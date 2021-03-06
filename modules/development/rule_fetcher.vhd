--------------------------------------------------------------------------------
-- Title       : Rule Fetcher
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Fetches N rules from Rule Storage each cycle.
--             : Note: rules_current is extended to prevent wrap-around errors.
--             : Note: Depending on rules_tested_in_parallel, some registers of
--             : rules_current and rules_number may be trimmed.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

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
    rules_number : out std_logic_vector(bits(rule_amount) - 1 downto 0);

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
      if (rules_current + rules_tested_in_parallel <= unsigned(rules_active)) then
        rules_current <= rules_current + rules_tested_in_parallel;
        done_i <= '0';
      else
        rules_current <= (others => '0');
        done_i <= '1';
      end if;

      -- Check if some rules from storage needs to be cleared
      for i in 0 to rules_tested_in_parallel - 1 loop
        if (rules_current + i <= unsigned(rules_active)) then
          rules_clear(i) <= '0';
        else
          rules_clear(i) <= '1';
        end if;
      end loop;

      -- Output the number of the first rule that was fetched
      rules_number <= std_logic_vector(rules_current(rules_number'range));

    end if;
  end process;

  -- Clear rules that should not be tested
  -- Required for when (rule_amount mod rules_active != 0)
  rule_clearer : for i in 0 to rules_tested_in_parallel - 1 generate
    rules_slv((i+1) * rule_size - 1 downto (i) * rule_size)
      <= (others => '0') when (rules_clear(i) = '1') else
      rule_storage_data_slv((i+1) * rule_size - 1 downto (i) * rule_size);
  end generate;

  -- Internally used out ports
  done <= done_i;

end rtl;
