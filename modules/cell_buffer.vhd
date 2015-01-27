-------------------------------------------------------------------------------
-- Title      : Cell Buffer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : cell_buffer.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: BRAM holding cell types and states.
--            : It is divided into two regions; one for each port.
--            : The address is Z & Y. They are combined since Z can be 0 bits.
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

entity cell_buffer is
  generic (
    matrix_width    : positive := 8;
    matrix_height   : positive := 8;
    matrix_depth    : positive := 8;
    cell_type_bits  : positive := 8;
    cell_state_bits : positive := 1
  );
  port (
    -- Port A
    a_address      : in  std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
    a_types_write  : in  std_logic;
    a_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    a_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    a_states_write : in  std_logic;
    a_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    a_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Port B
    b_address      : in  std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
    b_types_write  : in  std_logic;
    b_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    b_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    b_states_write : in  std_logic;
    b_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    b_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    swap : in std_logic;

    run : in std_logic;

    clock : in std_logic
  );
end cell_buffer;

architecture rtl of cell_buffer is

  signal a_address_bram : std_logic_vector(bits(matrix_depth) + bits(matrix_height) downto 0);
  signal b_address_bram : std_logic_vector(bits(matrix_depth) + bits(matrix_height) downto 0);

  signal swapped : std_logic := '0';

begin

  process begin
    wait until rising_edge(clock) and run = '1';
    if (swap = '1') then
      swapped <= not swapped;
    end if;
  end process;

  a_address_bram <=     swapped & a_address;
  b_address_bram <= not swapped & b_address;

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
