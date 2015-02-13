-------------------------------------------------------------------------------
-- Title      : Rule Numbers Reader
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rule_numbers_reader.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-13
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Reads and sends hit rule numbers to host.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-13  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity rule_numbers_reader is
  generic (
    matrix_width             : positive := 8;
    matrix_height            : positive := 8;
    matrix_depth             : positive := 8;
    rule_amount              : positive := 256;
    send_buffer_address_bits : positive := 8
  );
  port (
    buffer_address_z : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    buffer_address_y : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    buffer_data      : in  std_logic_vector(matrix_width * bits(rule_amount) - 1 downto 0);

    send_buffer_data  : out std_logic_vector(31 downto 0);
    send_buffer_count : in  std_logic_vector(send_buffer_address_bits - 1 downto 0);
    send_buffer_write : out std_logic;

    decode_operation : in rule_numbers_reader_operation_type;

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end rule_numbers_reader;

architecture rtl of rule_numbers_reader is

  constant rule_number_bits           : positive := bits(rule_amount);
  constant rule_numbers_per_word      : positive := min(matrix_width, 32/rule_number_bits);
  constant rule_numbers_words_per_row : positive := divide_ceil(matrix_width, rule_Numbers_per_word);

  type state_type is (
    IDLE, SEND_ALL_NUMBERS
  );

  signal state : state_type := IDLE;

  -- Buffer checks
  signal buffer_has_space_one : boolean;

  -- Shifted signals
  signal shifted_rule_numbers : std_logic_vector(matrix_width * rule_number_bits - 1 downto 0);
  signal shift_amount         : std_logic_vector(bits(matrix_width) - 1 downto 0);

  -- Internally used out ports
  signal address_z : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal address_y : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal address_x : std_logic_vector(bits(matrix_width) - 1 downto 0);
  signal done_i : std_logic := '1';

begin

  buffer_has_space_one <= signed(send_buffer_count) /= -1;

  process begin
    wait until rising_edge(clock);

    -- Defaults
    send_buffer_write <= '0';

    case state is

      when IDLE =>
        if (run = '1' and decode_operation = READ_ALL) then
          done_i <= '0';

          address_z <= (others => '0');
          address_y <= (others => '0');
          address_x <= (others => '0');

          state <= SEND_ALL_NUMBERS;
        end if;

      when SEND_ALL_NUMBERS =>
        if (buffer_has_space_one) then
          send_buffer_write <= '1';
          shift_amount <= address_x;
          -- Iterate in raster order (x, then y, then z)
          -- Fit as many as possible in each word, but align between each rule number and row
          address_x <= std_logic_vector(unsigned(address_x) + rule_numbers_per_word);
          if (unsigned(address_x) + rule_numbers_per_word = rule_numbers_per_word*rule_numbers_words_per_row) then -- TODO: Verify this
            address_x <= (others => '0');
            address_y <= std_logic_vector(unsigned(address_y) + 1);
            if (unsigned(address_y) + 1 = matrix_height or matrix_height = 1) then
              address_y <= (others => '0');
              address_z <= std_logic_vector(unsigned(address_z) + 1);
              if (unsigned(address_z) + 1 = matrix_depth or matrix_depth = 1) then
                state <= IDLE;
                done_i <= '1';
              end if;
            end if;
          end if;
        end if;

    end case;
  end process;

  -- This part is not clocked 
  process (shifted_rule_numbers) begin
    send_buffer_data <= (others => '0');
    send_buffer_data(rule_numbers_per_word * rule_number_bits - 1 downto 0) <= shifted_rule_numbers(rule_numbers_per_word * rule_number_bits - 1 downto 0);
  end process;

  -- Shifter
  rule_numbers_shifter : entity work.shifter_dynamic
  generic map (
    data_width         => matrix_width*rule_number_bits,
    shift_amount_width => bits(matrix_width),
    shift_unit         => rule_number_bits
  )
  port map (
    data_in      => buffer_data,
    data_out     => shifted_rule_numbers,
    left         => '0',
    arithmetic   => '0',
    shift_amount => shift_amount
  );

  -- Internally used out ports
  buffer_address_z <= address_z;
  buffer_address_y <= address_y;
  done <= done_i;

end rtl;
