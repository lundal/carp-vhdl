-------------------------------------------------------------------------------
-- Title      : Counter
-- Project    : 
-------------------------------------------------------------------------------
-- File       : counter.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
-- Company    : 
-- Last update: 2003/06/04
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: A generic counter
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2003/02/26  1.0      djupdal	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;

entity counter is

  generic (
    -- number of bits in count register
    SIZE : integer);

  port (
    -- reset register to 0
    reset : in std_logic;
    -- count upwards
    count : in std_logic;

    -- value to count to
    count_to : in unsigned(SIZE - 1 downto 0);

    -- countreg is zero
    zero     : out std_logic;
    -- countreg has reached "count_to"
    finished : out std_logic;
    -- current value of countreg
    value    : out std_logic_vector(SIZE - 1 downto 0);

    clk : in std_logic);

end counter;

architecture counter_arch of counter is

  signal count_reg  : unsigned(SIZE - 1 downto 0);
  signal finished_i : std_logic;

begin

  process (clk)
  begin
    
    if rising_edge (clk) then
      if reset = '1' then
        count_reg <= to_unsigned (0, SIZE);
        zero <= '1';
        
      elsif count = '1' and finished_i = '0' then
        count_reg <= count_reg + 1;
        zero <= '0';
                             
      end if;
    end if;

  end process;

  value <= std_logic_vector(count_reg);
  
  finished_i <= '1' when count_reg = count_to else '0';
  finished <= finished_i;
                                          
end counter_arch;
