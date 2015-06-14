--------------------------------------------------------------------------------
-- Title       : Shifter
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Shifts a signal a static amount.
--             : Supports left, right and arithmetic modes.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2014  Lundal    Created
--             : 2015  Lundal    Refactored
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter is
  generic (
    data_width   : positive := 32;
    shift_amount : positive := 1
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

