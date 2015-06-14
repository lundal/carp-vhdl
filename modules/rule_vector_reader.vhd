--------------------------------------------------------------------------------
-- Title       : Rule Vector Reader
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Reads rule vectors and places them in the Send Buffer
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

entity rule_vector_reader is
  generic (
    rule_amount              : positive := 256;
    rule_vector_amount       : positive := 64;
    send_buffer_address_bits : positive := 8
  );
  port (
    vector_buffer_data  : in  std_logic_vector(rule_amount - 1 downto 0);
    vector_buffer_count : in  std_logic_vector(bits(rule_vector_amount) - 1 downto 0);
    vector_buffer_read  : out std_logic;

    send_buffer_data  : out std_logic_vector(31 downto 0);
    send_buffer_count : in  std_logic_vector(send_buffer_address_bits - 1 downto 0);
    send_buffer_write : out std_logic;

    decode_operation : in rule_vector_reader_operation_type;
    decode_count     : in std_logic_vector(bits(rule_vector_amount) - 1 downto 0);

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end rule_vector_reader;

architecture rtl of rule_vector_reader is

  constant words_per_rule_vector : positive := divide_ceil(rule_amount, 32);

  type state_type is (
    IDLE, GET_RULE_VECTOR, SEND_RULE_VECTOR
  );

  signal state : state_type := IDLE;

  -- Rule vector data
  signal rule_vectors_to_send       : unsigned(bits(rule_vector_amount) - 1 downto 0);
  signal rule_vector_shift_register : std_logic_vector(rule_amount - 1 downto 0);
  signal rule_vector_words_sent     : unsigned(bits(words_per_rule_vector) - 1 downto 0);

  -- Buffer checks
  signal vector_buffer_has_data_one : boolean;
  signal send_buffer_has_space  : boolean;

  -- Internally used out ports
  signal done_i : std_logic := '1';

begin

  -- Generic checks
  assert (rule_amount >= 32) report "Unsupported rule_amount. Supported values are [32-N]." severity FAILURE;


  -- Buffer must have at least as many available words as the number of cycles
  -- between the condition is checked and the data is written. 4 should be plenty.
  send_buffer_has_space <= send_buffer_count(send_buffer_count'high downto 2) /= (send_buffer_count'high downto 2 => '1');
  vector_buffer_has_data_one <= vector_buffer_count /= (vector_buffer_count'range => '0');

  process begin
    wait until rising_edge(clock);

    -- Defaults
    vector_buffer_read <= '0';
    send_buffer_write <= '0';

    case state is

      when IDLE =>
        if (run = '1' and decode_operation = READ_N) then
          rule_vectors_to_send <= unsigned(decode_count);
          state <= GET_RULE_VECTOR;
          done_i <= '0';
        end if;

      when GET_RULE_VECTOR =>
        if (unsigned(rule_vectors_to_send) = 0) then
          state <= IDLE;
          done_i <= '1';
        elsif (vector_buffer_has_data_one) then
          rule_vectors_to_send       <= rule_vectors_to_send - 1;
          rule_vector_shift_register <= vector_buffer_data;
          rule_vector_words_sent     <= (others => '0');
          vector_buffer_read <= '1';
          state <= SEND_RULE_VECTOR;
        end if;

      when SEND_RULE_VECTOR =>
        if (send_buffer_has_space) then
          -- Send vector part
          send_buffer_write <= '1';
          send_buffer_data <= rule_vector_shift_register(31 downto 0);
          -- Shift register
          rule_vector_shift_register <= std_logic_vector(shift_right(unsigned(rule_vector_shift_register), 32));
          rule_vector_words_sent <= rule_vector_words_sent + 1;
          -- Check if done
          if (rule_vector_words_sent = words_per_rule_vector - 1) then
            state <= GET_RULE_VECTOR;
          end if;
        end if;

    end case;
  end process;

  -- Internally used out ports
  done <= done_i;

end rtl;
