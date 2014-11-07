-------------------------------------------------------------------------------
-- Title      : bitcounterN
-- Project    : 
-------------------------------------------------------------------------------
-- File       : bitcounterN.vhd
-- Author     : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2013/11/28
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Count number of ones in N signals 
-- where N is a power of 2 greater than 8.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2013/11/28  1.0      stoevneng Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_signed.all;
use work.sblock_package.all;

--library unisim;

entity bitcounterN is
  generic (
    N : integer;
    L : integer);
  port (
    input : in  std_logic_vector (N-1 downto 0);  --between 0 and 16
    f : out std_logic_vector (L-1 downto 0);
    clk : in std_logic);
end bitcounterN;


architecture bitcounterN_arch of bitcounterN is
  signal temp : std_logic_vector (L-1 downto 0);
  signal a : std_logic_vector (L-2 downto 0);
  signal b : std_logic_vector (L-2 downto 0);

  begin

recursecounter: if N > 16 generate
  counter1: entity bitcounterN
    generic map (
      N => N/2,
      L => L-1)
    port map (
      input => input(N-1 downto N/2),
      f => a,
    clk => clk);

  counter2: entity bitcounterN
    generic map (
      N => N/2,
      L => L-1)
    port map (
      input => input(N/2-1 downto 0),
      f => b,
    clk => clk);
    

end generate recursecounter;
  
trivialcounter: if N = 16 generate
  counter1: bitcounter8
    port map (
      input => input(N-1 downto N/2),
      f => a);

  counter2: bitcounter8
    port map (
      input => input(N/2-1 downto 0),
      f => b);
end generate trivialcounter;


  process(a, b)
  begin
    temp <= ('0' & a) + ('0' & b);
  end process;
  
  do_clk: if L = 5 or (L > 7 and L mod 2 = 0) generate
  process(clk)
  begin
    if(rising_edge(clk)) then
      f <= temp;
    end if;
  end process;
  end generate do_clk;
  
  don_clk: if L = 6 or (L > 6 and L mod 2 = 1) generate
    f <= temp;
  end generate don_clk;
end bitcounterN_arch;
