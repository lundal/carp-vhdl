-------------------------------------------------------------------------------
-- Title      : Address Generator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : addr_gen.vhd
-- Author     : Asbjørn Djupdal  <djupdal@harryklein>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/01/04
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: From sblock (x,y) to SBM BRAM address
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/01/04  2.0      stoevneng Updated to match new BRAM layout
-- 2003/02/22  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

entity addr_gen is
  
  port (
    ---------------------------------------------------------------------------
    -- input values, x and y position in sblock matrix

    x : in std_logic_vector(COORD_SIZE_X - 1 downto 0);
    y : in std_logic_vector(COORD_SIZE_Y - 1 downto 0);

    ---------------------------------------------------------------------------
    -- output values

    -- BRAM address
    addr          : out std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
    -- sblock databuses from BRAM are four sblocks wide
    -- This signals shows which of the four sblocks are addressed
    sblock_number : out std_logic_vector(1 downto 0);
    -- BRAM-0 and BRAM-1 are made up from four sets of RAM blocks; two for even
    -- and two for odd sblock rows and collumns. 
    -- This signal shows if current sblock is in the even or odd RAM block
    -- and thus shows which read/write ports to use on the BRAM
    port_select   : out std_logic_vector(1 downto 0));

end addr_gen;

architecture addr_gen_arch of addr_gen is

begin

  addr((COORD_SIZE_X + COORD_SIZE_Y - 5) downto COORD_SIZE_X - 3) <=
    y(COORD_SIZE_Y - 1 downto 1);
  addr(COORD_SIZE_X - 4 downto 0) <= x(COORD_SIZE_X - 1 downto 3);

  sblock_number <= x(1 downto 0);
  port_select(1) <= y(0);
  port_select(0) <= x(2);

end addr_gen_arch;
