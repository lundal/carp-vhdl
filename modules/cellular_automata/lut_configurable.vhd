--------------------------------------------------------------------------------
-- Title       : Configurable LUT
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : A configurable lookup table
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity lut_configurable is
  generic (
    address_bits            : positive := 5;
    configuration_data_bits : positive := 2  -- Must be a power of two
  );
  port (
    configuration_data   : in  std_logic_vector(configuration_data_bits - 1 downto 0);
    configuration_enable : in  std_logic;
    address              : in  std_logic_vector(address_bits - 1 downto 0);
    output               : out std_logic;
    clock                : in  std_logic
  );
end lut_configurable;

architecture rtl of lut_configurable is

  constant configuration_data_bits_bits : natural := bits(configuration_data_bits);
  constant shift_register_address_bits  : natural := address_bits - configuration_data_bits_bits;

  signal shift_register_output : std_logic_vector(configuration_data_bits - 1 downto 0);
  signal shift_register_select : std_logic_vector(address_bits - 1 downto shift_register_address_bits);

  function is_pow_2 (
    number : positive
  ) return boolean is
    constant num : unsigned := to_unsigned(number, 32);
  begin
     return (num and (num - 1)) = 0;
  end is_pow_2;

begin

  -- Generic checks
  assert (is_pow_2(configuration_data_bits)) report "Unsupported configuration_data_bits. Supported values are [2^N]." severity FAILURE;

  shift_registers : for i in 0 to configuration_data_bits-1 generate
    shift_register : entity work.shift_register
    generic map (
      address_bits  => shift_register_address_bits
    )
    port map (
      input   => configuration_data(i),
      shift   => configuration_enable,
      address => address(shift_register_address_bits - 1 downto 0),
      output  => shift_register_output(i),
      clock   => clock
    );
  end generate;

  shift_register_select <= address(address_bits-1 downto shift_register_address_bits);
  output <= shift_register_output(to_integer(unsigned(shift_register_select)));

end rtl;
