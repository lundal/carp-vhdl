-------------------------------------------------------------------------------
-- Title      : Configurable Look-Up Table
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : lut_configurable.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: A configurable look-up table
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-20  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity lut_configurable is
  generic (
    address_size            : positive := 5;
    configuration_data_size : positive := 2  -- Must be a power of two
  );
  port (
    configuration_data   : in  std_logic_vector(configuration_data_size - 1 downto 0);
    configuration_enable : in  std_logic;
    address              : in  std_logic_vector(address_size - 1 downto 0);
    output               : out std_logic;
    clock                : in  std_logic
  );
end lut_configurable;

architecture rtl of lut_configurable is

  constant configuration_data_size_log2 : integer := integer(ceil(log2(real(configuration_data_size))));
  constant shift_register_address_size  : integer := address_size - configuration_data_size_log2;
  
  signal shift_register_output : std_logic_vector(configuration_data_size - 1 downto 0);
  signal shift_register_select : std_logic_vector(address_size - 1 downto shift_register_address_size);

begin

  shift_registers : for i in 0 to configuration_data_size-1 generate
    shift_register : entity work.shift_register
    generic map (
      address_size  => shift_register_address_size
    )
    port map (
      input   => configuration_data(i),
      shift   => configuration_enable,
      address => address(shift_register_address_size - 1 downto 0),
      output  => shift_register_output(i),
      clock   => clock
    );
  end generate;

  shift_register_select <= address(address_size-1 downto shift_register_address_size);
  output <= shift_register_output(to_integer(unsigned(shift_register_select)));

end rtl;
