--------------------------------------------------------------------------------
-- Title       : Selector
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Selects one part of a signal (std_logic_vector multiplexer)
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity selector is
  generic (
    entry_bits   : positive := 8;
    entry_number : positive := 64
  );
  port (
    entries_in : in  std_logic_vector(entry_number*entry_bits - 1 downto 0);
    entry_out  : out std_logic_vector(entry_bits - 1 downto 0);
    selected   : in  std_logic_vector(bits(entry_number) - 1 downto 0)
  );
end selector;

architecture rtl of selector is

  type entries_type is array (entry_number-1 downto 0) of std_logic_vector(entry_out'range);

  signal entries : entries_type;

begin

  splitter : for i in 0 to entry_number - 1 generate
    entries(i) <= entries_in(entry_out'left + i*entry_bits downto i*entry_bits);
  end generate;

  entry_out <= entries(to_integer(unsigned(selected)));

end rtl;
