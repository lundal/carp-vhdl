-------------------------------------------------------------------------------
-- Title      : Shift Register
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : shift_register.vhd
-- Author     : Ola Martin Tiseth Stoevneng
--            : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: A shift register
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-20  1.1      lundal    Refactored
-- 2014-02-02  1.0      stoevneng Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shift_register is
  generic (
    address_bits : positive := 4
  );
  port (
    input   : in  std_logic;
    shift   : in  std_logic;
    address : in  std_logic_vector(address_bits - 1 downto 0);
    output  : out std_logic;
    clock   : in  std_logic
  );
end shift_register;

architecture rtl of shift_register is

  signal register_i : std_logic_vector(2**address_bits - 1 downto 0) := (others => '0');

begin

  process begin
    wait until rising_edge(clock);

    if (shift = '1') then
      register_i <= register_i(2**address_bits - 2 downto 0) & input;
    end if;

  end process;

  output <= register_i(to_integer(unsigned(address)));

end rtl;
