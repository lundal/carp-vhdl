-------------------------------------------------------------------------------
-- Title      : Hits To Numbers
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : hits_to_numbers.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-08
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Processes hits from rule testers into rule numbers.
--            : Note: Assumes testers tag rule zero as hit (resets registers).
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-08  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity hits_to_numbers is
  generic (
    rule_amount              : positive := 256;
    rules_tested_in_parallel : positive := 8;
    cells_tested_in_parallel : positive := 8
  );
  port (
    hits_slv : in std_logic_vector(cells_tested_in_parallel * rules_tested_in_parallel - 1 downto 0);

    rule_number : in std_logic_vector(bits(rule_amount) - 1 downto 0);

    rule_numbers_slv : out std_logic_vector(cells_tested_in_parallel * bits(rule_amount) - 1 downto 0);

    clock : in std_logic
  );
end hits_to_numbers;

architecture rtl of hits_to_numbers is

  type hits_type is array (cells_tested_in_parallel - 1 downto 0) of std_logic_vector(rules_tested_in_parallel - 1 downto 0);

  signal hits : hits_type;

  type rule_numbers_type is array (cells_tested_in_parallel - 1 downto 0) of std_logic_vector(bits(rule_amount) - 1 downto 0);

  signal rule_numbers : rule_numbers_type;

begin

  slv_to_array : for i in 0 to cells_tested_in_parallel - 1 generate
    hits(i) <= hits_slv((i+1) * rules_tested_in_parallel - 1 downto i * rules_tested_in_parallel);
  end generate;

  process begin
    wait until rising_edge(clock);

    for i in 0 to cells_tested_in_parallel - 1 loop
      for k in 0 to rules_tested_in_parallel - 1 loop
        if (hits(i)(k) = '1') then
          rule_numbers(i) <= std_logic_vector(unsigned(rule_number) + k);
        end if;
      end loop;
    end loop;

  end process;

  array_to_slv : for i in 0 to cells_tested_in_parallel - 1 generate
    rule_numbers_slv((i+1) * bits(rule_amount) - 1 downto i * bits(rule_amount)) <= rule_numbers(i);
  end generate;

end rtl;
