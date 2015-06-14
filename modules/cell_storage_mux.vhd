--------------------------------------------------------------------------------
-- Title       : Cell Storage Multiplexer
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Controls which components has access to the Cell Storage
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

entity cell_storage_mux is
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
    bram_a_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    bram_a_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    bram_a_types_write  : out std_logic;
    bram_a_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_a_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_a_states_write : out std_logic;
    bram_a_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    bram_a_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Buffer - Port B
    bram_b_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    bram_b_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    bram_b_types_write  : out std_logic;
    bram_b_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_b_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_b_states_write : out std_logic;
    bram_b_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    bram_b_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    source_select : in cell_storage_mux_select_type;

    run : in std_logic;

    clock : in std_logic
  );
end cell_storage_mux;

architecture rtl of cell_storage_mux is

  signal source_select_i : cell_storage_mux_select_type := WRITER_READER_AND_CELLULAR_AUTOMATA;

begin

  process begin
    wait until rising_edge(clock) and run = '1';
    source_select_i <= source_select;
  end process;

  process (source_select_i, bram_a_types_in, bram_a_states_in, bram_b_types_in, bram_b_states_in,
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
        bram_a_address_z         <= writer_reader_address_z;
        bram_a_address_y         <= writer_reader_address_y;
        bram_a_types_write       <= writer_reader_types_write;
        writer_reader_types_out  <= bram_a_types_in;
        bram_a_types_out         <= writer_reader_types_in;
        bram_a_states_write      <= writer_reader_states_write;
        writer_reader_states_out <= bram_a_states_in;
        bram_a_states_out        <= writer_reader_states_in;

        -- Port B
        bram_b_address_z         <= cellular_automata_address_z;
        bram_b_address_y         <= cellular_automata_address_y;
        bram_b_types_write       <= cellular_automata_types_write;
        cellular_automata_types_out <= bram_b_types_in;
        bram_b_types_out         <= cellular_automata_types_in;
        bram_b_states_write      <= cellular_automata_states_write;
        cellular_automata_states_out <= bram_b_states_in;
        bram_b_states_out        <= cellular_automata_states_in;

      when DEVELOPMENT =>
        -- Port A
        bram_a_address_z         <= development_a_address_z;
        bram_a_address_y         <= development_a_address_y;
        bram_a_types_write       <= development_a_types_write;
        development_a_types_out  <= bram_a_types_in;
        bram_a_types_out         <= development_a_types_in;
        bram_a_states_write      <= development_a_states_write;
        development_a_states_out <= bram_a_states_in;
        bram_a_states_out        <= development_a_states_in;

        -- Port B
        bram_b_address_z         <= development_b_address_z;
        bram_b_address_y         <= development_b_address_y;
        bram_b_types_write       <= development_b_types_write;
        development_b_types_out  <= bram_b_types_in;
        bram_b_types_out         <= development_b_types_in;
        bram_b_states_write      <= development_b_states_write;
        development_b_states_out <= bram_b_states_in;
        bram_b_states_out        <= development_b_states_in;

    end case;
  end process;

end rtl;
