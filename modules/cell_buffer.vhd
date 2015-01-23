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
--            : The address is Y & Z. They are combined since Z can be 0 bits.
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
    -- Port A
    a_address      : in  std_logic_vector(bits(height) + bits(depth) - 1 downto 0);
    a_types_write  : in  std_logic;
    a_types_in     : in  std_logic_vector(width*type_bits - 1 downto 0);
    a_types_out    : out std_logic_vector(width*type_bits - 1 downto 0);
    a_states_write : in  std_logic;
    a_states_in    : in  std_logic_vector(width*state_bits - 1 downto 0);
    a_states_out   : out std_logic_vector(width*state_bits - 1 downto 0);

    -- Port B
    b_address      : in  std_logic_vector(bits(height) + bits(depth) - 1 downto 0);
    b_types_write  : in  std_logic;
    b_types_in     : in  std_logic_vector(width*type_bits - 1 downto 0);
    b_types_out    : out std_logic_vector(width*type_bits - 1 downto 0);
    b_states_write : in  std_logic;
    b_states_in    : in  std_logic_vector(width*state_bits - 1 downto 0);
    b_states_out   : out std_logic_vector(width*state_bits - 1 downto 0);

    swapped : in std_logic;

    clock : in std_logic
  );
end cell_buffer;

architecture rtl of cell_buffer is

  signal a_address_bram : std_logic_vector(bits(height) + bits(depth) downto 0);
  signal b_address_bram : std_logic_vector(bits(height) + bits(depth) downto 0);

begin

  a_address_bram <=     swapped & a_address;
  b_address_bram <= not swapped & b_address;

  types_bram : entity work.bram_tdp
  generic map (
    address_bits => bits(height) + bits(depth) + 1,
    data_bits => width*type_bits,
    write_first => false
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
    address_bits => bits(height) + bits(depth) + 1,
    data_bits => width*state_bits,
    write_first => false
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
