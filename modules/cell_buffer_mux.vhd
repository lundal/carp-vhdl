-------------------------------------------------------------------------------
-- Title      : Cell Buffer Multiplexer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : cell_buffer_mux.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Controls which component has access to the cell buffer.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-23  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity cell_buffer_mux is
  generic (
    matrix_width    : positive := 8;
    matrix_height   : positive := 8;
    matrix_depth    : positive := 8;
    cell_type_bits  : positive := 8;
    cell_state_bits : positive := 1
  );
  port (
    -- Cell Writer Reader
    writer_reader_address_z    : in  std_logic_vector(bits(matrix_depth) - 1 downto 0);
    writer_reader_address_y    : in  std_logic_vector(bits(matrix_height) - 1 downto 0);
    writer_reader_types_write  : in  std_logic;
    writer_reader_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    writer_reader_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    writer_reader_states_write : in  std_logic;
    writer_reader_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    writer_reader_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Cellular Automata
    cellular_automata_address_z    : in  std_logic_vector(bits(matrix_depth) - 1 downto 0);
    cellular_automata_address_y    : in  std_logic_vector(bits(matrix_height) - 1 downto 0);
    cellular_automata_types_write  : in  std_logic;
    cellular_automata_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    cellular_automata_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    cellular_automata_states_write : in  std_logic;
    cellular_automata_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    cellular_automata_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Development - Port A
    development_a_address_z    : in  std_logic_vector(bits(matrix_depth) - 1 downto 0);
    development_a_address_y    : in  std_logic_vector(bits(matrix_height) - 1 downto 0);
    development_a_types_write  : in  std_logic;
    development_a_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    development_a_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    development_a_states_write : in  std_logic;
    development_a_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    development_a_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Development - Port B
    development_b_address_z    : in  std_logic_vector(bits(matrix_depth) - 1 downto 0);
    development_b_address_y    : in  std_logic_vector(bits(matrix_height) - 1 downto 0);
    development_b_types_write  : in  std_logic;
    development_b_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    development_b_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    development_b_states_write : in  std_logic;
    development_b_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    development_b_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Buffer - Port A
    buffer_a_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    buffer_a_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    buffer_a_types_write  : out std_logic;
    buffer_a_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_a_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_a_states_write : out std_logic;
    buffer_a_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    buffer_a_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Buffer - Port B
    buffer_b_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    buffer_b_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    buffer_b_types_write  : out std_logic;
    buffer_b_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_b_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_b_states_write : out std_logic;
    buffer_b_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    buffer_b_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    source_select : in cell_buffer_mux_select_type;

    run : in std_logic;

    clock : in std_logic
  );
end cell_buffer_mux;

architecture rtl of cell_buffer_mux is

  signal source_select_i : cell_buffer_mux_select_type := WRITER_READER_AND_CELLULAR_AUTOMATA;

begin

  process begin
    wait until rising_edge(clock) and run = '1';
    source_select_i <= source_select;
  end process;

  process (source_select_i, buffer_a_types_in, buffer_a_states_in, buffer_b_types_in, buffer_b_states_in,
           writer_reader_address_z, writer_reader_address_y, writer_reader_types_write, writer_reader_types_in, writer_reader_states_write, writer_reader_states_in,
           cellular_automata_address_z, cellular_automata_address_y, cellular_automata_types_write, cellular_automata_types_in, cellular_automata_states_write, cellular_automata_states_in,
           development_a_address_z, development_a_address_y, development_a_types_write, development_a_types_in, development_a_states_write, development_a_states_in,
           development_b_address_z, development_b_address_y, development_b_types_write, development_b_types_in, development_b_states_write, development_b_states_in) begin

    -- Defaults
    writer_reader_types_out      <= (others => '0');
    writer_reader_states_out     <= (others => '0');
    cellular_automata_types_out  <= (others => '0');
    cellular_automata_states_out <= (others => '0');
    development_a_types_out      <= (others => '0');
    development_a_states_out     <= (others => '0');
    development_b_types_out      <= (others => '0');
    development_b_states_out     <= (others => '0');

    case source_select_i is

      when WRITER_READER_AND_CELLULAR_AUTOMATA =>
        -- Port A
        buffer_a_address_z    <= writer_reader_address_z;
        buffer_a_address_y    <= writer_reader_address_y;
        buffer_a_types_write  <= writer_reader_types_write;
        writer_reader_types_out    <= buffer_a_types_in;
        buffer_a_types_out    <= writer_reader_types_in;
        buffer_a_states_write <= writer_reader_states_write;
        writer_reader_states_out   <= buffer_a_states_in;
        buffer_a_states_out   <= writer_reader_states_in;

        -- Port B
        buffer_b_address_z    <= cellular_automata_address_z;
        buffer_b_address_y    <= cellular_automata_address_y;
        buffer_b_types_write  <= cellular_automata_types_write;
        cellular_automata_types_out    <= buffer_b_types_in;
        buffer_b_types_out    <= cellular_automata_types_in;
        buffer_b_states_write <= cellular_automata_states_write;
        cellular_automata_states_out   <= buffer_b_states_in;
        buffer_b_states_out   <= cellular_automata_states_in;

      when DEVELOPMENT =>
        -- Port A
        buffer_a_address_z    <= development_a_address_z;
        buffer_a_address_y    <= development_a_address_y;
        buffer_a_types_write  <= development_a_types_write;
        development_a_types_out    <= buffer_a_types_in;
        buffer_a_types_out    <= development_a_types_in;
        buffer_a_states_write <= development_a_states_write;
        development_a_states_out   <= buffer_a_states_in;
        buffer_a_states_out   <= development_a_states_in;

        -- Port B
        buffer_b_address_z    <= development_b_address_z;
        buffer_b_address_y    <= development_b_address_y;
        buffer_b_types_write  <= development_b_types_write;
        development_b_types_out    <= buffer_b_types_in;
        buffer_b_types_out    <= development_b_types_in;
        buffer_b_states_write <= development_b_states_write;
        development_b_states_out   <= buffer_b_states_in;
        buffer_b_states_out   <= development_b_states_in;

    end case;
  end process;

end rtl;
