-------------------------------------------------------------------------------
-- Title      : package
-- Project    : 
-------------------------------------------------------------------------------
-- File       : package.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/05/19
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Constants and component declarations
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/05/19  3.0      stoevneng
-- 2005/05/23  2.0      aamodt 
-- 2003/01/17  1.1      djupdal
-- 2002/10/20  1.0      djupdal   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.funct_package.all;

package sblock_package is

  -- constants set by preprosessor

  constant COORD_SIZE_X : integer := 5;
  constant COORD_SIZE_Y : integer := 5;

  -- constants

  constant ROWS    : integer := 2 ** COORD_SIZE_Y;
  constant COLUMNS : integer := 2 ** COORD_SIZE_X;

  constant LUT_SIZE  : integer := 32;
  constant TYPE_SIZE : integer := 5; --max 8
  constant STATE_SIZE : integer := 1; --must be 1

  constant INSTR_ADDR_SIZE   : integer := 8;
  constant INSTR_SIZE        : integer := 128;
  
  -- 5 for 2d and 7 for 3d
  constant NEIGH_SIZE : integer := 5;
  

  constant RULE_SIZE         : integer := 89;--6*(TYPE_SIZE+STATE_SIZE+2)+1;
  -- Change this to change the maximum amount of rules:
  constant RULE_NBR_BUS_SIZE : integer := 8;
  -- Change this to change the amount of rules in a set:
  constant RULES_IN_SET_SIZE : integer := 3;
  -- Do not change these three:
  constant RULES_IN_SET      : integer := 2 ** RULES_IN_SET_SIZE;
  constant RULE_SET_SELECT_SIZE : integer := RULE_NBR_BUS_SIZE - RULES_IN_SET_SIZE;
  constant RULE_SETS_MAX     : integer := 2 ** RULE_SET_SELECT_SIZE;

  constant DEV_ROW_CYCLES_SIZE : integer := COORD_SIZE_X - 3;
  -- How many cycles are spent to develop one row of cells
  constant DEV_ROW_CYCLES : integer := 2 ** DEV_ROW_CYCLES_SIZE;
  -- How many cells are developed concurrently
  constant DEV_PARALLELITY : integer := COLUMNS/DEV_ROW_CYCLES;
  
  -- SBM BRAM addr bus size
  constant ADDR_BUS_SIZE : integer := COORD_SIZE_X + COORD_SIZE_Y - 4;
--Kaa
  -- for memory contain data generated on run-steps
  -- address bus can be changed to expand the numbers of values that can be stored
  constant RUN_STEP_ADDR_BUS_SIZE : integer := 13;
  constant RUN_STEP_DATA_BUS_SIZE : integer := COORD_SIZE_X + COORD_SIZE_Y + 1;

  -- for BRAM used to store fired rules for many dev-steps
  -- can NOT be changed, BRAM not dynamic
  constant RULEVECTOR_ADDR_BUS_SIZE : integer := 8;
  constant RULEVECTOR_DATA_BUS_SIZE : integer := 256;

  -- for BRAM used to store fired rules for one dev-step
  constant USEDRULES_ADDR_BUS_SIZE : integer := 10;
  constant USEDRULES_DATA_BUS_SIZE : integer := RULE_NBR_BUS_SIZE * DEV_PARALLELITY;

  -- for fitness result storage
  constant FITNESS_RESULT_SIZE  : integer := 4 * 32; 
  constant FITNESS_DATA_BUS_SIZE: integer := 32;
--Kaa

  -- How many cells are configured per cycle
  constant LUTCONVS_PER_CYCLE : integer := 8;

  -- How many types/states per word in the SBM BRAM
  constant ENTRIES_PER_WORD : integer := 4;  

  -- SBM BRAM's type and state bus sizes.
  constant TYPE_BUS_SIZE  : integer := TYPE_SIZE * ENTRIES_PER_WORD;
  constant STATE_BUS_SIZE : integer := STATE_SIZE * ENTRIES_PER_WORD;

  -- How many BRAM module per BRAM-A and BRAM-B.
  constant SBM_BRAM_MODULES : integer := 4;

  -- How many cells are configured concurrently
  constant SBM_CFG_SIZE : integer := LUTCONVS_PER_CYCLE * 16;

  -- How many states are read back to BRAM1 each cycle.
  constant SBM_RDB_SIZE : integer := ENTRIES_PER_WORD * SBM_BRAM_MODULES * 2;
  -- How many states are read by the RSF each cycle, for example all of them.
  constant SBM_FNK_SIZE : integer := ROWS * COLUMNS;
  -- bits required to represent SBM_FNK_SIZE
  constant RSF_VAL_SIZE : integer := COORD_SIZE_X + COORD_SIZE_Y + 1;
  -- very dependent on RSF_VAL_SIZE:
  --  6-8->1, 9-10->2, 11-12->3, 13-14->4, 15-16->5 and so on.
  constant RSF_PIPE_LEN : integer := (RSF_VAL_SIZE - 5) / 2;


  -- How many words needs to be read back to BRAM1 to read all the states
  constant READBACK_WORDS : integer := 
    ceil ((ROWS * COLUMNS) / SBM_RDB_SIZE, (ROWS * COLUMNS) mod SBM_RDB_SIZE);
  -- How many times the config unit must config SBM_CFG_SIZE cells to configure the whole matrix
  constant CONFIG_WORDS : integer := 
    ceil ((ROWS * COLUMNS) / SBM_CFG_SIZE, (ROWS * COLUMNS) mod SBM_CFG_SIZE);

  -----------------------------------------------------------------------------
  -- types

  type rule_set_t is array (RULES_IN_SET - 1 downto 0)
    of std_logic_vector(RULE_SIZE - 1 downto 0);

  type exec_result_type_t is array (RULES_IN_SET - 1 downto 0)
    of std_logic_vector(TYPE_SIZE - 1 downto 0);

  type selected_rule_t is array(DEV_PARALLELITY - 1 downto 0) 
    of std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
  
  type bram_addr_t is array (SBM_BRAM_MODULES * 2 - 1 downto 0)
    of std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  
  type bram_type_bus_t is array (SBM_BRAM_MODULES * 2 - 1 downto 0)
    of std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
    
  type bram_state_bus_t is array (SBM_BRAM_MODULES * 2 - 1 downto 0)
    of std_logic_vector(STATE_BUS_SIZE - 1 downto 0);
  
  type bram_addr_half_t is array (SBM_BRAM_MODULES - 1 downto 0)
    of std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  
  type bram_type_bus_half_t is array (SBM_BRAM_MODULES - 1 downto 0)
    of std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
    
  type bram_state_bus_half_t is array (SBM_BRAM_MODULES - 1 downto 0)
    of std_logic_vector(STATE_BUS_SIZE - 1 downto 0);
    
  type lutconv_type_bus_t is array (LUTCONVS_PER_CYCLE - 1 downto 0)
    of std_logic_vector(TYPE_SIZE - 1 downto 0);
  
  type lutconv_lut_bus_t is array (LUTCONVS_PER_CYCLE - 1 downto 0)
    of std_logic_vector(LUT_SIZE - 1 downto 0);
    
  type rule_type_t is array (NEIGH_SIZE - 1 downto 0) 
    of std_logic_vector(TYPE_SIZE - 1 downto 0);
    


  -----------------------------------------------------------------------------
  -- DFT Constants
  
    -- Must be numbers and not expressions for twgen.py to work --
  -- Twiddle factor precision / length
  constant TW_PRES      : integer := 6;
  -- Number of values in DFT input
  constant DFT_SIZE	    : integer := 128;
  -- The logarithm of how many DSPS are used
  constant DFT_LG_DSPS  : integer := 5;
    --------------------------------------------------------------
  
  constant TWIDDLE_SIZE : integer := (TW_PRES+2)*2;
  constant DFT_DSPS     : integer := 2**DFT_LG_DSPS;
  constant PERDSP	      : integer := DFT_SIZE/DFT_DSPS;
  constant VALSIZE	    : integer := 18;
  constant TWLEN        : integer := 16;
  constant DFT_INW      : integer := COORD_SIZE_X + COORD_SIZE_Y + 1;

  type dft_res_t is array(0 to DFT_SIZE/2-1) of STD_LOGIC_VECTOR (18-1 downto 0);

  -----------------------------------------------------------------------------
  -- components from Xilinx library

  component SRL16E
    port (
      d   : in  std_logic;
      ce  : in  std_logic;
      a0  : in  std_logic;
      a1  : in  std_logic;
      a2  : in  std_logic;
      a3  : in  std_logic;
      q   : out std_logic;
      clk : in  std_logic);
  end component;

  component bufg
    port (
      i : in std_logic;
      o : out std_logic);
  end component;

  component ibufg
    port (
      i : in  std_logic;
      o : out std_logic);
  end component;

  component clkdll
    port (
      clkin  : in  std_logic;
      clkfb  : in  std_logic;
      rst    : in  std_logic;
      clk0   : out std_logic;
      clk90  : out std_logic;
      clk180 : out std_logic;
      clk270 : out std_logic;
      clk2x  : out std_logic;
      clkdv  : out std_logic;
      locked : out std_logic);
  end component;

  -----------------------------------------------------------------------------
  -- components part of this project

  component toplevel
    port (
      pciBusy   : in    std_logic;
      pciEmpty  : in    std_logic;
      pciRW     : out   std_logic;
      pciEnable : out   std_logic;
      pciData   : inout std_logic_vector(63 downto 0);
      debugled  : out   std_logic_vector(15 downto 0);
      clk       : in    std_logic;
      clk40     : in    std_logic;
      rst       : in    std_logic);
  end component;

  -----------------------------------------------------------------------------

  component counter
    generic (
      SIZE : integer);
    port (
      reset    : in  std_logic;
      count    : in  std_logic;
      count_to : in  unsigned(SIZE - 1 downto 0);
      zero     : out std_logic;
      finished : out std_logic;
      value    : out std_logic_vector(SIZE - 1 downto 0);
      clk      : in  std_logic);
  end component;

  component addr_gen
    port (
      x             : in  std_logic_vector(COORD_SIZE_X - 1 downto 0);
      y             : in  std_logic_vector(COORD_SIZE_Y - 1 downto 0);
      addr          : out std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
      sblock_number : out std_logic_vector(1 downto 0);
      port_select   : out std_logic_vector(1 downto 0));
  end component;

  component word_select
    generic (
      NUMBER_OF_WORDS : integer);
    port (
      reset_select  : in  std_logic;
      select_next   : in  std_logic;
      selected_word : out std_logic_vector(NUMBER_OF_WORDS - 1 downto 0);
      rst           : in  std_logic;
      clk           : in  std_logic);
  end component;

  -----------------------------------------------------------------------------

  component instr_mem
    port (
      addr         : in  std_logic_vector(7 downto 0);
      data_read    : out std_logic_vector(127 downto 0);
      data_write   : in  std_logic_vector(127 downto 0);
      write_enable : in  std_logic;
      stall        : in  std_logic;
      rst          : in  std_logic;
      clk          : in  std_logic);
  end component;

  component sblock
    port (
      east              : in  std_logic;
      south             : in  std_logic;
      north             : in  std_logic;
      west              : in  std_logic;
      conf_data_l       : in  std_logic;
      conf_data_h       : in  std_logic;
      conf_data_ff      : in  std_logic;
      config_lut_enable : in  std_logic;
      config_ff_enable  : in  std_logic;
      output            : out std_logic;
      run               : in  std_logic;
      clk               : in  std_logic);
  end component;

  component sbm_bram
    port (
      type_data_read     : out bram_type_bus_t;
      state_data_read    : out bram_state_bus_t;
      type_data_write    : in bram_type_bus_t;
      state_data_write   : in bram_state_bus_t;
      addr               : in bram_addr_t;
      enable_read        : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
      enable_type_write  : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
      enable_state_write : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
      stall              : in  std_logic;
      clk                : in  std_logic;
      rst                : in  std_logic);
  end component;

  component bram_inferrer
    generic (
      addr_bits : integer;
      data_bits : integer);
    port (
      clk_a    : in std_logic;
      clk_b    : in std_logic;
      addr_a   : in std_logic_vector(addr_bits - 1 downto 0);
      data_i_a : in std_logic_vector(data_bits - 1 downto 0);
      data_o_a : out std_logic_vector(data_bits - 1 downto 0);
      we_a     : in std_logic;
      en_a     : in std_logic;
      rst_a    : in std_logic;
      addr_b   : in std_logic_vector(addr_bits - 1 downto 0);
      data_i_b : in std_logic_vector(data_bits - 1 downto 0);
      data_o_b : out std_logic_vector(data_bits - 1 downto 0);
      we_b     : in std_logic;
      en_b     : in std_logic;
      rst_b    : in std_logic);
  end component;

  component srl_inferer
    generic (
      size : integer;
      a_size : integer);
    port (
      d : in std_logic;
      ce : in std_logic;
      a : in std_logic_vector(a_size - 1 downto 0);
      q : out std_logic;
      clk : in std_logic);
  end component;


  component rule_executive
    port (
      north_type   : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      south_type   : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      east_type    : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      west_type    : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      center_type  : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      north_state  : in  std_logic;
      south_state  : in  std_logic;
      east_state   : in  std_logic;
      west_state   : in  std_logic;
      center_state : in  std_logic;
      rule         : in  std_logic_vector(RULE_SIZE - 1 downto 0);
      hit          : out std_logic;
      result_type  : out std_logic_vector(TYPE_SIZE - 1 downto 0);
      result_state : out std_logic;
      rst          : in  std_logic;
      clk          : in  std_logic);
  end component;

  component rule_select
    port (
      hits          : in  std_logic_vector(RULES_IN_SET - 1 downto 0);
      old_type      : in  std_logic_vector(TYPE_SIZE - 1 downto 0);
      old_state     : in  std_logic;
      results_type  : in  exec_result_type_t;
      results_state : in  std_logic_vector(RULES_IN_SET - 1 downto 0);
      result_type   : out std_logic_vector(TYPE_SIZE - 1 downto 0);
      result_state  : out std_logic;
--Kaa
      old_selected_rule: in std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
      selected_rule    :out std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
      ruleset          : in std_logic_vector(RULE_SET_SELECT_SIZE - 1 downto 0);
--Kaa
      rst           : in  std_logic;
      clk           : in  std_logic);
  end component;

  -----------------------------------------------------------------------------

  component com40
    port (
      send         : in    std_logic;
      ack_send     : out   std_logic;
      receive      : in    std_logic;
      ack_receive  : out   std_logic;
      data_send    : in    std_logic_vector(63 downto 0);
      data_receive : out   std_logic_vector(63 downto 0);
      pciBusy      : in    std_logic;
      pciEmpty     : in    std_logic;
      pciRW        : out   std_logic;
      pciEnable    : out   std_logic;
      pciData      : inout std_logic_vector(63 downto 0);
      rst          : in    std_logic;
      clk40        : in    std_logic);
  end component;

  component rule_storage
    port (
      ruleset        : out rule_set_t;
      cache_set_zero : in  std_logic;
      cache_next_set : in  std_logic;
      last_set       : out std_logic;
      store_rule     : in  std_logic;
      rule_number    : in  std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
      rule_to_store  : in  std_logic_vector(RULE_SIZE - 1 downto 0);
      nbr_of_last_rule : in std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
      rst                 : in std_logic;
      clk                 : in std_logic);
  end component;

  component lutconv
    port (
      index     : in  lutconv_type_bus_t;
      lut_read  : out lutconv_lut_bus_t;
      lut_write : in  std_logic_vector(LUT_SIZE - 1 downto 0);
      write_en  : in  std_logic;
      rst       : in  std_logic;
      clk       : in  std_logic);
  end component;

  component sblock_matrix
    port (
      databus_read        : out std_logic_vector(SBM_RDB_SIZE - 1 downto 0);
      databus_read_funk    : out std_logic_vector(SBM_FNK_SIZE - 1 downto 0);
      output_select       : in  std_logic_vector(READBACK_WORDS - 1 downto 0);
      databus_lut_l_write : in  std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
      databus_lut_h_write : in  std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
      databus_ff_write    : in  std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
      config_enable_lut   : in  std_logic_vector(CONFIG_WORDS - 1 downto 0);
      config_enable_ff    : in  std_logic_vector(CONFIG_WORDS - 1 downto 0);
      run_matrix          : in  std_logic;
      rst                 : in  std_logic;
      clk                 : in  std_logic);
  end component;

  component sbm_bram_mgr
    port (
      type_data_read_0          : out bram_type_bus_t;
      type_data_write_0         : in bram_type_bus_t;
      state_data_read_0         : out bram_state_bus_t;
      state_data_write_0        : in bram_state_bus_t;
      addr_0                    : in bram_addr_t;
      type_data_read_1          : out bram_type_bus_t;
      type_data_write_1         : in bram_type_bus_t;
      state_data_read_1         : out bram_state_bus_t;
      state_data_write_1        : in bram_state_bus_t;
      addr_1                    : in bram_addr_t;
      dev_enable_read_0         : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
      dev_enable_read_1b        : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      dev_enable_write_1a       : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      lss_enable_read_0a        : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      lss_enable_write_type_0b  : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      lss_enable_write_state_0b : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      cfg_enable_read_1b        : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      rdb_enable_write_state_1  : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
      select_sbm                : in std_logic;
      stall                     : in std_logic;
      rst                       : in std_logic;
      clk                       : in std_logic);
  end component;

  component hazard
    port (
      dont_issue_dec        : out std_logic;
      stall_lss             : out std_logic;
      stall_dec             : out std_logic;
      stall_fetch           : out std_logic;
      stall_sbm_bram_mgr    : out std_logic;
--Kaa
      stall_usedrules_mem   : out std_logic;
      stall_run_step_mem    : out std_logic;
      stall_rulevector_mem  : out std_logic;
      stall_fitness         : out std_logic;
--Kaa
      fetch_valid           : in  std_logic;
      dec_sbm_pipe_access   : in  std_logic;
      dec_start_devstep     : in  std_logic;
      dec_lss_access        : in  std_logic;
--Kaa
      dec_start_fitness     : in  std_logic;
--Kaa
      lss_idle              : in  std_logic;
      lss_ld2_sending       : in  std_logic;
      lss_ack_send_i        : in  std_logic;
      send                  : in  std_logic;
      dev_idle              : in  std_logic;
      sbm_pipe_idle         : in  std_logic;
--Kaa
      fitness_pipe_idle     : in  std_logic;
--Kaa
      dft_idle              : in  std_logic;
      dec_start_dft         : in  std_logic;
      rst                   : in  std_logic;
      clk                   : in  std_logic);
  end component;

  component fetch
    port (
      fetch_instruction       : out std_logic_vector(127 downto 0);
      fetch_valid             : out std_logic;
      fetch_enter_normal_mode : out std_logic;
      fetch_count_pc          : out std_logic;
      program_counter         : in  std_logic_vector(7 downto 0);
      valid                   : in  std_logic;
      program_store           : in  std_logic;
      stall                   : in  std_logic;
      flush                   : in  std_logic;
      receive                 : out std_logic;
      ack_receive             : in  std_logic;
      data_receive            : in  std_logic_vector(63 downto 0);
      rst                     : in  std_logic;
      clk                     : in  std_logic);
  end component;

  component decode
    port (
      fetch_instruction       : in  std_logic_vector(127 downto 0);
      fetch_valid             : in  std_logic;
      fetch_enter_normal_mode : in  std_logic;
      fetch_count_pc          : in  std_logic;
      dec_program_counter     : out std_logic_vector(7 downto 0);
      dec_valid               : out std_logic;
      flush_fetch             : out std_logic;
      dec_program_store       : out std_logic;
      dec_read_sblock         : out std_logic;
--Kaa
      dec_read_usedrules      : out std_logic;
--Kaa
      dec_send_type           : out std_logic;
      dec_send_types          : out std_logic;
      dec_send_state          : out std_logic;
      dec_send_states         : out std_logic;
      dec_send_rulevector     : out std_logic;
      dec_send_fitness        : out std_logic;
      dec_start_fitness       : out std_logic;
--Kaa
      dec_send_sums           : out std_logic;
      dec_send_used_rules     : out std_logic;
--Kaa
      
      dec_clear_bram          : out std_logic;
      dec_write_type          : out std_logic;
      dec_write_state         : out std_logic;
      dec_write_word          : out std_logic;
      dec_address             : out std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
      dec_port_select         : out std_logic_vector(1 downto 0);
      dec_sblock_number       : out std_logic_vector(1 downto 0);
      dec_type_data           : out std_logic_vector(TYPE_SIZE - 1 downto 0);
      dec_state_data          : out std_logic;
      dec_type_word           : out std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
      dec_state_words         : out std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);


--Kaa
      dec_number_of_readback_values: out
                std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0); 
--Kaa
      stall                   : in  std_logic;
      dont_issue              : in  std_logic;
      dec_sbm_pipe_access     : out std_logic;
      dec_lss_access          : out std_logic;
      dec_store_rule          : out std_logic;
      dec_rule_number         : out std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
      dec_rule_to_store       : out std_logic_vector(RULE_SIZE - 1 downto 0);
      dec_nbr_of_last_rule    : out std_logic_vector(7 downto 0);
      dec_lutconv_index       : out lutconv_type_bus_t;
      dec_lutconv_write       : out std_logic_vector(LUT_SIZE - 1 downto 0);
      dec_lutconv_write_en    : out std_logic;
      dec_start_devstep       : out std_logic;
      dec_start_config        : out std_logic;
      dec_start_readback      : out std_logic;
      dec_select_sbm          : out std_logic;
      dec_run_matrix          : out std_logic;
      dec_cycles_to_run       : out std_logic_vector(23 downto 0);
      dec_start_dft           : out std_logic;
      dec_dft_set_first_addr  : out std_logic;
      dec_dft_first_addr      : out std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      rst                     : in  std_logic;
      clk                     : in  std_logic);
  end component;

  component lss
    port (
      type_data_write_0   : out bram_type_bus_t;
      state_data_write_0  : out bram_state_bus_t;
      addr_0              : out bram_addr_t;
      type_data_read_0    : in  bram_type_bus_t;
      state_data_read_0   : in  bram_state_bus_t;
--Kaa
      sum_data_read        : in std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      sum_address          : out std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      enable_sum_data_read : out std_logic;

      usedrules_data       :  in std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
      usedrules_read_enable: out std_logic;
      usedrules_read_addr  : out std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);

      rulevector_data      : in std_logic_vector(RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
      read_next_rulevector : out std_logic;
      reset_rulevector_addr: out std_logic;

      fitness_reg_data     : in std_logic_vector(FITNESS_DATA_BUS_SIZE - 1 downto 0);
      fitness_reg_read_enable: out std_logic;
--Kaa

      lss_enable_write_type_0b  : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      lss_enable_write_state_0b : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      lss_enable_read_0a        : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      send                      : out std_logic;
      ack_send                  : in  std_logic;
      data_send                 : out std_logic_vector(63 downto 0);
      dec_read_sblock           : in  std_logic;
      dec_send_type             : in  std_logic;
      dec_send_types            : in  std_logic;
      dec_send_state            : in  std_logic;
      dec_send_states           : in  std_logic;
--Kaa
      dec_read_usedrules        : in std_logic;
--Kaa
      dec_send_sums             : in  std_logic;
      dec_send_used_rules       : in  std_logic;
      dec_send_rulevector       : in std_logic;
      dec_send_fitness          : in std_logic;
      dec_number_of_readback_values: in
                 std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
--Kaa
      dec_write_type            : in  std_logic;
      dec_write_state           : in  std_logic;
      dec_write_word            : in  std_logic;

      dec_address       : in std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
      dec_port_select   : in std_logic_vector(1 downto 0);
      dec_sblock_number : in std_logic_vector(1 downto 0);
      dec_type_data     : in std_logic_vector(TYPE_SIZE - 1 downto 0);
      dec_state_data    : in std_logic;
      dec_type_word     : in std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
      dec_state_words   : in std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);

      dec_clear_bram          : in std_logic;

      stall           : in  std_logic;
      lss_idle        : out std_logic;
      lss_ld2_sending : out std_logic;
      lss_ack_send_i  : out std_logic;

      rst      : in  std_logic;
      clk      : in  std_logic);
  end component;

  component dev
    port (
      ruleset             : in  rule_set_t;
      cache_set_zero      : out std_logic;
      cache_next_set      : out std_logic;
      last_set            : in  std_logic;
      type_data_read_0    : in  bram_type_bus_t;
      state_data_read_0   : in  bram_state_bus_t;
      addr_0              : out bram_addr_t;
      type_data_write_1   : out bram_type_bus_t;
      type_data_read_1    : in bram_type_bus_t;
      state_data_read_1   : in bram_state_bus_t;
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
      dec_start_devstep   : in  std_logic;
      dev_idle            : out std_logic;
      rst                 : in  std_logic;
      clk                 : in  std_logic); 
  end component;

  component sbm_pipe
    port (
      state_data_write_1 : out bram_state_bus_t;
      type_data_read_1   : in  bram_type_bus_t;
      state_data_read_1  : in  bram_state_bus_t;
      addr_1            : out bram_addr_t;

      cfg_enable_read_1b        : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
      rdb_enable_write_state_1 : out std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);

      lut_addr             : out lutconv_type_bus_t;
      lut_read             : in  lutconv_lut_bus_t;
      databus_lut_l_write  : out std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
      databus_lut_h_write  : out std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
      databus_ff_write     : out std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
      config_enable_lut    : out std_logic_vector(CONFIG_WORDS - 1 downto 0);
      config_enable_ff     : out std_logic_vector(CONFIG_WORDS - 1 downto 0);
      databus_read         : in  std_logic_vector(SBM_RDB_SIZE - 1 downto 0);
      output_select        : out std_logic_vector(READBACK_WORDS - 1 downto 0);
      dec_start_config     : in  std_logic;
      dec_start_readback   : in  std_logic;
      dec_run_matrix       : in  std_logic;
      dec_cycles_to_run    : in  std_logic_vector(23 downto 0);
      sbm_pipe_idle        : out std_logic;
      run_matrix           : out std_logic;
      --Kaa
      add                  : out std_logic;

      run_step_mem_address :out std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      run_step_mem_write_enable : out std_logic;
      --Kaa
      rst                  : in  std_logic;
      clk                  : in  std_logic);
  end component;

  component run_step_funk
    port (
    data_bus : in  std_logic_vector (SBM_FNK_SIZE - 1 downto 0);
    active   : in  std_logic;
    address_in     : in std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    write_enable_in: in std_logic;
    value           : out std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    address_out     : out std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    write_enable_out: out std_logic;
    clk      : in  std_logic;
    rst      : in  std_logic);
  end component;


  component bitcounter4
    port (
      a : in  std_logic;
      b : in  std_logic;
      c : in  std_logic;
      d : in  std_logic;
      f : out std_logic_vector (2 downto 0));
  end component;

  component bitcounter8 
    port (
      input : in  std_logic_vector (7 downto 0);  --between 0 and 4
      f : out std_logic_vector (3 downto 0));
  end component;

  component bitcounterN
    generic (
      N : integer;
      L : integer);
    port (
      input : in  std_logic_vector (N - 1 downto 0);
      f     : out std_logic_vector (L - 1 downto 0);
      clk   : in std_logic);
  end component;

  component run_step_mem
    port (
      address1     : in  std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      address2     : in  std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      data_read1   : out std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      data_read2   : out std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      data_write   : in  std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      write_enable : in  std_logic;
      read_enable  : in  std_logic;   

      stall        : in std_logic;
      rst          : in std_logic;
      clk          : in std_logic);
  end component;
  
  component rulevector_mem
    port (
      data_read    : out std_logic_vector (RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
      data_write   :  in std_logic_vector (RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
      write_enable :  in std_logic;
      reset_counter:  in std_logic;
      read_next    :  in std_logic;
      
      stall        :  in std_logic;
      
      rst : in std_logic;
      clk : in std_logic);
  end component;

  component usedrules_mem
    port (
      address_read : in  std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);--512 addresses
      address_write: in  std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);--512 addresses
      data_read    : out std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
      data_write   : in  std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
      write_enable : in  std_logic;
      --read_enable  : in  std_logic;   
      stall        : in std_logic;
      rst          : in std_logic;
      clk          : in std_logic);
  end component;

  component decode_and_or is
  port (
    input          : in selected_rule_t;
    output         :out std_logic_vector(2 ** RULE_NBR_BUS_SIZE - 1 downto 0));
  end component;

  component fitness_pipe
    port (
      dec_start_fitness   :  in std_logic;
      fitness_data        : out std_logic_vector(FITNESS_DATA_BUS_SIZE - 1 downto 0);
      read_enable         :  in std_logic;
      data_in             :  in std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      data_addr           : out std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      dft_output          : in  dft_res_t;
      run_step_to_evaluate:  in std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      -- hazard
      stall               :  in std_logic;
      fitness_idle        : out std_logic;
      -- other
      rst                 : in std_logic;
      clk                 : in std_logic);
  end component;

  component fitness_funk
    port (
      ld_finished      :  in std_logic;
      fitness_finished : out std_logic;
      active           :  in std_logic;
      data             :  in std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      result           : out std_logic_vector(FITNESS_RESULT_SIZE - 1 downto 0);
      stall            :  in std_logic;
      rst              :  in std_logic;
      clk              :  in std_logic);

  end component;
--Kaa

  component dft
    port (
      start_dft  : in  std_logic;
      data_in    : in  std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      data_addr  : out std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      first_addr : in  std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      set_first_addr : in std_logic;
      dft_idle   : out std_logic;
      output     : out dft_res_t;
      rst : in std_logic;
      clk : in std_logic);
  end component;

  component twmem
    generic (
	    ind : integer);
    port (
      clk : in std_logic;
		  address : in integer;
      data_o : out std_logic_vector(TWLEN-1 downto 0));
  end component;

end sblock_package;

