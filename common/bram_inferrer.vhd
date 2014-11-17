-------------------------------------------------------------------------------
-- Title      : bram_inferrer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : bram_inferrer.vhd
-- Author     : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2013/12/10
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: A dual port BRAM. Used for inferring BRAM.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2013/12/10  1.0      stoevneng Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;

entity bram_inferrer is
generic (
	addr_bits : integer;
	data_bits : integer
	);
port (
	clk_a : in std_logic;
	clk_b : in std_logic;
	
	addr_a : in std_logic_vector(addr_bits - 1 downto 0);
	data_i_a : in std_logic_vector(data_bits - 1 downto 0);
	data_o_a : out std_logic_vector(data_bits - 1 downto 0);
	we_a : in std_logic;
	en_a : in std_logic;
	rst_a : in std_logic;
	
	addr_b : in std_logic_vector(addr_bits - 1 downto 0);
	data_i_b : in std_logic_vector(data_bits - 1 downto 0);
	data_o_b : out std_logic_vector(data_bits - 1 downto 0);
	we_b : in std_logic;
	en_b : in std_logic;
	rst_b : in std_logic
	);
end bram_inferrer;

architecture Behavioral of bram_inferrer is
type ram_a is array((2**addr_bits) - 1 downto 0) of std_logic_vector(data_bits - 1 downto 0);
shared variable ram : ram_a := (others => (others => '0'));

begin

process(clk_a)
begin
	if(rising_edge(clk_a)) then
		if(en_a = '1') then
			if(we_a = '1') then
				ram(to_integer(unsigned(addr_a))) := data_i_a;
				data_o_a <= data_i_a;
			else
				data_o_a <= ram(to_integer(unsigned(addr_a)));
			end if;
		end if;
	end if;
end process;

process(clk_b)
begin
	if(rising_edge(clk_b)) then
		if(en_b = '1') then
			if(we_b = '1') then
				ram(to_integer(unsigned(addr_b))) := data_i_b;
				data_o_b <= data_i_b;
			else
				data_o_b <= ram(to_integer(unsigned(addr_b)));
			end if;
		end if;
	end if;
end process;

end Behavioral;

