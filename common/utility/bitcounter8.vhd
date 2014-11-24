-------------------------------------------------------------------------------
-- Title      : bitcounter8
-- Project    : 
-------------------------------------------------------------------------------
-- File       : bitcounter8.vhd
-- Author     : Kjetil Aamodt
-- Company    : 
-- Last update: 2005/05/26
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Count number of ones in four signals
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2005/02/21  1.0      aamodt	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_signed.all;
use work.sblock_package.all;


entity bitcounter8 is
port (
    input : in  std_logic_vector (7 downto 0);  --between 0 and 4
    f : out std_logic_vector (3 downto 0));
end bitcounter8;


architecture bitcounter8_arch of bitcounter8 is
  signal temp : std_logic_vector (3 downto 0);
  signal a : std_logic_vector (2 downto 0);
  signal b : std_logic_vector (2 downto 0);

  begin
  
counter1: bitcounter4
  port map (
    a => input(7),
    b => input(6),
    c => input(5),
    d => input(4),
    f => a);        -- max bx1000 (0x4)

counter2: bitcounter4
  port map (
    a => input(3),
    b => input(2),
    c => input(1),
    d => input(0),
    f => b);        -- max bx1000 (0x4)

  process(a, b)
    
  begin
    --temp <= ('0' & a) + ('0' & b);
     if (a(2)='0' and b(2)='0') then
       temp(0) <= a(0) xor b(0);
       temp(1) <= (not a(1) and not a(0) and     b(1) and not b(0) )or
                  (not a(1) and not a(0) and     b(1) and     b(0) )or
                  (not a(1) and     a(0) and not b(1) and     b(0) )or
                  (not a(1) and     a(0) and     b(1) and not b(0) )or               
                  (    a(1) and not a(0) and not b(1) and not b(0) )or
                  (    a(1) and not a(0) and not b(1) and     b(0) )or
                  (    a(1) and     a(0) and not b(1) and not b(0) )or
                  (    a(1) and     a(0) and     b(1) and     b(0) );
       temp(2) <= (a(1) and b(1)          ) or
                  (a(1) and a(0) and b(0) ) or
                  (a(0) and b(1) and b(0) );
       temp(3) <= '0';
     elsif a(2) = '1' and b(2) = '1' then --both equal "100"
       temp <= "1000";
     elsif a(2) = '1' then                -- a = "100"
       temp <= "01" & b(1 downto 0);
     else                                 -- b = "100"
       temp <= "01" & a(1 downto 0);
     end if;
  end process;

  f <= temp;
  
end bitcounter8_arch;
