-------------------------------------------------------------------------------
-- Title      : Rule Executive
-- Project    : 
-------------------------------------------------------------------------------
-- File       : rule_exec.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/02/24
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Calculates a result given a rule and preconditions
--              Uses two pipeline stages
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/02/24  2.0      stoevneng Removed Growth
-- 2013/12/16  1.5      stoevneng Updated to support TYPE_SIZE different from 5
-- 2003/03/11  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;

entity rule_executive is

  port (
    -- neighbourhood data
      north_type   : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      south_type   : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      east_type    : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      west_type    : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      center_type  : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      north_state  : in  std_logic;
      south_state  : in  std_logic;
      east_state   : in  std_logic;
      west_state   : in  std_logic;
      center_state : in  std_logic;

    -- rule to check
    rule : in std_logic_vector(RULE_SIZE - 1 downto 0);

    -- the rule conditions are true
    hit          : out std_logic;

    -- result after applying rule
    result_type  : out std_logic_vector(TYPE_SIZE - 1 downto 0);
    result_state : out std_logic;

    rst : in std_logic;
    clk : in std_logic);

end rule_executive;

architecture rule_exec_arch of rule_executive is
  constant ones : std_logic_vector(NEIGH_SIZE - 1 downto 0) :=  (others => '1');

  signal states : std_logic_vector(NEIGH_SIZE - 1 downto 0);
  signal types  : rule_type_t;

  signal rule_valid : std_logic;
  
  signal rule_state_dc : std_logic_vector(NEIGH_SIZE - 1 downto 0);
  signal rule_state    : std_logic_vector(NEIGH_SIZE - 1 downto 0);
  signal rule_type_dc  : std_logic_vector(NEIGH_SIZE - 1 downto 0);
  signal rule_type     : rule_type_t;

  signal rule_dont_change_state : std_logic;
  signal rule_change_state_to   : std_logic;
  signal rule_change_type_to    : std_logic_vector(TYPE_SIZE - 1 downto 0);

  -----------------------------------------------------------------------------


  signal ex1_rule_valid : std_logic;

  signal ex1_typeeq  : std_logic_vector(NEIGH_SIZE - 1 downto 0);
  signal ex1_stateeq : std_logic_vector(NEIGH_SIZE - 1 downto 0);
  
  signal ex1_result_type  : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal ex1_result_state : std_logic;

begin

  types(4)  <= north_type;
  types(3)  <= south_type;
  types(2)  <= east_type;
  types(1)  <= west_type;
  types(0)  <= center_type;

  states(4) <= north_state;
  states(3) <= south_state;
  states(2) <= east_state;
  states(1) <= west_state;
  states(0) <= center_state;
  
  -----------------------------------------------------------------------------
  -- extract individual fields from rule
  -----------------------------------------------------------------------------

  rule_valid <= rule(88);

  -----------------------------------------------------------------------------
  extract_loop: for i in 0 to NEIGH_SIZE - 1 generate
    rule_state_dc(i) <= rule(20 + 11 * i);
    rule_state(i)    <= rule(19 + 11 * i);
    rule_type_dc(i)  <= rule(18 + 11 * i);
    rule_type(i)     <= rule(TYPE_SIZE + 9 + 11*i downto 10 + 11*i);
  end generate extract_loop;
  -----------------------------------------------------------------------------

  rule_dont_change_state <= rule(9);
  rule_change_state_to   <= rule(8);
  rule_change_type_to    <= rule(TYPE_SIZE - 1 downto 0);

  -----------------------------------------------------------------------------
  -- check for hit
  -----------------------------------------------------------------------------

  process (rst, clk)

  begin

    if rst = '0' then

      ex1_rule_valid <= '0';

      ex1_stateeq <= (others => '0');
      ex1_typeeq  <= (others => '0');

      hit <= '0';

    elsif rising_edge (clk) then

      ex1_rule_valid <= rule_valid;

      -- compare type

      for i in 0 to NEIGH_SIZE - 1 loop
        if rule_type(i) = types(i) or rule_type_dc(i) = '1' then
          ex1_typeeq(i) <= '1';
        else
          ex1_typeeq(i) <= '0';
        end if;
        
        if rule_state(i) = states(i) or rule_state_dc(i) = '1' then
          ex1_stateeq(i) <= '1';
        else
          ex1_stateeq(i) <= '0';
        end if;
      end loop;

      -------------------------------------------------------------------------
      if ex1_rule_valid = '1' and ex1_typeeq = ones and ex1_stateeq = ones then
        hit <= '1';
      else
        hit <= '0';
      end if;
    end if;

  end process;

  -----------------------------------------------------------------------------
  -- calculate result
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rst = '0' then

    elsif rising_edge (clk) then

      ex1_result_type <= rule_change_type_to;
      if rule_dont_change_state = '1' then
        ex1_result_state <= center_state;
      else
        ex1_result_state <= rule_change_state_to;
      end if;

      result_type <= ex1_result_type;
      result_state <= ex1_result_state;

    end if;

  end process;

end rule_exec_arch;
