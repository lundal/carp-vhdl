-------------------------------------------------------------------------------
-- Title      : rule number decode and or
-- Project    : 
-------------------------------------------------------------------------------
-- File       : decode_and_or.vhd
-- Author     : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2013/12/20
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Decodes a number of rulenumbers and ORs the results.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2013/12/20  1.0      stoevneng	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.sblock_package.all;

entity decode_and_or is
  port (
    input  : in selected_rule_t;
    output :out std_logic_vector(2 ** RULE_NBR_BUS_SIZE - 1 downto 0));
end decode_and_or;

architecture decode_and_or_arch of decode_and_or is

  type temp_t is array(DEV_PARALLELITY - 1 downto 0) of unsigned(RULE_NBR_BUS_SIZE - 1 downto 0);
  signal temp: temp_t;

begin
  tempin: for i in 0 to DEV_PARALLELITY - 1 generate
    temp(i) <= unsigned(input(i));
  end generate tempin;

  process(temp)
  begin
    for n in 0 to 2 ** RULE_NBR_BUS_SIZE - 1 loop
      output(n) <= '0';
      for i in 0 to DEV_PARALLELITY - 1 loop
        if temp(i) = to_unsigned(n,RULE_NBR_BUS_SIZE) then
          output(n) <= '1';
        end if;
      end loop;
    end loop;
  end process;
  
end decode_and_or_arch;
