-------------------------------------------------------------------------------
-- Title      : Rule Tester
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rule_tester.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-03
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Tests a development rule against a cell neighborhood (async)
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

entity rule_tester is
  generic (
    cell_type_bits    : positive := 8;
    cell_state_bits   : positive := 1;
    neighborhood_size : positive := 7
  );
  port (
    types_slv  : in std_logic_vector(cell_type_bits * neighborhood_size - 1 downto 0);
    states_slv : in std_logic_vector(cell_state_bits * neighborhood_size - 1 downto 0);

    rule : in std_logic_vector((cell_type_bits + 1 + cell_state_bits + 1) * (neighborhood_size + 1) - 1 downto 0);

    type_out  : out std_logic_vector(cell_type_bits - 1 downto 0);
    state_out : out std_logic_vector(cell_state_bits - 1 downto 0);

    hit : out std_logic
  );
end rule_tester;

architecture rtl of rule_tester is

  constant condition_bits    : positive := cell_type_bits + 1 + cell_state_bits + 1;

  type types_type  is array (neighborhood_size - 1 downto 0) of std_logic_vector(cell_type_bits - 1 downto 0);
  type states_type is array (neighborhood_size - 1 downto 0) of std_logic_vector(cell_state_bits - 1 downto 0);

  signal types  : types_type;
  signal states : states_type;

  type result_type is record
    type_i       : std_logic_vector(cell_type_bits - 1 downto 0);
    type_change  : std_logic;
    state_i      : std_logic_vector(cell_state_bits - 1 downto 0);
    state_change : std_logic;
  end record;

  signal result : result_type;

  type condition_type is record
    type_i      : std_logic_vector(cell_type_bits - 1 downto 0);
    type_check  : std_logic;
    state_i     : std_logic_vector(cell_state_bits - 1 downto 0);
    state_check : std_logic;
  end record;

  type conditions_type is array (neighborhood_size - 1 downto 0) of condition_type;
  type conditions_slv_type is array (neighborhood_size - 1 downto 0) of std_logic_vector(condition_bits - 1 downto 0);

  signal conditions     : conditions_type;
  signal conditions_slv : conditions_slv_type;
  signal conditions_ok  : std_logic_vector(neighborhood_size - 1 downto 0);

begin

  -- Extract result (first "condition")
  result.type_i       <= rule(condition_bits - 1 downto 1 + cell_state_bits + 1);
  result.type_change  <= rule(cell_state_bits + 1);
  result.state_i      <= rule(cell_state_bits downto 1);
  result.state_change <= rule(0);

  split : for i in 0 to neighborhood_size - 1 generate
    -- Create condition array
    conditions_slv(i) <= rule((i+2)*condition_bits - 1 downto (i+1)*condition_bits);

    -- Extract conditions
    conditions(i).type_i      <= conditions_slv(i)(condition_bits - 1 downto 1 + cell_state_bits + 1);
    conditions(i).type_check  <= conditions_slv(i)(cell_state_bits + 1);
    conditions(i).state_i     <= conditions_slv(i)(cell_state_bits downto 1);
    conditions(i).state_check <= conditions_slv(i)(0);

    -- Create type and state arrays
    types(i)  <= types_slv((i+1)*cell_type_bits - 1 downto i*cell_type_bits);
    states(i) <= states_slv((i+1)*cell_state_bits - 1 downto i*cell_state_bits);
  end generate;

  condition_checks : for i in 0 to neighborhood_size - 1 generate
    conditions_ok(i) <= '1' when (conditions(i).type_i = types(i) or conditions(i).type_check = '0')
                            and (conditions(i).state_i = states(i) or conditions(i).state_check = '0') else '0';
  end generate;

  -- Mark as hit when rule is valid and all conditions are ok
  hit <= '1' when (result.type_change = '1' or result.state_change = '1')
             and conditions_ok = (conditions_ok'range => '1') else '0';

  -- Output new type and state
  type_out  <= result.type_i when result.type_change = '1' else types(0);
  state_out <= result.state_i when result.state_change = '1' else states(0);

end rtl;
