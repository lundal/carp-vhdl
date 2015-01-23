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
--            : Address is Y & Z. They are combined since Z can be 0 bits.
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
    width      : positive := 8;
    height     : positive := 8;
    depth      : positive := 8;
    type_bits  : positive := 8;
    state_bits : positive := 1
  );
  port (
    address : in std_logic_vector(bits(height) + bits(depth) - 1 downto 0);

    types_write : in  std_logic;
    types_in    : in  std_logic_vector(width*type_bits - 1 downto 0);
    types_out   : out std_logic_vector(width*type_bits - 1 downto 0);

    states_write : in  std_logic;
    states_in    : in  std_logic_vector(width*state_bits - 1 downto 0);
    states_out   : out std_logic_vector(width*state_bits - 1 downto 0);
    
    clock : in std_logic
  );
end cell_buffer;

architecture rtl of cell_buffer is

begin

  types_bram : entity work.bram_tdp
  generic map (
    address_bits => bits(height) + bits(depth),
    data_bits => width*type_bits,
    write_first => false
  )
  port map (
    a_write    => types_write,
    a_address  => address,
    a_data_in  => types_in,
    a_data_out => types_out,
    
    b_write    => '0',
    b_address  => (others => '0'),
    b_data_in  => (others => '0'),
    b_data_out => open,
    
    clock => clock
  );

  states_bram : entity work.bram_tdp
  generic map (
    address_bits => bits(height) + bits(depth),
    data_bits => width*state_bits,
    write_first => false
  )
  port map (
    a_write    => states_write,
    a_address  => address,
    a_data_in  => states_in,
    a_data_out => states_out,
    
    b_write    => '0',
    b_address  => (others => '0'),
    b_data_in  => (others => '0'),
    b_data_out => open,
    
    clock => clock
  );

end rtl;
