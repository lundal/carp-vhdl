-------------------------------------------------------------------------------
-- Title      : Multiple Rule Tester
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rule_tester_multi.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-03
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Tests multiple development rules against a cell neighborhood.
--            : Note: Hits are available after one clock cycle, while new
--            : type and state is available after two.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-03  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity rule_tester_multi is
  generic (
    cell_type_bits           : positive := 8;
    cell_state_bits          : positive := 1;
    neighborhood_size        : positive := 7;
    rule_amount              : positive := 256;
    rules_tested_in_parallel : positive := 8
  );
  port (
    neighborhood_types_slv  : in std_logic_vector(cell_type_bits * neighborhood_size - 1 downto 0);
    neighborhood_states_slv : in std_logic_vector(cell_state_bits * neighborhood_size - 1 downto 0);

    rules_slv   : in std_logic_vector(rules_tested_in_parallel * (cell_type_bits + 1 + cell_state_bits + 1) * (neighborhood_size + 1) - 1 downto 0);
    rules_first : in std_logic;

    hits : out std_logic_vector(rules_tested_in_parallel - 1 downto 0);

    result_type  : out std_logic_vector(cell_type_bits - 1 downto 0);
    result_state : out std_logic_vector(cell_state_bits - 1 downto 0);

    clock : in std_logic
  );
end rule_tester_multi;

architecture rtl of rule_tester_multi is

  constant condition_bits : positive := cell_type_bits + 1 + cell_state_bits + 1;
  constant rule_size      : positive := condition_bits * (neighborhood_size + 1);

  type rules_type is array (rules_tested_in_parallel - 1 downto 0) of std_logic_vector(rule_size - 1 downto 0);

  signal rules           : rules_type;
  signal rules_first_slv : std_logic_vector(rules_tested_in_parallel - 1 downto 0);

  type types_type  is array (rules_tested_in_parallel - 1 downto 0) of std_logic_vector(cell_type_bits - 1 downto 0);
  type states_type is array (rules_tested_in_parallel - 1 downto 0) of std_logic_vector(cell_state_bits - 1 downto 0);

  signal result_types  : types_type;
  signal result_states : states_type;

  -- Internally used out ports
  signal hits_i : std_logic_vector(rules_tested_in_parallel - 1 downto 0);

begin

  slv_to_array : for i in 0 to rules_tested_in_parallel - 1 generate
    rules(i) <= rules_slv((i+1)*rule_size - 1 downto i*rule_size);
  end generate;

  rule_testers : for i in 0 to rules_tested_in_parallel - 1 generate
    rule_tester : entity work.rule_tester
    generic map (
      cell_type_bits    => cell_type_bits,
      cell_state_bits   => cell_state_bits,
      neighborhood_size => neighborhood_size
    )
    port map (
      neighborhood_types_slv  => neighborhood_types_slv,
      neighborhood_states_slv => neighborhood_states_slv,

      rule       => rules(i),
      rule_first => rules_first_slv(i),

      hit => hits_i(i),

      result_type  => result_types(i),
      result_state => result_states(i),

      clock => clock
    );
  end generate;

  -- Propagate rule_first signal
  process (rules_first) begin
    rules_first_slv    <= (others => '0');
    rules_first_slv(0) <= rules_first;
  end process;

  -- Copy output from tester with hit
  process begin
    wait until rising_edge(clock);
    for i in 0 to rules_tested_in_parallel - 1 loop
      if (hits_i(i) = '1') then
        result_type  <= result_types(i);
        result_state <= result_states(i);
      end if;
    end loop;
  end process;

  -- Internally used out ports
  hits <= hits_i;

end rtl;
