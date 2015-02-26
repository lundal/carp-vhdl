-------------------------------------------------------------------------------
-- Title      : Hits To Vector
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : hits_to_vector.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-08
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Processes hits from rule testers into rule vectors.
--            : Note: Generates up to (rules_tested_in_parallel) unconnected.
--            : Note: Must be reset before first hits.
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

entity hits_to_vector is
  generic (
    rule_amount              : positive := 256;
    rules_tested_in_parallel : positive := 8;
    cells_tested_in_parallel : positive := 8
  );
  port (
    hits_slv : in std_logic_vector(cells_tested_in_parallel * rules_tested_in_parallel - 1 downto 0);

    rule_number : in std_logic_vector(bits(rule_amount) - 1 downto 0);

    rule_vector : out std_logic_vector(rule_amount - 1 downto 0);

    reset : in std_logic;

    clock : in std_logic
  );
end hits_to_vector;

architecture rtl of hits_to_vector is

  constant vector_padding_bits : natural := rules_tested_in_parallel - rule_amount mod rules_tested_in_parallel;

  type hits_type is array (cells_tested_in_parallel - 1 downto 0) of std_logic_vector(rules_tested_in_parallel - 1 downto 0);

  signal hits      : hits_type;
  signal hits_ored : hits_type;

  -- Internally used out ports
  signal rule_vector_i : std_logic_vector(vector_padding_bits + rule_amount - 1 downto 0);

begin

  slv_to_array : for i in 0 to cells_tested_in_parallel - 1 generate
    hits(i) <= hits_slv((i+1) * rules_tested_in_parallel - 1 downto i * rules_tested_in_parallel);
  end generate;

  -- Or together hits from different cells
  hits_ored(0) <= hits(0);
  hits_orer : for i in 1 to cells_tested_in_parallel - 1 generate
    hits_ored(i) <= hits_ored(i-1) or hits(i);
  end generate;

  -- Build rule vector
  process begin
    wait until rising_edge(clock);

    -- Clear vector
    if (reset = '1') then
      rule_vector_i <= (others => '0');
    else
      -- Insert hits into vector (OR with previous values from other cells)
      -- Note: Requires (rule_number mod rules_tested_in_parallel) to be zero.
      for i in 0 to rule_amount / rules_tested_in_parallel loop
        if (unsigned(rule_number) = i * rules_tested_in_parallel) then
          rule_vector_i((i+1) * rules_tested_in_parallel - 1 downto i * rules_tested_in_parallel)
            <= rule_vector_i((i+1) * rules_tested_in_parallel - 1 downto i * rules_tested_in_parallel)
            or hits_ored(hits_ored'high);
        end if;
      end loop;
    end if;

  end process;

  -- Internally used out ports
  rule_vector <= rule_vector_i(rule_vector'range);

end rtl;
