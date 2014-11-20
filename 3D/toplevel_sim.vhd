-------------------------------------------------------------------------------
-- Title      : Toplevel
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : toplevel.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
--            : Per Thomas Lundal
-- Company    : 
-- Last update: 2014/11/09
-- Platform   : Spartan-6 LX45T
-------------------------------------------------------------------------------
-- Description: Connects all main components
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/09  3.1      lundal    Added compatibility layer
-- 2014/04/09  3.0      stoevneng Added components
-- 2005/03/17  2.0      aamodt    Added components
-- 2003/01/17  1.1      djupdal
-- 2002/10/28  1.0      djupdal   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sblock_package.all;

entity toplevel_sim is
  port (
    sim_tx_buffer_data  : out std_logic_vector(31 downto 0);
    sim_tx_buffer_count : out std_logic_vector(31 downto 0);
    sim_tx_buffer_read  : in  std_logic;

    sim_rx_buffer_data  : in  std_logic_vector(31 downto 0);
    sim_rx_buffer_count : out std_logic_vector(31 downto 0);
    sim_rx_buffer_write : in  std_logic;

    clock_p : in  std_logic;
    clock_n : in  std_logic;
    reset_n : in  std_logic;

    leds : out std_logic_vector(3 downto 0)
  );
end toplevel_sim;

architecture rtl of toplevel_sim is

  -- General
  signal clock : std_logic;
  signal reset : std_logic;
  signal reset_n_i : std_logic;

  -----------------------------------------------------------------------------
  -- signals connecting components

  -- Communication
  signal tx_buffer_data  : std_logic_vector(31 downto 0);
  signal tx_buffer_count : std_logic_vector(31 downto 0);
  signal tx_buffer_write : std_logic;

  signal rx_buffer_data  : std_logic_vector(31 downto 0);
  signal rx_buffer_count : std_logic_vector(31 downto 0);
  signal rx_buffer_read  : std_logic;

  -- com40

  signal send         : std_logic;
  signal ack_send     : std_logic;
  signal receive      : std_logic;
  signal ack_receive  : std_logic;
  signal data_send    : std_logic_vector(63 downto 0);
  signal data_receive : std_logic_vector(63 downto 0);

  -- rule storage

  signal ruleset        : rule_set_t;
  signal cache_set_zero : std_logic;
  signal cache_next_set : std_logic;
  signal last_set       : std_logic;
  signal store_rule     : std_logic;
  signal rule_number    : std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
  signal rule_to_store  : std_logic_vector(RULE_SIZE - 1 downto 0);
  signal nbr_of_last_rule : std_logic_vector(7 downto 0);

  -- lut conv

  signal index     : lutconv_type_bus_t;
  signal lut_read  : lutconv_lut_bus_t;
  signal lut_slct  : std_logic_vector(LUTCONV_SELECT_SIZE - 1 downto 0);
  signal lut_write : std_logic_vector(LUT_SIZE - 1 downto 0);
  signal write_en  : std_logic;

  -- sblock matrix

  signal databus_read        : std_logic_vector(SBM_RDB_SIZE - 1 downto 0);
  signal databus_read_funk   : std_logic_vector(SBM_FNK_SIZE - 1 downto 0);
  signal output_funk_select  : std_logic_vector(RSF_READS_SIZE - 1 downto 0);
  signal output_select       : std_logic_vector(READBACK_WORDS - 1 downto 0);
  signal databus_lut_write   : std_logic_vector(SBM_CFG_SIZE*SRLS_PER_LUT - 1 downto 0);
  signal databus_ff_write    : std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
  signal config_enable_lut   : std_logic_vector(CONFIG_WORDS - 1 downto 0);
  signal config_enable_ff    : std_logic_vector(CONFIG_WORDS - 1 downto 0);
  signal run_matrix          : std_logic;

  -- sbm bram mgr

  signal type_data_read_0   : bram_type_bus_t;
  signal type_data_write_0  : bram_type_bus_t;
  signal state_data_read_0  : bram_state_bus_t;
  signal state_data_write_0 : bram_state_bus_t;
  signal addr_0             : bram_addr_t;
  signal type_data_read_1   : bram_type_bus_t;
  signal type_data_write_1  : bram_type_bus_t;
  signal state_data_read_1  : bram_state_bus_t;
  signal state_data_write_1 : bram_state_bus_t;
  signal addr_1             : bram_addr_t;

  signal dev_enable_read_0         : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
  signal dev_enable_write_1a       : std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
  signal dev_enable_read_1b        : std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
  signal lss_enable_read_0a        : std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
  signal lss_enable_write_type_0b  : std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
  signal lss_enable_write_state_0b : std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
  signal cfg_enable_read_1b        : std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
  signal rdb_enable_write_state_1  : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
  signal select_sbm                : std_logic;

--Kaa
  signal dev_usedrules_read         : std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  signal dev_usedrules_write        : std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  signal dev_usedrules_addr_read    : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal dev_usedrules_addr_write   : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal dev_usedrules_read_enable  : std_logic;
  signal dev_usedrules_write_enable : std_logic;

  signal dev_rulevector_data_write    : std_logic_vector(RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
  signal dev_rulevector_write_enable  : std_logic;
--Kaa
  
  -- hazard

  signal dont_issue_dec     : std_logic;
  signal stall_lss          : std_logic;
  signal stall_dec          : std_logic;
  signal stall_fetch        : std_logic;
  signal stall_sbm_bram_mgr : std_logic;
  
--Kaa
  signal stall_usedrules_mem : std_logic;
  signal stall_run_step_mem  : std_logic;
  signal stall_rulevector_mem: std_logic;
  signal stall_fitness       : std_logic;

--Kaa
  -- fetch

  signal fetch_instruction       : std_logic_vector(INSTR_SIZE - 1 downto 0);
  signal fetch_valid             : std_logic;
  signal fetch_enter_normal_mode : std_logic;
  signal fetch_count_pc          : std_logic;

  -- decode

  signal flush_fetch         : std_logic;

  signal dec_program_counter : std_logic_vector(7 downto 0);
  signal dec_valid           : std_logic;
  signal dec_program_store   : std_logic;
  signal dec_read_sblock     : std_logic;
--Kaa
  signal dec_read_usedrules  : std_logic;
--Kaa
  signal dec_clear_bram      : std_logic;
  signal dec_send_type       : std_logic;
  signal dec_send_types      : std_logic;
  signal dec_send_state      : std_logic;
  signal dec_send_states     : std_logic;
  signal dec_send_rulevector : std_logic;
  signal dec_send_fitness    : std_logic;
--Kaa
  signal dec_send_sums       : std_logic;
  signal dec_send_used_rules : std_logic;
  signal dec_number_of_readback_values :
    std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal dec_start_fitness   : std_logic;
--Kaa
  signal dec_write_type      : std_logic;
  signal dec_write_state     : std_logic;
  signal dec_write_word      : std_logic;
  signal dec_address         : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal dec_port_select     : std_logic_vector(2 downto 0);
  signal dec_sblock_number   : std_logic_vector(COORD_SIZE_X - 2 downto 0);
  signal dec_type_data       : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal dec_state_data      : std_logic;
  signal dec_type_word       : std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
  signal dec_state_words     : std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);
  signal dec_lutconv_index   : lutconv_type_bus_t;
  signal dec_lutconv_write   : std_logic_vector(LUT_SIZE - 1 downto 0);

  signal dec_lutconv_write_en : std_logic;
  signal dec_start_devstep    : std_logic;
  signal dec_start_config     : std_logic;
  signal dec_start_readback   : std_logic;

  signal dec_sbm_pipe_access : std_logic;
  signal dec_lss_access      : std_logic;

  signal dec_run_matrix    : std_logic;
  signal dec_cycles_to_run : std_logic_vector(23 downto 0);

  -- lss

  signal lss_idle        : std_logic;
  signal lss_ld2_sending : std_logic;
  signal lss_ack_send_i  : std_logic;
--Kaa
  signal lss_usedrules_read_enable: std_logic;
  signal lss_usedrules_addr_read  :
    std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);

  signal lss_rulevector_data_read  :
    std_logic_vector (RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
  signal lss_rulevector_read_next  : std_logic;
  signal lss_rulevector_reset      : std_logic;
--Kaa

  -- dev

  signal dev_idle : std_logic;

  -- cfg

  signal sbm_pipe_idle : std_logic;

--Kaa

  -- sum
  signal run_step_funk_add   : std_logic;
  signal run_step_funk_address      : std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal run_step_funk_write_enable : std_logic;
  signal run_step_first : std_logic;
  
  --run_step_mem
  signal run_step_mem_address1     :
    std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal run_step_mem_address2     :
    std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal run_step_mem_read1        :
    std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
  signal run_step_mem_read2        :
    std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
  signal run_step_mem_write_data   :
    std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
  signal run_step_mem_write_enable : std_logic;
  signal run_step_mem_read_enable  : std_logic;

  --usedrules_mem
  signal usedrules_addr_read      : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);

  --rulevector_mem

  signal rulevector_data_read     :
    std_logic_vector(RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
  signal rulevector_enable_read   : std_logic;
    
  --fitness
  signal fitness_read_data    :
    std_logic_vector(FITNESS_DATA_BUS_SIZE - 1 downto 0);
  signal fitness_read_enable  : std_logic;
  signal fitness_pipe_idle    : std_logic;
--Kaa

  --dft
  signal dec_start_dft : std_logic;
  signal dft_first_addr : std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal dft_set_first_addr : std_logic;
  signal dft_idle : std_logic;
  signal dft_output : dft_res_t;

begin  -- toplevel_arch

  leds <= "0101";
  reset_n_i <= not reset;

  -----------------------------------------------------------------------------

  com_unit : entity work.communication_sim
  generic map (
    tx_buffer_address_bits => 4,
    rx_buffer_address_bits => 4,
    reverse_payload_endian => true -- Required for x86 systems
  )
  port map (
    sim_tx_buffer_data  => sim_tx_buffer_data,
    sim_tx_buffer_count => sim_tx_buffer_count,
    sim_tx_buffer_read  => sim_tx_buffer_read,

    sim_rx_buffer_data  => sim_rx_buffer_data,
    sim_rx_buffer_count => sim_rx_buffer_count,
    sim_rx_buffer_write => sim_rx_buffer_write,

    clock_p => clock_p,
    clock_n => clock_n,
    reset_n => reset_n,

    tx_buffer_data  => tx_buffer_data,
    tx_buffer_count => tx_buffer_count,
    tx_buffer_write => tx_buffer_write,

    rx_buffer_data  => rx_buffer_data,
    rx_buffer_count => rx_buffer_count,
    rx_buffer_read  => rx_buffer_read,

    clock => clock,
    reset => reset
  );

  com40_unit: entity work.com40_compatibility_layer
  generic map (
    reverse_payload_endian => true -- Required for x86 systems
  )
  port map (
    -- COM40
    send         => send,
    ack_send     => ack_send,
    receive      => receive,
    ack_receive  => ack_receive,
    data_send    => data_send,
    data_receive => data_receive,
    -- PCIe
    tx_buffer_data  => tx_buffer_data,
    tx_buffer_count => tx_buffer_count,
    tx_buffer_write => tx_buffer_write,
    rx_buffer_data  => rx_buffer_data,
    rx_buffer_count => rx_buffer_count,
    rx_buffer_read  => rx_buffer_read,
    -- General
    clock => clock,
    reset => reset
  );

  rule_storage_unit: entity work.rule_storage
    port map (
      ruleset             => ruleset,
      cache_set_zero      => cache_set_zero,
      cache_next_set      => cache_next_set,
      last_set            => last_set,
      store_rule          => store_rule,
      rule_number         => rule_number,
      rule_to_store       => rule_to_store,
      nbr_of_last_rule    => nbr_of_last_rule,
      rst                 => reset_n_i,
      clk                 => clock);

  lutconv_unit: entity work.lutconv
    port map (
      index     => index,
      lut_read  => lut_read,
      slct      => lut_slct,
      lut_write => lut_write,
      write_en  => write_en,
      rst       => reset_n_i,
      clk       => clock);

  sbm_unit: entity work.sblock_matrix
    port map (
      databus_read        => databus_read,
      databus_read_funk   => databus_read_funk,
      output_funk_select  => output_funk_select,
      output_select       => output_select,
      databus_lut_write   => databus_lut_write,
      databus_ff_write    => databus_ff_write,
      config_enable_lut   => config_enable_lut,
      config_enable_ff    => config_enable_ff,
      run_matrix          => run_matrix,
      rst                 => reset_n_i,
      clk                 => clock);


  sbm_bram_mgr_unit: entity work.sbm_bram_mgr
    port map (
      type_data_read_0          => type_data_read_0,
      type_data_write_0         => type_data_write_0,
      state_data_read_0         => state_data_read_0,
      state_data_write_0        => state_data_write_0,
      addr_0                    => addr_0,
      type_data_read_1          => type_data_read_1,
      type_data_write_1         => type_data_write_1,
      state_data_read_1         => state_data_read_1,
      state_data_write_1        => state_data_write_1,
      addr_1                    => addr_1,
      dev_enable_read_0         => dev_enable_read_0,
      dev_enable_read_1b        => dev_enable_read_1b,
      dev_enable_write_1a       => dev_enable_write_1a,
      lss_enable_read_0a        => lss_enable_read_0a,
      lss_enable_write_type_0b  => lss_enable_write_type_0b,
      lss_enable_write_state_0b => lss_enable_write_state_0b,
      cfg_enable_read_1b        => cfg_enable_read_1b,
      rdb_enable_write_state_1  => rdb_enable_write_state_1,
      stall                     => stall_sbm_bram_mgr,
      select_sbm                => select_sbm,
      rst                       => reset_n_i,
      clk                       => clock);

  hazard_unit: entity work.hazard
    port map (
      dont_issue_dec        => dont_issue_dec,
      stall_lss             => stall_lss,
      stall_dec             => stall_dec,
      stall_fetch           => stall_fetch,
      stall_sbm_bram_mgr    => stall_sbm_bram_mgr,
--Kaa
      stall_usedrules_mem   => stall_usedrules_mem,
      stall_run_step_mem    => stall_run_step_mem,
      stall_rulevector_mem  => stall_rulevector_mem,
      stall_fitness         => stall_fitness,
--Kaa
      fetch_valid           => fetch_valid,
      dec_lss_access        => dec_lss_access,
      dec_sbm_pipe_access   => dec_sbm_pipe_access,
      dec_start_devstep     => dec_start_devstep,
--Kaa
      dec_start_fitness     => dec_start_fitness,
--Kaa
      lss_idle              => lss_idle,
      lss_ld2_sending       => lss_ld2_sending,
      lss_ack_send_i        => lss_ack_send_i,
      send                  => send,
      dev_idle              => dev_idle,
      sbm_pipe_idle         => sbm_pipe_idle,
--Kaa
      fitness_pipe_idle     => fitness_pipe_idle,
--Kaa
      dft_idle              => dft_idle,
      dec_start_dft         => dec_start_dft,
      rst                   => reset_n_i,
      clk                   => clock);

  fetch_unit : entity work.fetch
    port map (
      fetch_instruction       => fetch_instruction,
      fetch_valid             => fetch_valid,
      fetch_enter_normal_mode => fetch_enter_normal_mode,
      fetch_count_pc          => fetch_count_pc,
      program_counter         => dec_program_counter,
      valid                   => dec_valid,
      program_store           => dec_program_store,
      stall                   => stall_fetch,
      flush                   => flush_fetch,
      receive                 => receive,
      ack_receive             => ack_receive,
      data_receive            => data_receive,
      rst                     => reset_n_i,
      clk                     => clock);

  decode_unit: entity work.decode
    port map (
      fetch_instruction       => fetch_instruction,
      fetch_valid             => fetch_valid,
      fetch_enter_normal_mode => fetch_enter_normal_mode,
      fetch_count_pc          => fetch_count_pc,
      dec_program_counter     => dec_program_counter,
      dec_valid               => dec_valid,
      flush_fetch             => flush_fetch,
      dec_program_store       => dec_program_store,
      dec_read_sblock         => dec_read_sblock,
--Kaa
      dec_read_usedrules      => dec_read_usedrules,
--Kaa
      dec_clear_bram          => dec_clear_bram,
      dec_send_type           => dec_send_type,
      dec_send_types          => dec_send_types,
      dec_send_state          => dec_send_state,
      dec_send_states         => dec_send_states,
      dec_write_type          => dec_write_type,
      dec_write_state         => dec_write_state,
      dec_write_word          => dec_write_word,
--Kaa
      dec_send_sums           => dec_send_sums,
      dec_send_used_rules     => dec_send_used_rules,
      dec_send_rulevector     => dec_send_rulevector,
      dec_send_fitness        => dec_send_fitness,
      dec_start_fitness       => dec_start_fitness,
--Kaa
      dec_address             => dec_address,
      dec_port_select         => dec_port_select,
      dec_sblock_number       => dec_sblock_number,
      dec_type_data           => dec_type_data,
      dec_state_data          => dec_state_data,
      dec_type_word           => dec_type_word,
      dec_state_words         => dec_state_words,
--Kaa
      dec_number_of_readback_values => dec_number_of_readback_values,
--Kaa
      stall                   => stall_dec,
      dont_issue              => dont_issue_dec,
      dec_sbm_pipe_access     => dec_sbm_pipe_access,
      dec_lss_access          => dec_lss_access,
      dec_store_rule          => store_rule,
      dec_rule_number         => rule_number,
      dec_rule_to_store       => rule_to_store,
      dec_nbr_of_last_rule => nbr_of_last_rule,
      dec_lutconv_index       => index,
      dec_lutconv_write       => lut_write,
      dec_lutconv_write_en    => write_en,
      dec_start_devstep       => dec_start_devstep,
      dec_start_config        => dec_start_config,
      dec_start_readback      => dec_start_readback,
      dec_select_sbm          => select_sbm,
      dec_run_matrix          => dec_run_matrix,
      dec_cycles_to_run       => dec_cycles_to_run,
      dec_start_dft           => dec_start_dft,
      dec_dft_set_first_addr  => dft_set_first_addr,
      dec_dft_first_addr      => dft_first_addr,
      rst                     => reset_n_i,
      clk                     => clock);

  lss_unit: entity work.lss
    port map (
      type_data_write_0         => type_data_write_0,
      state_data_write_0        => state_data_write_0,
      addr_0                    => addr_0,
      type_data_read_0          => type_data_read_0,
      state_data_read_0         => state_data_read_0,
--Kaa
      sum_data_read             => run_step_mem_read1,
      sum_address               => run_step_mem_address1,
      enable_sum_data_read      => run_step_mem_read_enable,
      dec_number_of_readback_values => dec_number_of_readback_values,

      usedrules_data            => dev_usedrules_read,
      usedrules_read_enable     => lss_usedrules_read_enable,
      usedrules_read_addr       => usedrules_addr_read,  --lss**

      rulevector_data           => lss_rulevector_data_read,
      read_next_rulevector      => lss_rulevector_read_next,
      reset_rulevector_addr     => lss_rulevector_reset,

      fitness_reg_data          => fitness_read_data,
      fitness_reg_read_enable   => fitness_read_enable,
--Kaa
      lss_enable_write_type_0b  => lss_enable_write_type_0b,
      lss_enable_write_state_0b => lss_enable_write_state_0b,
      lss_enable_read_0a        => lss_enable_read_0a,
      send                      => send,
      ack_send                  => ack_send,
      data_send                 => data_send,
      dec_read_sblock           => dec_read_sblock,
--Kaa
      dec_read_usedrules        => dec_read_usedrules,
--Kaa
      dec_send_type             => dec_send_type,
      dec_send_types            => dec_send_types,
      dec_send_state            => dec_send_state,
      dec_send_states           => dec_send_states,
--Kaa
      dec_send_sums             => dec_send_sums,
      dec_send_used_rules       => dec_send_used_rules,
      dec_send_rulevector       => dec_send_rulevector,
      dec_send_fitness          => dec_send_fitness,
--Kaa
      dec_write_type            => dec_write_type,
      dec_write_state           => dec_write_state,
      dec_write_word            => dec_write_word,
      dec_address               => dec_address,
      dec_port_select           => dec_port_select,
      dec_sblock_number         => dec_sblock_number,
      dec_type_data             => dec_type_data,
      dec_state_data            => dec_state_data,
      dec_type_word             => dec_type_word,
      dec_state_words           => dec_state_words,
      dec_clear_bram            => dec_clear_bram,

      stall                     => stall_lss,
      lss_idle                  => lss_idle,
      lss_ld2_sending           => lss_ld2_sending,
      lss_ack_send_i            => lss_ack_send_i,

      rst                       => reset_n_i,
      clk                       => clock);

  dev_unit: entity work.dev
    port map (
      ruleset             => ruleset,
      cache_set_zero      => cache_set_zero,
      cache_next_set      => cache_next_set,
      last_set            => last_set,
      type_data_read_0    => type_data_read_0,
      state_data_read_0   => state_data_read_0,
      addr_0              => addr_0,
      type_data_write_1   => type_data_write_1,
      type_data_read_1    => type_data_read_1,
      state_data_write_1  => state_data_write_1,
      state_data_read_1   => state_data_read_1,
      addr_1              => addr_1,
      dev_enable_read_0   => dev_enable_read_0,
      dev_enable_write_1a  => dev_enable_write_1a,
      dev_enable_read_1b   => dev_enable_read_1b,
--Kaa
      dev_usedrules_read        => dev_usedrules_read,
      dev_usedrules_write       => dev_usedrules_write,  
      dev_usedrules_addr_read   => usedrules_addr_read,  --dev**
      dev_usedrules_addr_write  => dev_usedrules_addr_write,
      dev_usedrules_read_enable => dev_usedrules_read_enable,
      dev_usedrules_write_enable=> dev_usedrules_write_enable,

      dev_rulevector_data_write   => dev_rulevector_data_write,
      dev_rulevector_write_enable => dev_rulevector_write_enable,
--Kaa
      
      dec_start_devstep   => dec_start_devstep,
      dev_idle            => dev_idle,

      rst                 => reset_n_i,
      clk                 => clock);

  sbm_pipe_unit: entity work.sbm_pipe
    port map (
      state_data_write_1        => state_data_write_1,
      type_data_read_1          => type_data_read_1,
      state_data_read_1         => state_data_read_1,
      addr_1                    => addr_1,
      cfg_enable_read_1b        => cfg_enable_read_1b,
      rdb_enable_write_state_1  => rdb_enable_write_state_1,
      lut_addr                  => index,
      lut_read                  => lut_read,
      lut_slct                  => lut_slct,
      databus_lut_write         => databus_lut_write,
      databus_ff_write          => databus_ff_write,
      config_enable_lut         => config_enable_lut,
      config_enable_ff          => config_enable_ff,
      databus_read              => databus_read,
      output_funk_select        => output_funk_select,
      output_select             => output_select,
      dec_start_config          => dec_start_config,
      dec_start_readback        => dec_start_readback,
      dec_run_matrix            => dec_run_matrix,
      dec_cycles_to_run         => dec_cycles_to_run,
      sbm_pipe_idle             => sbm_pipe_idle,
      run_matrix                => run_matrix,
--Kaa
      add                       => run_step_funk_add,
      run_step_mem_address      => run_step_funk_address,
      run_step_mem_write_enable => run_step_funk_write_enable,
      run_step_first            => run_step_first,
--Kaa
      rst                       => reset_n_i,
      clk                       => clock);

--Kaa
  run_step_funk_unit: entity work.run_step_funk
    port map (
      data_bus         => databus_read_funk,
      active           => run_step_funk_add,
      address_in       => run_step_funk_address,
      write_enable_in  => run_step_funk_write_enable,
      value            => run_step_mem_write_data,
      address_out      => run_step_mem_address1,
      write_enable_out => run_step_mem_write_enable,
      first_in         => run_step_first,
      rst      => reset_n_i,
      clk      => clock);

  run_step_mem_unit: entity work.run_step_mem
    port map (
      address1      => run_step_mem_address1,
      address2      => run_step_mem_address2,
      data_read1    => run_step_mem_read1,
      data_read2    => run_step_mem_read2,
      data_write   => run_step_mem_write_data,
      write_enable => run_step_mem_write_enable,
      read_enable  => run_step_mem_read_enable,
      stall        => stall_run_step_mem,
      rst          => reset_n_i,
      clk          => clock);

  rulevector_mem_unit: entity work.rulevector_mem
  port map(
    data_read     => lss_rulevector_data_read,
    data_write    => dev_rulevector_data_write,
    write_enable  => dev_rulevector_write_enable,
    reset_counter => lss_rulevector_reset,
    read_next     => lss_rulevector_read_next,
    stall         => stall_rulevector_mem,
    rst           => reset_n_i,
    clk           => clock);

  dft_unit : entity work.dft
   port map(
    start_dft   => dec_start_dft,
    data_in     => run_step_mem_read2,
    data_addr   => run_step_mem_address2,
    first_addr  => dft_first_addr,
    set_first_addr => dft_set_first_addr,
    dft_idle        => dft_idle,
    output      => dft_output,
    rst         => reset_n_i,
    clk         => clock);

  fitness_pipe_unit: entity work.fitness_pipe
    port map (
      dec_start_fitness    => dec_start_fitness,
      fitness_data         => fitness_read_data,
      read_enable          => fitness_read_enable,
      data_in              => run_step_mem_read1,
      data_addr            => run_step_mem_address1,
      dft_output           => dft_output,
      run_step_to_evaluate => dec_number_of_readback_values,  --using same bus
      stall                => stall_fitness,
      fitness_idle         => fitness_pipe_idle,
      rst                  => reset_n_i,
      clk                  => clock);
  
  usedrules_mem_unit: entity work.usedrules_mem
    port map (
      address_read  => usedrules_addr_read,
      address_write => dev_usedrules_addr_write,
      data_read     => dev_usedrules_read,
      data_write    => dev_usedrules_write,
      write_enable  => dev_usedrules_write_enable,
      stall         => stall_usedrules_mem,
      rst           => reset_n_i,
      clk           => clock);
  
--   process(dev_usedrules_read_enable, lss_usedrules_read_enable,
--           dev_usedrules_addr_read, lss_usedrules_addr_read)
--   begin  
--     --can be read from both LSS and Development unit
--     if dev_usedrules_read_enable = '1'  then
--       usedrules_addr_read <= dev_usedrules_addr_read;
--     else
--       usedrules_addr_read <= lss_usedrules_addr_read;
--     end if;
    
--   end process;
  
end rtl;
