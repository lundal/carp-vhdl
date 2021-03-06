--------------------------------------------------------------------------------
-- Title       : Information Sender
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Places system information in the Send Buffer
--             : Note: Many signals are trimmed during synthesis since all
--             : values are constants.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity information_sender is
  generic (
    matrix_width             : positive := 8;
    matrix_height            : positive := 8;
    matrix_depth             : positive := 8;
    matrix_wrap              : boolean  := true;
    cell_type_bits           : positive := 8;
    cell_state_bits          : positive := 1;
    jump_counters            : positive := 4;
    jump_counter_bits        : positive := 16;
    rule_amount              : positive := 256;
    send_buffer_address_bits : positive := 10
  );
  port (
    send_buffer_data  : out std_logic_vector(31 downto 0);
    send_buffer_count : in  std_logic_vector(send_buffer_address_bits - 1 downto 0);
    send_buffer_write : out std_logic;

    fitness_identifier    : in std_logic_vector(8 - 1 downto 0);
    fitness_words_per_run : in std_logic_vector(8 - 1 downto 0);
    fitness_parameters    : in std_logic_vector(16 - 1 downto 0);

    decode_operation : in information_sender_operation_type;

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end information_sender;

architecture rtl of information_sender is

  type state_type is (
    IDLE, SEND_MATRIX_SIZE, SEND_CELL_SIZE_AND_COUNTERS, SEND_RULE_AMOUNT, SEND_FITNESS
  );

  signal state : state_type := IDLE;

  -- Buffer checks
  signal buffer_has_space : boolean;

begin

  -- Buffer must have at least as many available words as the number of cycles
  -- between the condition is checked and the data is written. 4 should be plenty.
  buffer_has_space <= send_buffer_count(send_buffer_count'high downto 2) /= (send_buffer_count'high downto 2 => '1');

  process begin
    wait until rising_edge(clock);

    -- Default
    send_buffer_data  <= (others => '0');
    send_buffer_write <= '0';

    case (state) is
      when IDLE =>
        if (run = '1' and decode_operation = SEND) then
          state <= SEND_MATRIX_SIZE;
        end if;

      when SEND_MATRIX_SIZE =>
        if (buffer_has_space) then
          send_buffer_data(0)            <= to_std_logic(matrix_wrap);
          send_buffer_data(15 downto 8)  <= std_logic_vector(to_unsigned(matrix_width, 8));
          send_buffer_data(23 downto 16) <= std_logic_vector(to_unsigned(matrix_height, 8));
          send_buffer_data(31 downto 24) <= std_logic_vector(to_unsigned(matrix_depth, 8));
          send_buffer_write              <= '1';
          state <= SEND_CELL_SIZE_AND_COUNTERS;
        end if;

      when SEND_CELL_SIZE_AND_COUNTERS =>
        if (buffer_has_space) then
          send_buffer_data(7 downto 0)   <= std_logic_vector(to_unsigned(cell_state_bits, 8));
          send_buffer_data(15 downto 8)  <= std_logic_vector(to_unsigned(cell_type_bits, 8));
          send_buffer_data(23 downto 16) <= std_logic_vector(to_unsigned(jump_counters, 8));
          send_buffer_data(31 downto 24) <= std_logic_vector(to_unsigned(jump_counter_bits, 8));
          send_buffer_write              <= '1';
          state <= SEND_RULE_AMOUNT;
        end if;

      when SEND_RULE_AMOUNT =>
        if (buffer_has_space) then
          send_buffer_data  <= std_logic_vector(to_unsigned(rule_amount, 32));
          send_buffer_write <= '1';
          state <= SEND_FITNESS;
        end if;

      when SEND_FITNESS =>
        if (buffer_has_space) then
          send_buffer_data  <= fitness_parameters & fitness_words_per_run & fitness_identifier;
          send_buffer_write <= '1';
          state <= IDLE;
        end if;

    end case;
  end process;

  done <= '1' when state = IDLE else '0';

end rtl;
