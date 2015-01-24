-------------------------------------------------------------------------------
-- Title      : Cell Writer Reader
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : cell_writer_reader.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Writes cell data to buffer and sends cell data to host.
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

entity cell_writer_reader is
  generic (
    matrix_width    : positive := 8;
    matrix_height   : positive := 8;
    matrix_depth    : positive := 8;
    cell_type_bits  : positive := 8;
    cell_state_bits : positive := 1
  );
  port (
    buffer_address      : out std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
    buffer_types_write  : out std_logic;
    buffer_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_states_write : out std_logic;
    buffer_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    buffer_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    decode_operation : in cell_writer_reader_operation_type;
    decode_zyx       : in std_logic_vector(bits(matrix_depth) + bits(matrix_height) + bits(matrix_width) - 1 downto 0);
    decode_state     : in std_logic_vector(cell_state_bits - 1 downto 0);
    decode_states    : in std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    decode_type      : in std_logic_vector(cell_type_bits - 1 downto 0);
    decode_types     : in std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end cell_writer_reader;

architecture rtl of cell_writer_reader is

begin



end rtl;
