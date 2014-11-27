-------------------------------------------------------------------------------
-- Title      : Rule Select
-- Project    : 
-------------------------------------------------------------------------------
-- File       : rule_select.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
-- Company    : 
-- Last update: 2014/01/07
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Selects a result from several rule executives, based on
--              priorities 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/01/07  1.1      stoevneng Parameterized ruleselection.
-- 2003/03/12  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;

entity rule_select is

  port (
    -- vector with hit signals from all rule_execs
    hits : in std_logic_vector(RULES_IN_SET - 1 downto 0);

    -- old sblock data, in case of no rule hits
    old_type  : in std_logic_vector(TYPE_SIZE - 1 downto 0);
    old_state : in std_logic;

    -- results from all rule_execs
    results_type  : in exec_result_type_t;
    results_state : in std_logic_vector(RULES_IN_SET - 1 downto 0);

    -- selected result, to be written to BRAM-1
    result_type  : out std_logic_vector(TYPE_SIZE - 1 downto 0);
    result_state : out std_logic;
--Kaa
    old_selected_rule: in std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
    selected_rule    :out std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
    ruleset          :in std_logic_vector(RULE_SET_SELECT_SIZE - 1 downto 0);
--Kaa
    rst : in std_logic;
    clk : in std_logic);

end rule_select;
    
architecture rule_sel_arch of rule_select is

begin

  process (rst, clk)
  begin

    if rst = '0' then

      result_type <= (others => '0');
      result_state <= '0';
--Kaa
      selected_rule <= (others =>  '0');
--Kaa
    elsif rising_edge (clk) then
      result_type <= old_type;
      result_state <= old_state;
      selected_rule <=  old_selected_rule;
      for i in 0 to RULES_IN_SET - 1 loop
        if hits(i) = '1' then
          result_type <= results_type(i);
          result_state<= results_state(i);
          selected_rule <= ruleset & std_logic_vector(to_unsigned(i,RULES_IN_SET_SIZE));
        end if;
      end loop;
    end if;
  end process;
end rule_sel_arch;

