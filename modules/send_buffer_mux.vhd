--------------------------------------------------------------------------------
-- Title       : Send Buffer Multiplexer
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Controls which component has access to the Send Buffer
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

entity send_buffer_mux is
  generic (
    send_buffer_address_bits : positive := 10
  );
  port (
    -- Cell Writer Reader
    cell_writer_reader_data  : in  std_logic_vector(31 downto 0);
    cell_writer_reader_count : out std_logic_vector(send_buffer_address_bits - 1 downto 0);
    cell_writer_reader_write : in  std_logic;

    -- Information Sender
    information_sender_data  : in  std_logic_vector(31 downto 0);
    information_sender_count : out std_logic_vector(send_buffer_address_bits - 1 downto 0);
    information_sender_write : in  std_logic;

    -- Rule Vector Reader
    rule_vector_reader_data  : in  std_logic_vector(31 downto 0);
    rule_vector_reader_count : out std_logic_vector(send_buffer_address_bits - 1 downto 0);
    rule_vector_reader_write : in  std_logic;

    -- Rule Numbers Reader
    rule_numbers_reader_data  : in  std_logic_vector(31 downto 0);
    rule_numbers_reader_count : out std_logic_vector(send_buffer_address_bits - 1 downto 0);
    rule_numbers_reader_write : in  std_logic;

    -- Fitness Sender
    fitness_sender_data  : in  std_logic_vector(31 downto 0);
    fitness_sender_count : out std_logic_vector(send_buffer_address_bits - 1 downto 0);
    fitness_sender_write : in  std_logic;

    -- Buffer
    send_buffer_data  : out std_logic_vector(31 downto 0);
    send_buffer_count : in  std_logic_vector(send_buffer_address_bits - 1 downto 0);
    send_buffer_write : out std_logic;

    source_select : in send_buffer_mux_select_type;

    run : in std_logic;

    clock : in std_logic
  );
end send_buffer_mux;

architecture rtl of send_buffer_mux is

  signal source_select_i : send_buffer_mux_select_type := CELL_WRITER_READER;

begin

  process begin
    wait until rising_edge(clock) and run = '1';
    source_select_i <= source_select;
  end process;

  process (source_select_i, send_buffer_count,
           cell_writer_reader_data, cell_writer_reader_write,
           information_sender_data, information_sender_write,
           rule_vector_reader_data, rule_vector_reader_write,
           rule_numbers_reader_data, rule_numbers_reader_write,
           fitness_sender_data, fitness_sender_write) begin

    -- Defaults
    cell_writer_reader_count  <= (others => '0');
    information_sender_count  <= (others => '0');
    rule_vector_reader_count  <= (others => '0');
    rule_numbers_reader_count <= (others => '0');
    fitness_sender_count      <= (others => '0');

    case source_select_i is

      when CELL_WRITER_READER =>
        send_buffer_data  <= cell_writer_reader_data;
        cell_writer_reader_count <= send_buffer_count;
        send_buffer_write <= cell_writer_reader_write;

      when INFORMATION_SENDER =>
        send_buffer_data  <= information_sender_data;
        information_sender_count <= send_buffer_count;
        send_buffer_write <= information_sender_write;

      when RULE_VECTOR_READER =>
        send_buffer_data  <= rule_vector_reader_data;
        rule_vector_reader_count <= send_buffer_count;
        send_buffer_write <= rule_vector_reader_write;

      when RULE_NUMBERS_READER =>
        send_buffer_data  <= rule_numbers_reader_data;
        rule_numbers_reader_count <= send_buffer_count;
        send_buffer_write <= rule_numbers_reader_write;

      when FITNESS_SENDER =>
        send_buffer_data  <= fitness_sender_data;
        fitness_sender_count <= send_buffer_count;
        send_buffer_write <= fitness_sender_write;

    end case;
  end process;

end rtl;
