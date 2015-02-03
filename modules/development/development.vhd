-------------------------------------------------------------------------------
-- Title      : Development
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : development.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-03
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: TODO
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-03  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.functions.all;
use work.types.all;

entity development is
  generic (
    matrix_width              : positive := 8;
    matrix_height             : positive := 8;
    matrix_depth              : positive := 8;
    matrix_wrap               : boolean  := true;
    cell_type_bits            : positive := 8;
    cell_state_bits           : positive := 1;
    rule_storage_address_bits : positive := 8
  );
  port (
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

    rule_storage_write   : in std_logic;
    rule_storage_address : in std_logic_vector(rule_storage_address_bits - 1 downto 0);
    rule_storage_data    : in std_logic_vector((cell_type_bits + 1 + cell_state_bits + 1) * if_else(matrix_depth = 1, 6, 8) - 1 downto 0);

    decode_operation : in development_operation_type;

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end development;

architecture rtl of development is



begin



end rtl;
