-------------------------------------------------------------------------------
-- Title      : Counter
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : counter.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: A generic counter
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2015-01-20  1.1      lundal  Refactored
-- 2003-02-26  1.0      djupdal	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
  generic (
    counter_bits : positive := 4
  );
  port (
    reset     : in  std_logic;
    increment : in  std_logic;
    count_to  : in  unsigned(counter_bits - 1 downto 0);
    zero      : out std_logic;
    finished  : out std_logic;
    value     : out unsigned(counter_bits - 1 downto 0);
    clock     : in  std_logic
  );
end counter;

architecture rtl of counter is

  signal zero_i     : std_logic;
  signal finished_i : std_logic;
  signal value_i    : unsigned(counter_bits - 1 downto 0);

begin

  process begin
    wait until rising_edge(clock);

    if (reset = '1') then
      value_i <= to_unsigned(0, counter_bits);
    elsif (increment = '1' and finished_i = '0') then
      value_i <= value_i + 1;
    end if;

  end process;

  zero_i     <= '1' when value_i = to_unsigned(0, counter_bits) else '0';
  finished_i <= '1' when value_i = count_to else '0';

  zero     <= zero_i;
  finished <= finished_i;
  value    <= value_i;
                                          
end rtl;
