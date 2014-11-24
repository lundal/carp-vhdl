-------------------------------------------------------------------------------
-- Title      : Shifter
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : shifter.vhd
-- Author     : Per Thomas Lundal
-- Company    : 
-- Last update: 2014/11/21
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Shifts a signal a static amount.
--            : Supports left, right and arithmetic modes.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/21  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter is
  generic (
    data_width   : natural := 32;
    shift_amount : natural := 1
  );
  port (
    data_in    : in  std_logic_vector(data_width - 1 downto 0);
    data_out   : out std_logic_vector(data_width - 1 downto 0);
    left       : in  std_logic;
    arithmetic : in  std_logic;
    enable     : in  std_logic
  );
end shifter;

architecture rtl of shifter is

begin

  process (data_in, left, arithmetic, enable) begin
    if (enable = '0') then
      data_out <= data_in;
    elsif (left = '1') then
      data_out <= std_logic_vector(shift_left(unsigned(data_in), shift_amount));
    elsif (arithmetic = '1') then
      data_out <= std_logic_vector(shift_right(signed(data_in), shift_amount));
    else
      data_out <= std_logic_vector(shift_right(unsigned(data_in), shift_amount));
    end if;
  end process;

end rtl;

