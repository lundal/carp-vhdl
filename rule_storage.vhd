-------------------------------------------------------------------------------
-- Title      : Rule Storage
-- Project    : 
-------------------------------------------------------------------------------
-- File       : rule_storage.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/01/14
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Storage for rules used in development pipeline
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/01/14  2.1      stoevneng Fully parameterized
-- 2013/12/10  2.0      stoevneng Updated to use inferred BRAM
-- 2003/03/10  1.0      djupdal   Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;

library unisim;

entity rule_storage is

  port (
    -- current set of rules
    ruleset : out rule_set_t;

    -- set ruleset to first set of rules
    cache_set_zero : in  std_logic;
    -- set ruleset to next set of rules
    cache_next_set : in  std_logic;

    -- current set of rules is the last set of rules
    last_set       : out std_logic;

    -- store rule to rule storage
    store_rule    : in std_logic;
    -- priority (address) of rule
    rule_number   : in std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);

    rule_to_store : in std_logic_vector(RULE_SIZE - 1 downto 0);

    -- rule storage must know total number of rules to know when the last set
    -- is reached 
    nbr_of_last_rule : in std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);

    rst : in std_logic;
    clk : in std_logic);

end rule_storage;

architecture rule_storage_arch of rule_storage is

  type state_type is (idle, setup, cache);
  signal state : state_type;
  signal cur_cache : std_logic_vector(RULES_IN_SET_SIZE - 2 downto 0);
  signal next_cache : std_logic_vector(RULES_IN_SET_SIZE - 2 downto 0);

  signal addra        : std_logic_vector(RULE_NBR_BUS_SIZE - 1  downto 0);
  signal addrb        : std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
  signal rule_read_a  : std_logic_vector(RULE_SIZE - 1 downto 0);
  signal rule_read_b  : std_logic_vector(RULE_SIZE - 1 downto 0);
  signal write_enable : std_logic;

  signal reset_counter : std_logic;
  signal count         : std_logic;
  signal count_to      : unsigned(RULE_SET_SELECT_SIZE - 1 downto 0);
  signal value         : std_logic_vector(RULE_SET_SELECT_SIZE - 1 downto 0);
  signal finished      : std_logic;

  signal rst_i        : std_logic;

  signal zero         : std_logic_vector(RULE_SIZE - 1 downto 0);
  signal one          : std_logic_vector(RULES_IN_SET_SIZE - 2 downto 0);

begin

  count_to <= unsigned(nbr_of_last_rule(RULE_NBR_BUS_SIZE - 1 downto RULES_IN_SET_SIZE));

  ruleaddr_counter: counter
    generic map (
      SIZE => RULE_SET_SELECT_SIZE)
    port map (
      reset    => reset_counter,
      count    => count,
      count_to => count_to,
      zero     => open,
      finished => finished,
      value    => value,
      clk      => clk);

  -----------------------------------------------------------------------------

  last_set <= finished;

  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rst = '0' then
      state <= idle;
      ruleset <= (others => (others => '0'));

    elsif rising_edge (clk) then
      case state is

        when idle =>
          if cache_set_zero = '1' or cache_next_set = '1' then
            state <= setup;
            next_cache <= zero(RULES_IN_SET_SIZE - 2 downto 0);
          else
            state <= idle;
          end if;

        when setup =>
          state <= cache;
          cur_cache <= zero(RULES_IN_SET_SIZE - 2 downto 0);
          next_cache <= zero(RULES_IN_SET_SIZE - 3 downto 0) & '1';
        when cache =>
          if cur_cache = one(RULES_IN_SET_SIZE - 2 downto 0) then
            state <= idle;
          end if;
          for i in 0 to RULES_IN_SET/2 - 1 loop
            if std_logic_vector(to_unsigned(i,RULES_IN_SET_SIZE-1)) = cur_cache then
              ruleset(i*2) <= rule_read_a;
              ruleset(i*2+1) <= rule_read_b;
              cur_cache <= std_logic_vector(to_unsigned(i+1,RULES_IN_SET_SIZE-1));
              next_cache <= std_logic_vector(to_unsigned(i+2,RULES_IN_SET_SIZE-1));
              if finished = '1' and nbr_of_last_rule(RULES_IN_SET_SIZE - 1 downto 0) < (cur_cache & '0') then
                ruleset(i*2)(88) <= '0';
              end if;
              if finished = '1' and nbr_of_last_rule(RULES_IN_SET_SIZE - 1 downto 0) < (cur_cache & '1') then
                ruleset(i*2+1)(88) <= '0';
              end if;
            end if;
          end loop;

        when others =>
          state <= idle;

      end case;
    end if;

  end process;

  -----------------------------------------------------------------------------

  addrb(RULE_NBR_BUS_SIZE - 1 downto 1) <= addra(RULE_NBR_BUS_SIZE - 1 downto 1);
  addrb(0) <= '1';

  -----------------------------------------------------------------------------

  process (state, value, cache_set_zero, cache_next_set,
           store_rule, rule_number, rst_i, next_cache, cur_cache, zero, one)
  begin

    write_enable <= '0';
    addra <= (others => '0');
    reset_counter <= '0';
    count <= '0';

    addra(RULE_NBR_BUS_SIZE - 1 downto RULES_IN_SET_SIZE) <= value;
    addra(RULES_IN_SET_SIZE - 1 downto 0) <= zero(RULES_IN_SET_SIZE - 1 downto 0);

    reset_counter <= rst_i;

    case state is

      when idle =>
        if cache_set_zero = '1' then
          reset_counter <= '1';
        end if;

        if cache_next_set = '1' then
          count <= '1';
        end if;

        if store_rule = '1' then
          write_enable <= '1';
          addra <= rule_number;
        end if;

      when setup =>
        addra(RULES_IN_SET_SIZE - 1 downto 1) <= next_cache;

      when cache =>
        if cur_cache /= one(RULES_IN_SET_SIZE-2 downto 0) then
          addra(RULES_IN_SET_SIZE - 1 downto 1) <= next_cache;
        else
          null;
        end if;

      when others =>
        null;

    end case;
        
  end process;

  -----------------------------------------------------------------------------

  rst_i <= not rst;

  zero  <= (others => '0');
  one   <= (others => '1');
  
  -----------------------------------------------------------------------------
  rulestorage : bram_inferrer
    generic map (
      addr_bits => RULE_NBR_BUS_SIZE,
      data_bits => RULE_SIZE)
    port map (
      clk_a => clk,
      clk_b => clk,

      addr_a     => addra,
      data_i_a   => rule_to_store,
      data_o_a   => rule_read_a,
      we_a       => write_enable,
      en_a       => one(0),
      rst_a      => rst_i,

      addr_b     => addrb,
      data_i_b   => zero,
      data_o_b   => rule_read_b,
      we_b       => zero(0),
      en_b       => one(0),
      rst_b      => rst_i);

end rule_storage_arch;
