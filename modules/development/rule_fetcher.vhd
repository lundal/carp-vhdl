-------------------------------------------------------------------------------
-- Title      : Rule Fetcher
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rule_fetcher.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-07
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Fetches N rules from storage each cycle.
--            : rules_current is extended to prevent wrap-around errors.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-07  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity rule_fetcher is
  generic (
    rule_amount              : positive := 256;
    rule_size                : positive := 80;
    rules_tested_in_parallel : positive := 4
  );
  port (
    rule_storage_address_slv : out std_logic_vector(rules_tested_in_parallel * bits(rule_amount) - 1 downto 0);
    rule_storage_data_slv    : in  std_logic_vector(rules_tested_in_parallel * rule_size - 1 downto 0);

    rules_active : in  std_logic_vector(bits(rule_amount) - 1 downto 0);
    rules_slv    : out std_logic_vector(rules_tested_in_parallel * rule_size - 1 downto 0);

    run  : in std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end rule_fetcher;

architecture rtl of rule_fetcher is

  signal rules_current : unsigned(bits(rule_amount + rules_tested_in_parallel) - 1 downto 0) := (others => '0');

  signal rules_clear : std_logic_vector(rules_tested_in_parallel - 1 downto 0);

  signal done_i : std_logic := '1';

begin

  storage_addresses : for i in 0 to rules_tested_in_parallel - 1 generate
    rule_storage_address_slv((i+1) * bits(rule_amount) - 1 downto (i) * bits(rule_amount))
      <= std_logic_vector(resize(rules_current + i, bits(rule_amount)));
  end generate;

  process begin
    wait until rising_edge(clock);

    if (run = '1' or not done_i = '1') then
      -- Next rules
      if (rules_current + rules_tested_in_parallel < unsigned(rules_active)) then
        rules_current <= rules_current + rules_tested_in_parallel;
        done_i <= '0';
      else
        rules_current <= (others => '0');
        done_i <= '1';
      end if;

      -- Check if some rules from storage needs to be cleared
      for i in 0 to rules_tested_in_parallel - 1 loop
        if (rules_current + i < unsigned(rules_active)) then
          rules_clear(i) <= '0';
        else
          rules_clear(i) <= '1';
        end if;
      end loop;

    end if;
  end process;

  rule_clearer : for i in 0 to rules_tested_in_parallel - 1 generate
    rules_slv((i+1) * rule_size - 1 downto (i) * rule_size)
      <= (others => '0') when (rules_clear(i) = '1') else
      rule_storage_data_slv((i+1) * rule_size - 1 downto (i) * rule_size);
  end generate;

  -- Internally used out ports
  done <= done_i;

end rtl;
