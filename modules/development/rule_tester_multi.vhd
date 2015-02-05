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
-- Description: Tests multiple development rules against a cell neighborhood
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
    rules_tested_in_parallel : positive := 2
  );
  port (
    neighborhood_types_slv  : in std_logic_vector(cell_type_bits * neighborhood_size - 1 downto 0);
    neighborhood_states_slv : in std_logic_vector(cell_state_bits * neighborhood_size - 1 downto 0);

    rules_slv : in std_logic_vector(rules_tested_in_parallel * (cell_type_bits + 1 + cell_state_bits + 1) * (neighborhood_size + 1) - 1 downto 0);

    type_out  : out std_logic_vector(cell_type_bits - 1 downto 0);
    state_out : out std_logic_vector(cell_state_bits - 1 downto 0);

    hit        : out std_logic;
    hit_number : out std_logic_vector(bits(rules_tested_in_parallel) - 1 downto 0);

    clock : in std_logic
  );
end rule_tester_multi;

architecture rtl of rule_tester_multi is

  constant condition_bits : positive := cell_type_bits + 1 + cell_state_bits + 1;
  constant rule_size      : positive := condition_bits * (neighborhood_size + 1);

  type rules_type is array (rules_tested_in_parallel - 1 downto 0) of std_logic_vector(rule_size - 1 downto 0);

  signal rules : rules_type;

  type types_type  is array (rules_tested_in_parallel - 1 downto 0) of std_logic_vector(cell_type_bits - 1 downto 0);
  type states_type is array (rules_tested_in_parallel - 1 downto 0) of std_logic_vector(cell_state_bits - 1 downto 0);

  signal types  : types_type;
  signal states : states_type;

  signal hits : std_logic_vector(rules_tested_in_parallel - 1 downto 0);

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

      rule => rules(i),

      type_out  => types(i),
      state_out => states(i),

      hit => hits(i)
    );
  end generate;

  process begin
    wait until rising_edge(clock);

    -- Default
    hit        <= '0';
    hit_number <= (others => '0');
    type_out   <= neighborhood_types_slv(cell_type_bits - 1 downto 0);
    state_out  <= neighborhood_states_slv(cell_state_bits - 1 downto 0);

    -- Select output
    for i in 0 to rules_tested_in_parallel - 1 loop
      if (hits(i) = '1') then
        hit        <= '1';
        hit_number <= std_logic_vector(to_unsigned(i, hit_number'length));
        type_out   <= types(i);
        state_out  <= states(i);
      end if;
    end loop;

  end process;

end rtl;
