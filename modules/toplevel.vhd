-------------------------------------------------------------------------------
-- Title      : Toplevel
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : toplevel.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Connects all main components
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-20  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.functions.all;
use work.types.all;

entity toplevel is
  generic (
    tx_buffer_address_bits : positive := 10; -- PCIe packet length field is 10 bits
    rx_buffer_address_bits : positive := 10;
    reverse_payload_endian : boolean  := true; -- Required for x86 systems
    program_counter_bits   : positive := 8;
    matrix_width           : positive := 8;
    matrix_height          : positive := 8;
    matrix_depth           : positive := 8;
    cell_type_bits         : positive := 8;
    cell_state_bits        : positive := 1; -- Must be 1 due to implementation of CA
    cell_write_width       : positive := 8;
    instruction_bits       : positive := 256 -- Must be 256 due to implementation of fetch_communication
  );
  port (
    pcie_tx_p : out std_logic;
    pcie_tx_n : out std_logic;
    pcie_rx_p : in  std_logic;
    pcie_rx_n : in  std_logic;

    clock_p : in  std_logic;
    clock_n : in  std_logic;
    reset_n : in  std_logic;

    leds : out std_logic_vector(3 downto 0)
  );
end toplevel;

architecture rtl of toplevel is

  -- General
  signal clock : std_logic;
  signal reset : std_logic;

  -- Pipeline control
  signal run                     : std_logic;
  signal done_fetch              : std_logic;
  signal done_cell_writer_reader : std_logic;

  -- Communication
  signal tx_buffer_data  : std_logic_vector(31 downto 0);
  signal tx_buffer_count : std_logic_vector(tx_buffer_address_bits - 1 downto 0);
  signal tx_buffer_write : std_logic;

  signal rx_buffer_data  : std_logic_vector(31 downto 0);
  signal rx_buffer_count : std_logic_vector(rx_buffer_address_bits - 1 downto 0);
  signal rx_buffer_read  : std_logic;

  -- Decode
  signal decode_from_fetch_instruction : std_logic_vector(instruction_bits - 1 downto 0);

  signal decode_to_cell_writer_reader_operation : cell_writer_reader_operation_type;
  signal decode_to_cell_writer_reader_zyx       : std_logic_vector(bits(matrix_depth) + bits(matrix_height) + bits(matrix_width) - 1 downto 0);
  signal decode_to_cell_writer_reader_state     : std_logic_vector(cell_state_bits - 1 downto 0);
  signal decode_to_cell_writer_reader_states    : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal decode_to_cell_writer_reader_type      : std_logic_vector(cell_type_bits - 1 downto 0);
  signal decode_to_cell_writer_reader_types     : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);

  signal decode_to_cell_buffer_swap       : std_logic;
  signal decode_to_cell_buffer_mux_select : cell_buffer_mux_select_type;

  -- Cell Writer Reader
  signal cell_writer_reader_to_mux_address      : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal cell_writer_reader_to_mux_types_write  : std_logic;
  signal cell_writer_reader_to_mux_types        : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cell_writer_reader_from_mux_types      : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cell_writer_reader_to_mux_states_write : std_logic;
  signal cell_writer_reader_to_mux_states       : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal cell_writer_reader_from_mux_states     : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

  -- Cellular Automata
  signal cellular_automata_to_mux_address      : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal cellular_automata_to_mux_types_write  : std_logic;
  signal cellular_automata_to_mux_types        : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cellular_automata_from_mux_types      : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cellular_automata_to_mux_states_write : std_logic;
  signal cellular_automata_to_mux_states       : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal cellular_automata_from_mux_states     : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

  -- Development
  signal development_to_mux_a_address      : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal development_to_mux_a_types_write  : std_logic;
  signal development_to_mux_a_types        : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal development_from_mux_a_types      : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal development_to_mux_a_states_write : std_logic;
  signal development_to_mux_a_states       : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal development_from_mux_a_states     : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

  signal development_to_mux_b_address      : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal development_to_mux_b_types_write  : std_logic;
  signal development_to_mux_b_types        : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal development_from_mux_b_types      : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal development_to_mux_b_states_write : std_logic;
  signal development_to_mux_b_states       : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal development_from_mux_b_states     : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

  -- Cell buffer
  signal cell_buffer_from_mux_a_address      : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal cell_buffer_from_mux_a_types_write  : std_logic;
  signal cell_buffer_from_mux_a_types        : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cell_buffer_to_mux_a_types          : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cell_buffer_from_mux_a_states_write : std_logic;
  signal cell_buffer_from_mux_a_states       : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal cell_buffer_to_mux_a_states         : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

  signal cell_buffer_from_mux_b_address      : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal cell_buffer_from_mux_b_types_write  : std_logic;
  signal cell_buffer_from_mux_b_types        : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cell_buffer_to_mux_b_types          : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal cell_buffer_from_mux_b_states_write : std_logic;
  signal cell_buffer_from_mux_b_states       : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal cell_buffer_to_mux_b_states         : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

begin

  leds <= "0101";

  run <= done_fetch and done_cell_writer_reader;

  -----------------------------------------------------------------------------

  communication : entity work.communication
  generic map (
    tx_buffer_address_bits => tx_buffer_address_bits,
    rx_buffer_address_bits => rx_buffer_address_bits,
    reverse_payload_endian => reverse_payload_endian
  )
  port map (
    pcie_tx_p => pcie_tx_p,
    pcie_tx_n => pcie_tx_n,
    pcie_rx_p => pcie_rx_p,
    pcie_rx_n => pcie_rx_n,

    clock_p => clock_p,
    clock_n => clock_n,
    reset_n => reset_n,

    tx_buffer_in    => tx_buffer_data,
    tx_buffer_count => tx_buffer_count,
    tx_buffer_write => tx_buffer_write,

    rx_buffer_out   => rx_buffer_data,
    rx_buffer_count => rx_buffer_count,
    rx_buffer_read  => rx_buffer_read,

    clock => clock,
    reset => reset
  );

  fetch : entity work.fetch
  generic map (
    buffer_address_bits  => rx_buffer_address_bits,
    program_counter_bits => program_counter_bits,
    instruction_bits     => instruction_bits
  )
  port map (
    buffer_data  => rx_buffer_data,
    buffer_count => rx_buffer_count,
    buffer_read  => rx_buffer_read,

    instruction => decode_from_fetch_instruction,

    run  => run,
    done => done_fetch,

    clock => clock
  );

  decode : entity work.decode
  generic map (
    matrix_width     => matrix_width,
    matrix_height    => matrix_height,
    matrix_depth     => matrix_depth,
    cell_type_bits   => cell_type_bits,
    cell_state_bits  => cell_state_bits,
    cell_write_width => cell_write_width,
    instruction_bits => instruction_bits
  )
  port map (
    instruction => decode_from_fetch_instruction,

    cell_writer_reader_operation => decode_to_cell_writer_reader_operation,
    cell_writer_reader_zyx       => decode_to_cell_writer_reader_zyx,
    cell_writer_reader_state     => decode_to_cell_writer_reader_state,
    cell_writer_reader_states    => decode_to_cell_writer_reader_states,
    cell_writer_reader_type      => decode_to_cell_writer_reader_type,
    cell_writer_reader_types     => decode_to_cell_writer_reader_types,

    cell_buffer_swap       => decode_to_cell_buffer_swap,
    cell_buffer_mux_select => decode_to_cell_buffer_mux_select,

    run  => run,

    clock => clock
  );

  cell_writer_reader : entity work.cell_writer_reader
  generic map (
    matrix_width     => matrix_width,
    matrix_height    => matrix_height,
    matrix_depth     => matrix_depth,
    cell_type_bits   => cell_type_bits,
    cell_state_bits  => cell_state_bits,
    cell_write_width => cell_write_width
  )
  port map (
    buffer_address      => cell_writer_reader_to_mux_address,
    buffer_types_write  => cell_writer_reader_to_mux_types_write,
    buffer_types_in     => cell_writer_reader_from_mux_types,
    buffer_types_out    => cell_writer_reader_to_mux_types,
    buffer_states_write => cell_writer_reader_to_mux_states_write,
    buffer_states_in    => cell_writer_reader_from_mux_states,
    buffer_states_out   => cell_writer_reader_to_mux_states,

    decode_operation => decode_to_cell_writer_reader_operation,
    decode_zyx       => decode_to_cell_writer_reader_zyx,
    decode_state     => decode_to_cell_writer_reader_state,
    decode_states    => decode_to_cell_writer_reader_states,
    decode_type      => decode_to_cell_writer_reader_type,
    decode_types     => decode_to_cell_writer_reader_types,

    run  => run,
    done => done_cell_writer_reader,

    clock => clock
  );

  cell_buffer_mux : entity work.cell_buffer_mux
  generic map (
    matrix_width    => matrix_width,
    matrix_height   => matrix_height,
    matrix_depth    => matrix_depth,
    cell_type_bits  => cell_type_bits,
    cell_state_bits => cell_state_bits
  )
  port map (
    writer_reader_address      => cell_writer_reader_to_mux_address,
    writer_reader_types_write  => cell_writer_reader_to_mux_types_write,
    writer_reader_types_in     => cell_writer_reader_to_mux_types,
    writer_reader_types_out    => cell_writer_reader_from_mux_types,
    writer_reader_states_write => cell_writer_reader_to_mux_states_write,
    writer_reader_states_in    => cell_writer_reader_to_mux_states,
    writer_reader_states_out   => cell_writer_reader_from_mux_states,

    cellular_automata_address      => cellular_automata_to_mux_address,
    cellular_automata_types_write  => cellular_automata_to_mux_types_write,
    cellular_automata_types_in     => cellular_automata_to_mux_types,
    cellular_automata_types_out    => cellular_automata_from_mux_types,
    cellular_automata_states_write => cellular_automata_to_mux_states_write,
    cellular_automata_states_in    => cellular_automata_to_mux_states,
    cellular_automata_states_out   => cellular_automata_from_mux_states,

    development_a_address      => development_to_mux_a_address,
    development_a_types_write  => development_to_mux_a_types_write,
    development_a_types_in     => development_to_mux_a_types,
    development_a_types_out    => development_from_mux_a_types,
    development_a_states_write => development_to_mux_a_states_write,
    development_a_states_in    => development_to_mux_a_states,
    development_a_states_out   => development_from_mux_a_states,

    development_b_address      => development_to_mux_b_address,
    development_b_types_write  => development_to_mux_b_types_write,
    development_b_types_in     => development_to_mux_b_types,
    development_b_types_out    => development_from_mux_b_types,
    development_b_states_write => development_to_mux_b_states_write,
    development_b_states_in    => development_to_mux_b_states,
    development_b_states_out   => development_from_mux_b_states,

    buffer_a_address      => cell_buffer_from_mux_a_address,
    buffer_a_types_write  => cell_buffer_from_mux_a_types_write,
    buffer_a_types_in     => cell_buffer_to_mux_a_types,
    buffer_a_types_out    => cell_buffer_from_mux_a_types,
    buffer_a_states_write => cell_buffer_from_mux_a_states_write,
    buffer_a_states_in    => cell_buffer_to_mux_a_states,
    buffer_a_states_out   => cell_buffer_from_mux_a_states,

    buffer_b_address      => cell_buffer_from_mux_b_address,
    buffer_b_types_write  => cell_buffer_from_mux_b_types_write,
    buffer_b_types_in     => cell_buffer_to_mux_b_types,
    buffer_b_types_out    => cell_buffer_from_mux_b_types,
    buffer_b_states_write => cell_buffer_from_mux_b_states_write,
    buffer_b_states_in    => cell_buffer_to_mux_b_states,
    buffer_b_states_out   => cell_buffer_from_mux_b_states,

    source_select => decode_to_cell_buffer_mux_select,

    run => run,

    clock => clock
  );

  cell_buffer : entity work.cell_buffer
  generic map (
    matrix_width    => matrix_width,
    matrix_height   => matrix_height,
    matrix_depth    => matrix_depth,
    cell_type_bits  => cell_type_bits,
    cell_state_bits => cell_state_bits
  )
  port map (
    a_address      => cell_buffer_from_mux_a_address,
    a_types_write  => cell_buffer_from_mux_a_types_write,
    a_types_in     => cell_buffer_from_mux_a_types,
    a_types_out    => cell_buffer_to_mux_a_types,
    a_states_write => cell_buffer_from_mux_a_states_write,
    a_states_in    => cell_buffer_from_mux_a_states,
    a_states_out   => cell_buffer_to_mux_a_states,

    b_address      => cell_buffer_from_mux_b_address,
    b_types_write  => cell_buffer_from_mux_b_types_write,
    b_types_in     => cell_buffer_from_mux_b_types,
    b_types_out    => cell_buffer_to_mux_b_types,
    b_states_write => cell_buffer_from_mux_b_states_write,
    b_states_in    => cell_buffer_from_mux_b_states,
    b_states_out   => cell_buffer_to_mux_b_states,

    swap => decode_to_cell_buffer_swap,

    run => run,

    clock => clock
  );

end rtl;
