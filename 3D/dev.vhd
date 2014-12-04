-------------------------------------------------------------------------------
-- Title      : Development Pipeline
-- Project    :
-------------------------------------------------------------------------------
-- File       : dev.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
--            : Per Thomas Lundal
-- Company    :
-- Last update: 2014/12/03
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Pipeline for doing a development step from BRAM-0 to BRAM-1
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/12/03  3.6      lundal    Bugfixes
-- 2014/03/20  3.5      stoevneng Updated for 3D
-- 2014/02/03  3.0      stoevneng Extended to compute 8 SBLOCKS each cycle
-- 2005/04/03  2.0      aamodt    Added logic for fired rules control
-- 2003/03/10  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;
use work.funct_package.all;

entity dev is

  port (
    -- rule storage

    ruleset : in rule_set_t;

    cache_set_zero : out std_logic;
    cache_next_set : out std_logic;
    last_set       : in  std_logic;

    -- sbm bram mgr

    type_data_read_0    : in  bram_type_bus_t;
    state_data_read_0   : in  bram_state_bus_t;
    addr_0              : out bram_addr_t;
    type_data_write_1   : out bram_type_bus_t;
    type_data_read_1    : in  bram_type_bus_t;
    state_data_read_1   : in  bram_state_bus_t;
    state_data_write_1  : out bram_state_bus_t;
    addr_1              : out bram_addr_t;
    dev_enable_read_0   : out std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
    dev_enable_read_1b  : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
    dev_enable_write_1a : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);



--Kaa
    dev_usedrules_read         :  in std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
    dev_usedrules_write        : out std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
    dev_usedrules_addr_read    : out std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
    dev_usedrules_addr_write   : out std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
    dev_usedrules_read_enable  : out std_logic;
    dev_usedrules_write_enable : out std_logic;

    dev_rulevector_data_write  : out std_logic_vector(RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
    dev_rulevector_write_enable: out std_logic;
--Kaa

    -- decode
    dec_start_devstep  : in  std_logic;

    -- hazard
    dev_idle       : out std_logic;

-- other
    rst : in std_logic;
    clk : in std_logic);

end dev;

architecture dev_arch of dev is

  signal zero : std_logic_vector(COORD_SIZE_X - 1 downto 0);

  -----------------------------------------------------------------------------
  -- signals are grouped after the pipeline stage they are used in
  -- pipeline registers are named with the pipeline stage name as prefix
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Control

  type control_state_type is (idle, prepare_pipe, run, next_ruleset);

  signal control_state : control_state_type;

  signal dev_enable_read : std_logic;

  signal count_column            : std_logic;
  signal column_counter_zero     : std_logic;
  signal column_counter_zero_reg     : std_logic;
  signal column_counter_finished : std_logic;
  signal column_counter_finished_reg : std_logic;
  signal reset_column_counter    : std_logic;
  signal column_count_to         : unsigned(COORD_SIZE_X - DEV_PAR_SIZE - 1 downto 0);

  signal column_minus_1 : std_logic_vector(COORD_SIZE_X - 1 downto 0);
  signal column_value   : std_logic_vector(COORD_SIZE_X - 1 downto 0);
  signal column_plus_1  : std_logic_vector(COORD_SIZE_X - 1 downto 0);
  signal column_plus_1_i : std_logic_vector(COORD_SIZE_X - DEV_PAR_SIZE - 1 downto 0);

  signal count_row            : std_logic;
  signal row_counter_zero     : std_logic;
  signal row_counter_zero_reg     : std_logic;
  signal row_counter_finished : std_logic;
  signal row_counter_finished_reg : std_logic;
  signal reset_row_counter    : std_logic;
  signal row_count_to         : unsigned(COORD_SIZE_Y - 1 downto 0);

--Kaa
  --actual rule set
  signal count_ruleset             : std_logic;
  signal ruleset_value             : std_logic_vector(RULE_SET_SELECT_SIZE - 1 downto 0);
  signal ruleset_counter_zero      : std_logic;
  signal ruleset_counter_finished  : std_logic;
  signal reset_ruleset_counter     : std_logic;
  signal ruleset_count_to          : unsigned(RULE_SET_SELECT_SIZE - 1 downto 0);
--Kaa
  signal row_minus_1 : std_logic_vector(COORD_SIZE_Y - 1 downto 0);
  signal row_value   : std_logic_vector(COORD_SIZE_Y - 1 downto 0);
  signal row_plus_1  : std_logic_vector(COORD_SIZE_Y - 1 downto 0);
  signal row_plus_1_i : std_logic_vector(COORD_SIZE_Y - 1 downto 0);

  signal count_layer                : std_logic;
  signal count_layer_reg            : std_logic;
  signal layer_counter_zero         : std_logic;
  signal layer_counter_finished     : std_logic;
  signal reset_layer_counter        : std_logic;
  signal layer_count_to             : unsigned(COORD_SIZE_Z - 1 downto 0);

  signal layer_minus_1 : std_logic_vector(COORD_SIZE_Z - 1 downto 0);
  signal layer_value   : std_logic_vector(COORD_SIZE_Z - 1 downto 0);
  signal layer_plus_1  : std_logic_vector(COORD_SIZE_Z - 1 downto 0);
  signal layer_plus_1_i : std_logic_vector(COORD_SIZE_Z - 1 downto 0);

  signal port_select   : std_logic_vector(2 downto 0);
  signal rst_countregs : std_logic;

  signal addr_center : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal addr_north  : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal addr_south  : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal addr_up     : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal addr_down   : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);

  signal use_prev : std_logic;

  -- pipeline signals

  -- signals an access to next pipeline stage
  signal control_access       : std_logic;
  -- shows which read/write ports to use on the BRAM
  -- see addr_gen.vhd for details
  signal control_port_select  : std_logic_vector(2 downto 0);
  -- address of current two sblocks
  signal control_address      : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);

--Kaa
  signal control_usedrules_addr: std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal temp_usedrules_addr: std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);

  signal control_clear_rulevector : std_logic;
  signal control_last_sblock_last_ruleset: std_logic;

  signal addr_1_read  : bram_addr_half_t;
  signal addr_1_write : bram_addr_half_t;
  -----------------------------------------------------------------------------
  -- Fetch1

  signal fetch1_access       : std_logic;
  signal fetch1_port_select  : std_logic_vector(2 downto 0);
  signal fetch1_address      : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
--Kaa
  signal fetch1_usedrules_addr: std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal fetch1_clear_rulevector : std_logic;
  signal fetch1_last_sblock_last_ruleset: std_logic;
--Kaa
  -----------------------------------------------------------------------------
  -- Fetch2

  signal fetch2_access       : std_logic;
  signal fetch2_port_select  : std_logic_vector(2 downto 0);
  signal fetch2_address      : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
--Kaa
  signal fetch2_usedrules_addr   : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal fetch2_clear_rulevector : std_logic;
  signal fetch2_last_sblock_last_ruleset: std_logic;
--Kaa
  -----------------------------------------------------------------------------
  -- Setup

  signal type_east  : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);
  signal type_west  : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);
  signal type_north : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);
  signal type_south : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);
  signal type_up    : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);
  signal type_down  : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);

  signal state_east  : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal state_west  : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal state_north : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal state_south : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal state_up    : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal state_down  : std_logic_vector(DEV_PARALLELITY - 1 downto 0);

  signal type_center  : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);
  signal state_center : std_logic_vector(DEV_PARALLELITY - 1 downto 0);

  signal type_center_prev  : std_logic_vector(TYPE_SIZE * DEV_PARALLELITY - 1 downto 0);
  signal state_center_prev : std_logic_vector(DEV_PARALLELITY - 1 downto 0);

  -- pipeline signals

  signal setup_access      : std_logic;
  signal setup_port_select : std_logic_vector(2 downto 0);
  signal setup_address     : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);

  -- type data for self and neighbourhood
  type type_t is array (DEV_PARALLELITY - 1 downto 0)
    of std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal setup_up_type     : type_t;
  signal setup_down_type   : type_t;
  signal setup_north_type  : type_t;
  signal setup_south_type  : type_t;
  signal setup_east_type   : type_t;
  signal setup_west_type   : type_t;
  signal setup_center_type : type_t;

  -- state data for self and neighbourhood
  signal setup_up_state     : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal setup_down_state   : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal setup_north_state  : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal setup_south_state  : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal setup_east_state   : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal setup_west_state   : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
  signal setup_center_state : std_logic_vector(DEV_PARALLELITY - 1 downto 0);

  -- old type and state for center sblocks, used if no rule is fired
  signal setup_old_type  : type_t;
  signal setup_old_state : std_logic_vector(DEV_PARALLELITY - 1 downto 0);

--Kaa
  signal setup_usedrules_addr        : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal setup_old_selected_rule : std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  signal setup_clear_rulevector : std_logic;
  signal setup_last_sblock_last_ruleset: std_logic;
--Kaa

  -----------------------------------------------------------------------------
  -- Execute1

  signal ex1_access      : std_logic;
  signal ex1_port_select : std_logic_vector(2 downto 0);
  signal ex1_address     : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal ex1_old_type  : type_t;
  signal ex1_old_state : std_logic_vector(DEV_PARALLELITY - 1 downto 0);
--Kaa
  signal ex1_usedrules_addr     : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal ex1_old_selected_rule  : selected_rule_t;
  signal ex1_clear_rulevector : std_logic;
  signal ex1_last_sblock_last_ruleset: std_logic;
--Kaa

  -----------------------------------------------------------------------------
  -- Execute2

  -- vectors with hit signals for DEV_PARALLELITY sblocks
  -- All rules have a corresponding bit in these vectors and sets the bit if the
  -- rule should fire
  type ex2_hit_t          is array(DEV_PARALLELITY - 1 downto 0)
                            of std_logic_vector(RULES_IN_SET - 1 downto 0);
  type ex2_result_type_t  is array(DEV_PARALLELITY - 1 downto 0)
                            of exec_result_type_t;
  type ex2_result_state_t is array(DEV_PARALLELITY - 1 downto 0)
                            of std_logic_vector(RULES_IN_SET - 1 downto 0);
  signal ex2_hit           : ex2_hit_t;
  -- results for the sblocks
  -- Used if one of the rules have a hit
  signal ex2_result_type   : ex2_result_type_t;
  signal ex2_result_state  : ex2_result_state_t;


  signal ex2_access      : std_logic;
  signal ex2_port_select : std_logic_vector(2 downto 0);
  signal ex2_address     : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal ex2_old_type    : type_t;
  signal ex2_old_state   : std_logic_vector(DEV_PARALLELITY - 1 downto 0);

--Kaa
  signal ex2_usedrules_addr     : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal ex2_old_selected_rule: selected_rule_t;
  signal ex2_clear_rulevector : std_logic;
  signal ex2_last_sblock_last_ruleset: std_logic;

  signal ex2_rulevector     : std_logic_vector(255 downto 0);
--Kaa

  -----------------------------------------------------------------------------
  -- Select

  -- sblock data to be written to BRAM-1
  signal select_result_type  : std_logic_vector(DEV_PARALLELITY * TYPE_SIZE - 1 downto 0);
  signal select_result_state : std_logic_vector(DEV_PARALLELITY - 1 downto 0);

  signal select_access      : std_logic;
  signal select_port_select : std_logic_vector(2 downto 0);
  signal select_address     : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);

--Kaa
  signal select_usedrules_addr : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal select_selected_rule  : selected_rule_t;

  signal select_rulevector     : std_logic_vector(255 downto 0);
  signal select_rulevector_conc  : std_logic_vector(255 downto 0);

  signal select_write_rulevector: std_logic;
  signal select_clear_rulevector : std_logic;
  signal select_last_sblock_last_ruleset: std_logic;
--Kaa

-- Store

-- dev functions
  type bram_port_t is array (0 to PARALLEL_DEV_WORDS - 1) of integer;

  function bram_center (
    c : std_logic_vector)
    return bram_port_t is
    variable result: bram_port_t;
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1 loop
      result(i) := to_integer(unsigned(c)) * 2 + i * 2;
    end loop;
    if PARALLEL_DEV_WORDS = 2 then
      if c(0) = '1' then
        result(1) := (to_integer(unsigned(c)) / 2) * 2;
      end if;
    end if;
    return result;
  end bram_center;

  function bram_east (
    c : std_logic_vector)
    return bram_port_t is
    variable result: bram_port_t;
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1 loop
      if c(0) = '1' xor i mod 2 = 1 then
        result(i) := to_integer(unsigned(c)) * 2 + i * 2 - 2;
      else
        result(i) := to_integer(unsigned(c)) * 2 + i * 2 + 2;
      end if;
    end loop;
    return result;
  end bram_east;
  function bram_west (
    c : std_logic_vector)
    return bram_port_t is
    variable result: bram_port_t;
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1 loop
      if c(0) = '1' xor i mod 2 = 1 then
        result(i) := to_integer(unsigned(c)) * 2 + i * 2 - 2;
      else
        result(i) := to_integer(unsigned(c)) * 2 + i * 2 + 2;
      end if;
    end loop;
    return result;
  end bram_west;

  function bram_north (
    c : std_logic_vector)
    return bram_port_t is
    variable result: bram_port_t;
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1 loop
      if PARALLEL_DEV_WORDS = 4 then
        result(i) := to_integer(unsigned(c)) * 2 + (i / 2) * 2 + 1;
      else
        if c(1) = '1' then
          result(i) := to_integer(unsigned(c)) * 2 + i * 2 - 4;
        else
          result(i) := to_integer(unsigned(c)) * 2 + i * 2 + 4;
        end if;
      end if;
    end loop;
    return result;
  end bram_north;
  function bram_south (
    c : std_logic_vector)
    return bram_port_t is
    variable result: bram_port_t;
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1 loop
      if PARALLEL_DEV_WORDS = 4 then
        result(i) := to_integer(unsigned(c)) * 2 + (i / 2) * 2 + 5;
      else
        if c(1) = '1' then
          result(i) := to_integer(unsigned(c)) * 2 + i * 2 - 3;
        else
          result(i) := to_integer(unsigned(c)) * 2 + i * 2 + 5;
        end if;
      end if;
    end loop;
    return result;
  end bram_south;

  function bram_up (
    c : std_logic_vector)
    return bram_port_t is
    variable result: bram_port_t;
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1 loop
      result(i) := (to_integer(unsigned(c)) * 2 + i * 2 + 8) mod 16;
    end loop;
    return result;
  end bram_up;
  function bram_down (
    c : std_logic_vector)
    return bram_port_t is
    variable result: bram_port_t;
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1  loop
      result(i) := (to_integer(unsigned(c)) * 2 + i * 2 + 9) mod 16;
    end loop;
    return result;
  end bram_down;

  signal bram_center_workaround : bram_port_t;

begin

  zero <= (others => '0');

  -----------------------------------------------------------------------------
  -- Control
  -----------------------------------------------------------------------------
  dev_enable_read_0  <= (others => dev_enable_read);
  dev_enable_read_1b <= (others => dev_enable_read);

--Kaa
  dev_usedrules_read_enable <= dev_enable_read;
--Kaa

  -----------------------------------------------------------------------------

  column_count_to <= to_unsigned (COLUMNS/DEV_PARALLELITY - 1, COORD_SIZE_X - DEV_PAR_SIZE);

  column_counter: counter
    generic map (
      SIZE     => COORD_SIZE_X - DEV_PAR_SIZE)
    port map (
      reset    => reset_column_counter,
      count    => count_column,
      count_to => column_count_to,
      zero     => column_counter_zero,
      finished => column_counter_finished,
      value    => column_plus_1_i,
      clk      => clk);
  column_plus_1 <= column_plus_1_i & zero(DEV_PAR_SIZE - 1 downto 0);
  
  -----------------------------------------------------------------------------
  row_count_to <= to_unsigned (ROWS - 1, COORD_SIZE_Y);

  row_counter: counter
    generic map (
      SIZE     => COORD_SIZE_Y)
    port map (
      reset    => reset_row_counter,
      count    => count_row,
      count_to => row_count_to,
      zero     => row_counter_zero,
      finished => row_counter_finished,
      value    => row_plus_1,
      clk      => clk);
  -----------------------------------------------------------------------------


  layer_count_to <= to_unsigned (LAYERS - 1, COORD_SIZE_Z);

  layer_counter: counter
    generic map (
      SIZE     => COORD_SIZE_Z)
    port map (
      reset    => reset_layer_counter,
      count    => count_layer,
      count_to => layer_count_to,
      zero     => layer_counter_zero,
      finished => layer_counter_finished,
      value    => layer_plus_1,
      clk      => clk);
--  layer_plus_1 <= layer_plus_1_i(COORD_SIZE_Z - 1 downto 0);

  -----------------------------------------------------------------------------

  ruleset_count_to <= to_unsigned (RULE_SETS_MAX - 1 , RULE_SET_SELECT_SIZE);

  ruleset_counter: counter
    generic map (
      SIZE     => RULE_SET_SELECT_SIZE)--max 32 rule sets
    port map (
      reset    => reset_ruleset_counter,
      count    => count_ruleset,
      count_to => ruleset_count_to,
      zero     => ruleset_counter_zero,
      finished => ruleset_counter_finished,
      value    => ruleset_value,
      clk      => clk);

  -----------------------------------------------------------------------------

  addr_generator_center: addr_gen
    port map (
      x             => column_value,
      y             => row_value,
      z             => layer_value,
      addr          => addr_center,
      sblock_number => open,
      port_select   => port_select);

  addr_generator_up : addr_gen
    port map (
      x             => column_value,
      y             => row_value,
      z             => layer_minus_1,
      addr          => addr_up,
      sblock_number => open,
      port_select   => open);

  addr_generator_down : addr_gen
    port map (
      x             => column_value,
      y             => row_value,
      z             => layer_plus_1,
      addr          => addr_down,
      sblock_number => open,
      port_select   => open);

  addr_generator_north : addr_gen
    port map (
      x             => column_value,
      y             => row_minus_1,
      z             => layer_value,
      addr          => addr_north,
      sblock_number => open,
      port_select   => open);

  addr_generator_south : addr_gen
    port map (
      x             => column_value,
      y             => row_plus_1,
      z             => layer_value,
      addr          => addr_south,
      sblock_number => open,
      port_select   => open);



--Kaa
--  temp_usedrules_addr(USEDRULES_ADDR_BUS_SIZE - 1 downto COORD_SIZE_Y + COORD_SIZE_X - 1)
--     <= (others => '0');
--  temp_usedrules_addr(COORD_SIZE_Y + COORD_SIZE_X - 2 downto 0)
--     <= row_value & column_minus_1;
    temp_usedrules_addr <= padded_array(layer_value & row_value,
                                         COORD_SIZE_Y + COORD_SIZE_Z,--input width
                                         USEDRULES_ADDR_BUS_SIZE);       --output width
--Kaa

  -----------------------------------------------------------------------------
  -- clocked part of FSM

  process (clk, rst)
  begin

    if rst = '0' then
      control_state <= idle;
      control_access <= '0';

    elsif rising_edge (clk) then
      case control_state is

        -- waits for instructions
        when idle =>
          control_access <= '0';

          -- next state
          if dec_start_devstep = '1' then
            control_state <= prepare_pipe;
            use_prev <= '0';
          else
            control_state <= idle;
          end if;

        -- load far_east register in setup
        when prepare_pipe =>
          control_state <= run;
          --control_port_select <= '1';

          row_counter_zero_reg <= row_counter_zero;
          row_counter_finished_reg <= row_counter_finished;
--Kaa
          --always clear rulevector before new rule
          control_clear_rulevector <= '1';
--Kaa
        -- do development iteration
        when run =>
          control_access <= '1';
          control_port_select <= port_select;
          control_address <= addr_center;
--Kaa
          control_usedrules_addr <= temp_usedrules_addr;
          control_clear_rulevector <= '0';

          if layer_counter_finished = '1' and row_counter_finished_reg = '1' and
            last_set = '1' then
            control_last_sblock_last_ruleset <= '1';
          else
            control_last_sblock_last_ruleset <= '0';
          end if;
--Kaa
          row_counter_zero_reg <= row_counter_zero;
          row_counter_finished_reg <= row_counter_finished;
          -- stop when both counters are finished
          if layer_value = (COORD_SIZE_Z - 1 downto 0 => '1') and
             row_value = (COORD_SIZE_Y - 1 downto 0 => '1') and
             column_value = "1" & (COORD_SIZE_X - 2 downto 0 => '0') then
            control_state <= next_ruleset;
          else
            control_state <= run;
          end if;

        -- wait until pipe is ready, get new set of rules if not finished
        when next_ruleset =>
          control_access <= '0';
          control_last_sblock_last_ruleset <= '0';
          if ex2_access = '1' then
            control_state <= next_ruleset;
          elsif last_set = '0' then
            control_state <= prepare_pipe;
            use_prev <= '1';
          else
            control_state <= idle;

          end if;

        when others =>
          control_state <= idle;

      end case;

    end if;

  end process;

  -----------------------------------------------------------------------------
  -- comb. part of FSM

  process (control_state, row_counter_zero, row_counter_finished, column_counter_finished,
           layer_counter_finished, port_select, addr_up, addr_north, addr_south,
           addr_down, dec_start_devstep, ex2_access, last_set,
           addr_center, use_prev, temp_usedrules_addr, 
           column_plus_1, row_plus_1)
  begin

    -- default values
    reset_column_counter <= '0';
    reset_row_counter <= '0';
    reset_layer_counter <= '0';

--Kaa
    reset_ruleset_counter <= '0';
    count_ruleset         <= '0';
    dev_usedrules_addr_read <= (others => 'Z');
--Kaa

    count_layer <= '0';
    count_row <= '0';
    count_column <= '0';

    addr_0 <= (others => (others => 'Z'));

    addr_1_read <= (others => (others => 'Z'));

    dev_enable_read <= '0';

    dev_idle <= '0';

    rst_countregs <= '1';

    cache_set_zero <= '0';
    cache_next_set <= '0';

    case control_state is

      when idle =>
        dev_idle <= '1';

        reset_layer_counter <= '1';
        reset_row_counter <= '1';
        reset_column_counter <= '1';
--Kaa
        reset_ruleset_counter <= '1';
--Kaa
        rst_countregs <= '0';

        if dec_start_devstep = '1' then
          cache_set_zero <= '1';
        end if;


      when prepare_pipe =>
        dev_enable_read <= '1';

        count_layer <= '1';
        count_row <= '1';
        count_column <= '1';
--Kaa
        --increment ruleset counter if not first ruleset
        if use_prev = '1' then
          count_ruleset <= '1';
        end if;
--Kaa
      when run =>
        count_column <= '1';
        if column_counter_finished = '1' then
          reset_column_counter <= '1';
        end if;
        if column_plus_1 = (COORD_SIZE_X - 1 downto 0 => '0') then
          count_row <= '1';
          if row_counter_finished = '1' then
            reset_row_counter <= '1';
          end if;
          if row_plus_1 = (COORD_SIZE_Y - 1 downto 0 => '0') then
            count_layer <= '1';
            if layer_counter_finished = '1' then
              reset_layer_counter <= '1';
            end if;
          end if;
        end if;


        dev_enable_read <= '1';
        
        addr_0(bram_east(port_select)(0)) <= addr_center;
        addr_0(bram_west(port_select)(0)) <= addr_center;
        for i in 0 to PARALLEL_DEV_WORDS - 1 loop
          addr_0(bram_center(port_select)(i)) <= addr_center;
          addr_0(bram_north(port_select)(i)) <= addr_north;
          addr_0(bram_south(port_select)(i)) <= addr_south;
          addr_0(bram_up(port_select)(i)) <= addr_up;
          addr_0(bram_down(port_select)(i)) <= addr_down;
        end loop;

        for i in 0 to SBM_BRAM_MODULES - 1 loop
          addr_1_read(i) <= addr_center;
        end loop;

--Kaa
        dev_usedrules_addr_read <= temp_usedrules_addr;
--Kaa

      when next_ruleset =>
        reset_layer_counter <= '1';
        reset_row_counter <= '1';
        reset_column_counter <= '1';
        
        rst_countregs <= '0';

        if ex2_access = '0' and last_set = '0' then
          cache_next_set <= '1';
        end if;

      when others =>
        null;

    end case;

  end process;

  addr1: for i in 0 to SBM_BRAM_MODULES - 1 generate
    addr_1(i*2+1) <= addr_1_read(i);
    addr_1(i*2) <= addr_1_write(i);
  end generate addr1;

  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------

  -- registers used to generate addresses other than from the current row and
  -- column values
  process (rst_countregs, clk)
  begin
    if rst_countregs = '0' then

      column_value <= (others => '0');
      row_value <= (others => '0');
      layer_value <= (others => '0');
      column_minus_1 <= (others => '1');
      row_minus_1 <= (others => '1');
      layer_minus_1 <= (others => '1');

    elsif rising_edge (clk) then
      if count_layer = '1' and layer_counter_zero = '0' then
        layer_value <= layer_plus_1(COORD_SIZE_Z - 1 downto 0);
        layer_minus_1 <= layer_value;
      end if;

      if count_row = '1' and (row_counter_zero = '0' or layer_counter_zero = '0' ) then
        row_value   <= row_plus_1;
        row_minus_1 <= row_value;
      end if;
      
      if count_column = '1' and (column_counter_zero = '0' or row_counter_zero = '0' or layer_counter_zero = '0') then
        column_value <= column_plus_1;
        column_minus_1 <= column_value;
      end if;

    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Fetch1
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      fetch1_access <= control_access;
      fetch1_address <= control_address;
      fetch1_port_select <= control_port_select;
--Kaa
      fetch1_usedrules_addr <= control_usedrules_addr;
      fetch1_clear_rulevector <= control_clear_rulevector;
      fetch1_last_sblock_last_ruleset <= control_last_sblock_last_ruleset;
--Kaa

    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Fetch2
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      fetch2_access <= fetch1_access;
      fetch2_address <= fetch1_address;
      fetch2_port_select <= fetch1_port_select;
--Kaa
      fetch2_usedrules_addr <=  fetch1_usedrules_addr;
      fetch2_clear_rulevector <= fetch1_clear_rulevector;
      fetch2_last_sblock_last_ruleset <= fetch1_last_sblock_last_ruleset;
--Kaa

    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Setup
  -----------------------------------------------------------------------------

  -- get correct data from BRAM-0, based on port_select
  process (fetch2_port_select,
           type_data_read_0, state_data_read_0,
           type_data_read_1, state_data_read_1)
  begin
    for i in 0 to PARALLEL_DEV_WORDS - 1 loop
      type_center(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_0(bram_center(fetch2_port_select)(i));
      type_north(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_0(bram_north(fetch2_port_select)(i));
      type_south(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_0(bram_south(fetch2_port_select)(i));
      type_up(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_0(bram_up(fetch2_port_select)(i));
      type_down(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_0(bram_down(fetch2_port_select)(i));
      type_east(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_0(bram_center(fetch2_port_select)(i))(TYPE_BUS_SIZE - TYPE_SIZE - 1 downto 0)
               & type_data_read_0(bram_east(fetch2_port_select)(i))(TYPE_BUS_SIZE - 1 downto TYPE_BUS_SIZE - TYPE_SIZE);
      type_west(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_0(bram_west(fetch2_port_select)(i))(TYPE_SIZE - 1 downto 0)
               & type_data_read_0(bram_center(fetch2_port_select)(i))(TYPE_BUS_SIZE - 1 downto TYPE_SIZE);

      state_center(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_0(bram_center(fetch2_port_select)(i));
      state_north(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_0(bram_north(fetch2_port_select)(i));
      state_south(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_0(bram_south(fetch2_port_select)(i));
      state_up(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_0(bram_up(fetch2_port_select)(i));
      state_down(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_0(bram_down(fetch2_port_select)(i));
      state_east(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_0(bram_center(fetch2_port_select)(i))(STATE_BUS_SIZE - 2 downto 0)
               & state_data_read_0(bram_east(fetch2_port_select)(i))(STATE_BUS_SIZE - 1 downto STATE_BUS_SIZE - 1);
      state_west(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_0(bram_west(fetch2_port_select)(i))(0)
               & state_data_read_0(bram_center(fetch2_port_select)(i))(STATE_BUS_SIZE - 1 downto 1);

      type_center_prev(TYPE_BUS_SIZE * (i + 1) - 1 downto TYPE_BUS_SIZE * i)
              <= type_data_read_1(bram_center(fetch2_port_select)(i)+1);
      state_center_prev(STATE_BUS_SIZE * (i + 1) - 1 downto STATE_BUS_SIZE * i)
              <= state_data_read_1(bram_center(fetch2_port_select)(i)+1);
    end loop;
  end process;



  -----------------------------------------------------------------------------

  -- setup pipeline registers with correct data
  process (rst, clk)
  begin

    if rising_edge (clk) then
      for i in 0 to DEV_PARALLELITY - 1 loop
        setup_center_type(i) <= type_center((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
        setup_east_type(i)   <= type_east((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
        setup_south_type(i)  <= type_south((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
        setup_west_type(i)   <= type_west((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
        setup_north_type(i)  <= type_north((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
        setup_up_type(i)     <= type_up((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
        setup_down_type(i)   <= type_down((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
        setup_center_state(i) <= state_center(DEV_PARALLELITY-i-1);
        setup_east_state(i)   <= state_east(DEV_PARALLELITY-i-1);
        setup_south_state(i)  <= state_south(DEV_PARALLELITY-i-1);
        setup_west_state(i)   <= state_west(DEV_PARALLELITY-i-1);
        setup_north_state(i)  <= state_north(DEV_PARALLELITY-i-1);
        setup_up_state(i)     <= state_up(DEV_PARALLELITY-i-1);
        setup_down_state(i)   <= state_down(DEV_PARALLELITY-i-1);
        -- if this is not the first set of rules, old data must be taken
        -- from BRAM-1, instead of BRAM-0.  This is to avoid loosing
        -- data generated on previous passes
        if use_prev = '1' then
          setup_old_type(i)  <= type_center_prev((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
          setup_old_state(i) <= state_center_prev(DEV_PARALLELITY-i-1);
        else
          setup_old_type(i)  <= type_center((DEV_PARALLELITY-i) * TYPE_SIZE - 1
                                      downto (DEV_PARALLELITY-i-1) * TYPE_SIZE);
          setup_old_state(i) <= state_center(DEV_PARALLELITY-i-1);
        end if;
      end loop;

--Kaa
      --setup with data from BRAM
      if use_prev = '1' then
        --if not first rule set, read old rule from BRAM
        setup_old_selected_rule <= dev_usedrules_read;
      else
        --if first rule set, set used rule equal 0xFF
        setup_old_selected_rule <= (others => '1');
      end if;

      setup_usedrules_addr <= fetch2_usedrules_addr;
      setup_clear_rulevector <= fetch2_clear_rulevector;
      setup_last_sblock_last_ruleset <= fetch2_last_sblock_last_ruleset;
--Kaa

      setup_access <= fetch2_access;
      setup_address <= fetch2_address;
      setup_port_select <= fetch2_port_select;

    end if;


  end process;

  -----------------------------------------------------------------------------
  -- Execute1
  -----------------------------------------------------------------------------

  rule_execution: for i in 0 to DEV_PARALLELITY - 1 generate
    rule_executives: for j in 0 to RULES_IN_SET - 1 generate
      rule_execX: rule_executive
        port map (
          up_type      => setup_up_type(i),
          down_type    => setup_down_type(i),
          north_type   => setup_north_type(i),
          south_type   => setup_south_type(i),
          east_type    => setup_east_type(i),
          west_type    => setup_west_type(i),
          center_type  => setup_center_type(i),
          up_state     => setup_up_state(i),
          down_state   => setup_down_state(i),
          north_state  => setup_north_state(i),
          south_state  => setup_south_state(i),
          east_state   => setup_east_state(i),
          west_state   => setup_west_state(i),
          center_state => setup_center_state(i),
          rule         => ruleset(j),
          hit          => ex2_hit(i)(j),
          result_type  => ex2_result_type(i)(j),
          result_state => ex2_result_state(i)(j),
          rst          => rst,
          clk          => clk);
    end generate rule_executives;
  end generate rule_execution;
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      ex1_access <= setup_access;
      ex1_address <= setup_address;
      ex1_port_select <= setup_port_select;
      ex1_old_type <= setup_old_type;
      ex1_old_state <= setup_old_state;
--Kaa
      for i in 0 to DEV_PARALLELITY - 1 loop
        ex1_old_selected_rule(i)
          <= setup_old_selected_rule(USEDRULES_DATA_BUS_SIZE - i * RULE_NBR_BUS_SIZE - 1
                            downto USEDRULES_DATA_BUS_SIZE - (i+1) * RULE_NBR_BUS_SIZE);
      end loop;
      ex1_usedrules_addr <= setup_usedrules_addr;
      ex1_clear_rulevector <= setup_clear_rulevector;
      ex1_last_sblock_last_ruleset <= setup_last_sblock_last_ruleset;
--Kaa

    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Execute2
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      ex2_access <= ex1_access;
      ex2_address <= ex1_address;
      ex2_port_select <= ex1_port_select;
      ex2_old_type <= ex1_old_type;
      ex2_old_state <= ex1_old_state;
--Kaa
      ex2_old_selected_rule <= ex1_old_selected_rule;

      ex2_usedrules_addr <= ex1_usedrules_addr;
      ex2_clear_rulevector <= ex1_clear_rulevector;
      ex2_last_sblock_last_ruleset <= ex1_last_sblock_last_ruleset;
--Kaa
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Select
  -----------------------------------------------------------------------------

  ruleselection: for i in 0 to DEV_PARALLELITY - 1 generate
    rule_selectX: rule_select
      port map (
        hits          => ex2_hit(i),
        old_type      => ex2_old_type(i),
        old_state     => ex2_old_state(i),
        results_type  => ex2_result_type(i),
        results_state => ex2_result_state(i),
        result_type   => select_result_type (TYPE_SIZE * (DEV_PARALLELITY - i) - 1
                          downto TYPE_SIZE * (DEV_PARALLELITY - 1 - i)),
        result_state  => select_result_state (ENTRIES_PER_WORD - i - 1),
  --Kaa
        old_selected_rule => ex2_old_selected_rule(i),
        selected_rule     => select_selected_rule(i),
        ruleset           => ruleset_value,
  --Kaa
        rst           => rst,
        clk           => clk);

  --Kaa
  --Kaa
  end generate ruleselection;
  decode: decode_and_or
    port map (
      input => select_selected_rule,
      output => select_rulevector_conc);
--Kaa
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      select_access <= ex2_access;
      select_address <= ex2_address;
      select_port_select <= ex2_port_select;
--Kaa
      select_usedrules_addr <= ex2_usedrules_addr;

      select_last_sblock_last_ruleset <= ex2_last_sblock_last_ruleset;
      select_write_rulevector <= select_last_sblock_last_ruleset;

      select_clear_rulevector <= ex2_clear_rulevector;
--Kaa
    end if;
  end process;

--Kaa
  process(rst, clk)
    begin
      if rising_edge(clk) then
        if select_clear_rulevector = '1' then
          select_rulevector <= (others => '0');
        else
          select_rulevector <= select_rulevector or select_rulevector_conc;
        end if;

      end if;
    end process;
--Kaa

  -----------------------------------------------------------------------------
  -- Store
  -----------------------------------------------------------------------------

  -- store to BRAM-1
  bram_center_workaround <= bram_center(select_port_select); -- (0) need to be on a separate line for some reason

  addra1 : for i in 0 to SBM_BRAM_MODULES - 1 generate
    addr_1_write(i) <= select_address when select_access = '1' else (others => 'Z');
    dev_enable_write_1a(i) <= select_access when bram_center_workaround(0)/2 = i/PARALLEL_DEV_WORDS else '0';

    type_data_write_1(i*2)   <= select_result_type
              (TYPE_BUS_SIZE * ((i mod PARALLEL_DEV_WORDS)+1) - 1 
        downto (TYPE_BUS_SIZE * (i mod PARALLEL_DEV_WORDS))) 
                            when select_access = '1' else (others => 'Z');

    state_data_write_1(i*2)   <= select_result_state
              (STATE_BUS_SIZE * ((i mod PARALLEL_DEV_WORDS)+1) - 1 
        downto (STATE_BUS_SIZE * (i mod PARALLEL_DEV_WORDS)))
                            when select_access = '1' else (others => 'Z');
    type_data_write_1(i*2+1) <= (others => 'Z');
    state_data_write_1(i*2+1) <= (others => 'Z');

  end generate addra1;

--Kaa
  dev_usedrules_addr_write <= select_usedrules_addr
                              when select_access = '1' else (others =>  'Z');
  usedruleswrite: for i in 0 to DEV_PARALLELITY - 1 generate
    dev_usedrules_write(RULE_NBR_BUS_SIZE * (DEV_PARALLELITY-i) - 1
                  downto RULE_NBR_BUS_SIZE * (DEV_PARALLELITY-i-1))
                        <= select_selected_rule(i);
  end generate usedruleswrite;
  dev_usedrules_write_enable <= select_access;

  dev_rulevector_data_write <= select_rulevector or select_rulevector_conc;
  dev_rulevector_write_enable <= select_write_rulevector;
--Kaa


end dev_arch;

