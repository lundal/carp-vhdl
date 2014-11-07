-------------------------------------------------------------------------------
-- Title      : twmem
-- Project    : 
-------------------------------------------------------------------------------
-- File       : twmem.vhd
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
-- Company    : 
-- Last update: 2014/04/08
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Constant memory holding twiddle factors for DFT.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2014/04/08  1.0      stovneng Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library work;
use work.twiddle.all;
use work.sblock_package.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity twmem is
generic (
	ind : integer
	);
port (clk : in std_logic;
		  address : in integer;
        --we : in std_logic;
        --data_i : in std_logic_vector(7 downto 0);
        data_o : out std_logic_vector(TWLEN-1 downto 0)
     );

end twmem;

architecture twmem_arch of twmem is
signal ram : twat := TWIDDLES(ind);--(others => (others => '0'));
begin

process(clk)
begin
    if(rising_edge(clk)) then
        data_o <= ram(address);
    end if; 
end process;

end twmem_arch;

