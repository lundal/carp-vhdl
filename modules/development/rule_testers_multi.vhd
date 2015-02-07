-------------------------------------------------------------------------------
-- Title      : Multiple Rule Testers
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rule_testers_multi.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-06
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Tests multiple development rules against cell neighborhoods
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-06  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;


entity rule_testers_multi is
  generic (
    cell_type_bits           : positive := 8;
    cell_state_bits          : positive := 1;
    neighborhood_size        : positive := 7;
    rules_tested_in_parallel : positive := 2;
    cells_tested_in_parallel : positive := 8
  );
  port (
    neighborhoods_types_slv  : in std_logic_vector(cells_tested_in_parallel * cell_type_bits * neighborhood_size - 1 downto 0);
    neighborhoods_states_slv : in std_logic_vector(cells_tested_in_parallel * cell_state_bits * neighborhood_size - 1 downto 0);

    rules_slv : in std_logic_vector(rules_tested_in_parallel * (cell_type_bits + 1 + cell_state_bits + 1) * (neighborhood_size + 1) - 1 downto 0);

    types_out  : out std_logic_vector(cells_tested_in_parallel * cell_type_bits - 1 downto 0);
    states_out : out std_logic_vector(cells_tested_in_parallel * cell_state_bits - 1 downto 0);

    hits        : out std_logic_vector(cells_tested_in_parallel - 1 downto 0);
    hits_number : out std_logic_vector(cells_tested_in_parallel * bits(rules_tested_in_parallel) - 1 downto 0);

    clock : in std_logic
  );
end rule_testers_multi;

architecture rtl of rule_testers_multi is

begin

  testers : for i in 0 to cells_tested_in_parallel - 1 generate
    tester : entity work.rule_tester_multi
    generic map (
      cell_type_bits           => cell_type_bits,
      cell_state_bits          => cell_state_bits,
      neighborhood_size        => neighborhood_size,
      rules_tested_in_parallel => rules_tested_in_parallel
    )
    port map (
      neighborhood_types_slv  => neighborhoods_types_slv((i+1) * cell_type_bits * neighborhood_size - 1 downto i * cell_type_bits * neighborhood_size),
      neighborhood_states_slv => neighborhoods_states_slv((i+1) * cell_state_bits * neighborhood_size - 1 downto i * cell_state_bits * neighborhood_size),

      rules_slv => rules_slv,

      type_out  => types_out((i+1) * cell_type_bits - 1 downto i * cell_type_bits),
      state_out => states_out((i+1) * cell_state_bits - 1 downto i * cell_state_bits),

      hit        => hits(i),
      hit_number => hits_number((i+1) * bits(rules_tested_in_parallel) - 1 downto i * bits(rules_tested_in_parallel)),

      clock => clock
    );
  end generate;

end rtl;

