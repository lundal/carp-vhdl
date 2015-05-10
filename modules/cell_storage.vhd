-------------------------------------------------------------------------------
-- Title      : Cell Storage
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : cell_storage.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Storage for cell types and states.
--            : It has two regions that can be swapped.
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

entity cell_storage is
  generic (
    matrix_width    : positive := 8;
    matrix_height   : positive := 8;
    matrix_depth    : positive := 8;
    cell_type_bits  : positive := 8;
    cell_state_bits : positive := 1
  );
  port (
    -- Port A
    a_address_z    : in  std_logic_vector(bits(matrix_depth) - 1 downto 0);
    a_address_y    : in  std_logic_vector(bits(matrix_height) - 1 downto 0);
    a_types_write  : in  std_logic;
    a_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    a_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    a_states_write : in  std_logic;
    a_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    a_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Port B
    b_address_z    : in  std_logic_vector(bits(matrix_depth) - 1 downto 0);
    b_address_y    : in  std_logic_vector(bits(matrix_height) - 1 downto 0);
    b_types_write  : in  std_logic;
    b_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    b_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    b_states_write : in  std_logic;
    b_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    b_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    operation : in cell_storage_operation_type;

    run : in std_logic;

    clock : in std_logic
  );
end cell_storage;

architecture rtl of cell_storage is

  signal a_address_bram : std_logic_vector(bits(matrix_depth) + bits(matrix_height) downto 0);
  signal b_address_bram : std_logic_vector(bits(matrix_depth) + bits(matrix_height) downto 0);

  signal swapped : std_logic := '0';

begin

  process begin
    wait until rising_edge(clock) and run = '1';
    case (operation) is
      when SWAP =>
        swapped <= not swapped;

      when others=>

    end case;
  end process;

  a_address_bram <=     swapped & a_address_z & a_address_y;
  b_address_bram <= not swapped & b_address_z & b_address_y;

  types_bram : entity work.bram_tdp
  generic map (
    address_bits => 1 + bits(matrix_depth) + bits(matrix_height),
    data_bits    => matrix_width*cell_type_bits,
    write_first  => true
  )
  port map (
    a_write    => a_types_write,
    a_address  => a_address_bram,
    a_data_in  => a_types_in,
    a_data_out => a_types_out,

    b_write    => b_types_write,
    b_address  => b_address_bram,
    b_data_in  => b_types_in,
    b_data_out => b_types_out,

    clock => clock
  );

  states_bram : entity work.bram_tdp
  generic map (
    address_bits => 1 + bits(matrix_depth) + bits(matrix_height),
    data_bits    => matrix_width*cell_state_bits,
    write_first  => true
  )
  port map (
    a_write    => a_states_write,
    a_address  => a_address_bram,
    a_data_in  => a_states_in,
    a_data_out => a_states_out,

    b_write    => b_states_write,
    b_address  => b_address_bram,
    b_data_in  => b_states_in,
    b_data_out => b_states_out,

    clock => clock
  );

end rtl;
