-------------------------------------------------------------------------------
-- Title      : bitcount4
-- Project    : 
-------------------------------------------------------------------------------
-- File       : bitcount4.vhd
-- Author     : Kjetil Aamodt
-- Company    : 
-- Last update: 2005/02/22
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
use work.sblock_package.all;


entity bitcounter4 is
  
  port (
    a : in  std_logic;
    b : in  std_logic;
    c : in  std_logic;
    d : in  std_logic;
    f : out std_logic_vector (2 downto 0));

end bitcounter4;


architecture bitcounter4_arch of bitcounter4 is

  signal temp : std_logic_vector (2 downto 0);

begin  -- bitcount4_arch
  process(a,b,c,d)
  variable ab, ac, ad, bc, bd, cd : std_logic;-- and functions for two signals
  variable abcd : std_logic;
                                        
  begin
    ab := a and b;
    ac := a and c;
    ad := a and d;
    bc := b and c;
    bd := b and d;
    cd := c and d;
    abcd := a and b and c and d;

    temp(0) <= not abcd and
               ((a and not b and not c and not d) or
                (b and not a and not c and not d) or
                (c and not a and not b and not d) or
                (d and not a and not b and not c) or
                (a and b and c) or
                (b and c and d) or
                (a and c and d) or
                (a and b and d)
               );
    temp(1) <= (ab or ac or ad or bc or bd or cd) and not abcd;
    temp(2) <= abcd;
  end process;

  f <= temp;
  
end bitcounter4_arch;
