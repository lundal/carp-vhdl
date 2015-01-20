-------------------------------------------------------------------------------
-- Title      : Twiddle Memory
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : twiddle_memory.vhd
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
-- Company    : NTNU
-- Last update: 2014-04-08
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: A memory block holding twidle factors
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2014-04-08  1.0      stovneng Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.twiddles.all;
use work.constants.all;

entity twiddle_memory is
  generic (
	  index : integer
	);
  port (
    clock    : in std_logic;
		address  : in integer;
    data_out : out std_logic_vector(TWLEN-1 downto 0)
  );
end twiddle_memory;

architecture rtl of twiddle_memory is

  signal ram : twat := TWIDDLES(index);--(others => (others => '0'));

begin

  process begin
    wait until rising_edge(clock);
    data_out <= ram(address);
  end process;

end rtl;
