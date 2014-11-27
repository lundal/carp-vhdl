-------------------------------------------------------------------------------
-- Title      : SBM Pipeline
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sbm_pipe.vhd
-- Author     : Asbjørn Djupdal  <djupdal@harryklein>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2013/12/10
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Pipeline for doing operations on sblock matrix (config,
--              readback, run) 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2013/12/10  3.0      stoevneng Updated
-- 2005/03/17  2.0      kjetil    Updated
-- 2003/02/24  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;
use work.funct_package.all;

entity sbm_pipe is

  port (
    -- sbm bram mgr

    state_data_write_1 : out bram_state_bus_t;
    type_data_read_1   : in  bram_type_bus_t;
    state_data_read_1  : in  bram_state_bus_t;
    addr_1             : out bram_addr_t;
    cfg_enable_read_1b : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
    rdb_enable_write_state_1 : out std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);

    -- lutconv

    lut_addr : out lutconv_type_bus_t;
    lut_read : in  lutconv_lut_bus_t;

    -- sbm

    databus_lut_l_write : out std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
    databus_lut_h_write : out std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
    databus_ff_write    : out std_logic_vector(SBM_CFG_SIZE - 1 downto 0);

    config_enable_lut : out std_logic_vector(CONFIG_WORDS - 1 downto 0);
    config_enable_ff  : out std_logic_vector(CONFIG_WORDS - 1 downto 0);

    databus_read  : in  std_logic_vector(SBM_RDB_SIZE - 1 downto 0);
    output_select : out std_logic_vector(READBACK_WORDS - 1 downto 0);

    run_matrix : out std_logic;

    -- decode

    dec_start_config   : in std_logic;
    dec_start_readback : in std_logic;
    dec_run_matrix     : in std_logic;

    dec_cycles_to_run  : in std_logic_vector(23 downto 0);

    -- hazard

    sbm_pipe_idle : out std_logic;

--Kaa
    -- run_step_function
    add       : out std_logic;

    run_step_mem_address      : out std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    run_step_mem_write_enable : out std_logic;
--Kaa

    -- other

    rst : in std_logic;
    clk : in std_logic);

end sbm_pipe;

architecture sbm_pipe_arch of sbm_pipe is

  signal zero : std_logic_vector(2 downto 0);

  -----------------------------------------------------------------------------
  -- signals are grouped after the pipeline stage they are used in
  -- pipeline registers are named with the pipeline stage name as prefix
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Control

  type control_state_type is (idle, run_sbm, config, readback,
                              write_last,
                              wait_to_finish);

  signal control_state : control_state_type;

  -- config signals

  signal count_row            : std_logic;
  signal row_counter_finished : std_logic;
  signal reset_row_counter    : std_logic;
  signal row_value            : std_logic_vector(COORD_SIZE_Y - 1 downto 0);

  signal count_column            : std_logic;
  signal column_counter_finished : std_logic;
  signal reset_column_counter    : std_logic;
  signal column_value            : std_logic_vector(COORD_SIZE_X - 4 downto 0);

  signal addr        : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal port_select : std_logic_vector(1 downto 0);

  signal row_count_to    : unsigned(COORD_SIZE_Y - 1 downto 0);
  signal column_count_to : unsigned(COORD_SIZE_X - 4 downto 0);

  -- readback signals

  signal restart     : std_logic;
  signal select_next : std_logic;

  -- sbm signals

  signal cycles_to_run  : std_logic_vector(23 downto 0);
  signal restart_run    : std_logic;
  signal cycle_count_to : unsigned(23 downto 0);
  signal run_count      : std_logic;
  signal run_finished   : std_logic;
  signal count_zero     : std_logic;

  -- pipeline registers for config pipe

  -- signals an access to config pipeline
  signal control_cfg_access      : std_logic;
  -- shows which read/write ports to use on the BRAM
  -- see addr_gen.vhd for details
  signal control_cfg_port_select : std_logic;

  -- pipeline registers for readback pipe

  -- signals an access to readback pipe
  signal control_rdb_access        : std_logic;
  -- which group og sblocks should drive the output databus
  signal control_rdb_selected_word :
    std_logic_vector(READBACK_WORDS - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Fetch1

  signal fetch1_access      : std_logic;
  signal fetch1_port_select : std_logic;

  -----------------------------------------------------------------------------
  -- Fetch2

  signal fetch2_access      : std_logic;
  signal fetch2_port_select : std_logic;

  -----------------------------------------------------------------------------
  -- Convert1

  signal convert1_access  : std_logic;
  signal convert1_ff      : std_logic_vector(LUTCONVS_PER_CYCLE - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Convert2

  signal convert2_access  : std_logic;
  signal convert2_ff      : std_logic_vector(LUTCONVS_PER_CYCLE - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Convert3

  signal convert3_access  : std_logic;
  -- lut for sblocks
  signal convert3_lut     : lutconv_lut_bus_t;
  -- flipflop for sblocks
  signal convert3_ff      : std_logic_vector(LUTCONVS_PER_CYCLE - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Buffer1-16

  constant SBM_CFG_BUS_SIZE : integer := 8;
  constant SBM_CFG_INDEX_SIZE : integer := SBM_CFG_BUS_SIZE - 3;

  type lut_cfg_buffer_t is array (SBM_CFG_SIZE - 1 downto 0)
    of std_logic_vector(LUT_SIZE - 1 downto 0);

  signal lut_cfg_buffer_i : lut_cfg_buffer_t;
  signal lut_cfg_buffer_1 : lut_cfg_buffer_t;
  signal lut_cfg_buffer_2 : lut_cfg_buffer_t;
  signal ff_cfg_buffer_i  : std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
  signal ff_cfg_buffer    : std_logic_vector(SBM_CFG_SIZE - 1 downto 0);

  signal config_delay  : std_logic_vector(14 downto 0);
  signal next_delay    : std_logic_vector(14 downto 0);

  signal selected_word : std_logic_vector(CONFIG_WORDS - 1 downto 0);

  signal index_restart  : std_logic;
  signal index_count_to : unsigned(SBM_CFG_INDEX_SIZE - 1 downto 0);
  signal index          : std_logic_vector(SBM_CFG_INDEX_SIZE - 1 downto 0);
  signal index_finished : std_logic;

  signal reset_ws : std_logic;

  -----------------------------------------------------------------------------
  -- Config

  signal cfg_access : std_logic;
  signal addr_1_conf : bram_addr_t;

  -----------------------------------------------------------------------------
  -- Readback1

  signal readback1_access : std_logic;

  -----------------------------------------------------------------------------
  -- Readback2

  signal rd1_restart : std_logic;
  signal addr_2 : std_logic_vector(ADDR_BUS_SIZE - 2 downto 0);
  signal addr_count_to : unsigned(ADDR_BUS_SIZE - 2 downto 0);
  signal addr_1_rdb : bram_addr_t;
  signal rdb_access : std_logic;
  -----------------------------------------------------------------------------
  -- Store

--Kaa
  -----------------------------------------------------------------------------
  -- Run-step function
  signal first_step          : std_logic;
  signal count_sum_address   : std_logic;
  signal reset_sum_address   : std_logic;
  signal max_sum_address     : unsigned (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal run_step_mem_address_i : std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
--Kaa
  
begin

  lut_addr <= (others => (others => 'Z'));
  
  zero <= "000";

  -----------------------------------------------------------------------------
  -- Control
  -----------------------------------------------------------------------------

  row_count_to <= to_unsigned (ROWS - 1, COORD_SIZE_Y);

  row_counter: counter
    generic map (
      SIZE     => COORD_SIZE_Y)
    port map (
      reset    => reset_row_counter,
      count    => count_row,
      count_to => row_count_to,
      zero     => open,
      finished => row_counter_finished,
      value    => row_value,
      clk      => clk);

  -----------------------------------------------------------------------------

  column_count_to <= to_unsigned ((COLUMNS / LUTCONVS_PER_CYCLE) - 1, COORD_SIZE_X - 3);

  column_counter: counter
    generic map (
      SIZE     => COORD_SIZE_X - 3)
    port map (
      reset    => reset_column_counter,
      count    => count_column,
      count_to => column_count_to,
      zero     => open,
      finished => column_counter_finished,
      value    => column_value,
      clk      => clk);

--Kaa
  max_sum_address <= to_unsigned(2**RUN_STEP_ADDR_BUS_SIZE - 1, RUN_STEP_ADDR_BUS_SIZE); 

  sum_address_counter: counter
    generic map (
      SIZE => RUN_STEP_ADDR_BUS_SIZE)
    port map (
      reset    => reset_sum_address,
      count    => count_sum_address,
      count_to => max_sum_address,
      zero     => open,
      finished => open,
      value    => run_step_mem_address_i,
      clk      => clk);
--Kaa

  -----------------------------------------------------------------------------

  addr_generator: addr_gen
    port map (
      x(COORD_SIZE_X - 1 downto 3) => column_value,
      x(2 downto 0)                => zero,
      y                            => row_value,
      addr                         => addr,
      sblock_number                => open,
      port_select                  => port_select);

  -----------------------------------------------------------------------------
  -- word selecter used for selecting output words from sblock matrix
  -- (readback pipe) 

  word_selecter: word_select
    generic map (
      NUMBER_OF_WORDS => READBACK_WORDS)
    port map (
      reset_select  => restart, 
      select_next   => select_next,
      selected_word => control_rdb_selected_word,
      rst           => rst,
      clk           => clk);

  -----------------------------------------------------------------------------

  cycle_count_to <= unsigned(cycles_to_run);
  cycle_counter: counter
    generic map (
      SIZE => 24)
    port map (
      reset    => restart_run,
      count    => run_count,
      count_to => cycle_count_to,
      zero     => count_zero,
      finished => run_finished,
      value    => open,
      clk      => clk);

  -----------------------------------------------------------------------------
  -- clocked part of FSM

  process (clk, rst)
  begin

    if rst = '0' then
      control_state <= idle;
      control_cfg_access <= '0';
      control_rdb_access <= '0';
      restart <= '1';
      add <= '0';     
      cycles_to_run <= (others => '0');
      first_step <= '0';
    elsif rising_edge (clk) then

      case control_state is

        -- waiting for instructions
        when idle =>
          -- reset all signals, don't activate pipelines
          select_next <= '1';
          restart <= '1';
          control_cfg_access <= '0';
          control_rdb_access <= '0';
--Kaa
          first_step <= '1';
--Kaa
          -- next state
          if dec_start_config = '1' then
            control_state <= config;
          elsif dec_start_readback = '1' then
            control_state <= readback;
          elsif dec_run_matrix = '1' then
            control_state <= run_sbm;
            cycles_to_run <= dec_cycles_to_run;
          else
            control_state <= idle;
          end if;
--Kaa
        -- run sblock matrix a given number of cycles
        when run_sbm =>
          if run_finished = '1' then
            control_state <= write_last;
          end if;
          restart <= '0';
          add <= '1';
          --only if not first
          if first_step = '1' then
            first_step <= '0';          --not first_step
          end if;

        when write_last =>
          control_state <= idle;
          add <= '0';
--Kaa
        -- configure sblockmatrix from BRAM-1
        when config =>
          control_cfg_access <= '1';
          control_cfg_port_select <= port_select(1);

          -- stop when both counters are finished
          if row_counter_finished = '1' and column_counter_finished = '1' then
            control_state <= wait_to_finish;
          else
            control_state <= config;
          end if;

        -- readback data from sblockmatrix to BRAM-1
        when readback =>
          control_rdb_access <= '1';
          restart <= '0';

          -- stop when both counters are finished
          if control_rdb_selected_word(READBACK_WORDS - 1) = '1' then
            control_state <= wait_to_finish;
          else
            control_state <= readback;
          end if;

          --select_next <= not select_next;

        -- wait until pipelines are ready before going to idle
        when wait_to_finish =>
          control_cfg_access <= '0';
          control_rdb_access <= '0';

          if config_delay(0) = '1' or readback1_access = '1' then
            control_state <= wait_to_finish;
          else
            control_state <= idle;
          end if;

        when others =>
          control_state <= idle;
          control_rdb_access <= '0';
          control_cfg_access <= '0';

      end case;

    end if;

  end process;

  -----------------------------------------------------------------------------
  -- comb. part of FSM

  process (dec_start_readback, readback1_access,
           control_state, column_counter_finished, addr, port_select,
           config_delay, dec_start_config, first_step, run_step_mem_address_i)
  begin

    -- default values for all signals
    reset_row_counter <= '0';
    reset_column_counter <= '0';
    count_column <= '0';
    count_row <= '0';
    
    cfg_access <= '0';
    addr_1_conf <= (others => (others => 'Z'));
    
    cfg_enable_read_1b <= (others => '0');

    sbm_pipe_idle <= '0';

    restart_run <= '0';
    run_count <= '0';

--Kaa
    run_step_mem_write_enable <= '0';
    run_step_mem_address <= (others => 'Z');
    
    count_sum_address <= '0';
    reset_sum_address <= '0';

    run_matrix <= '0';
--Kaa
    
    case control_state is

      when idle =>
        sbm_pipe_idle <= '1';

        reset_row_counter <= '1';
        reset_column_counter <= '1';

        restart_run <= '1';
        
      when run_sbm =>
        run_count <= '1';
        run_matrix <= not count_zero;

        if first_step = '0' then
          count_sum_address <= '1'; 
          run_step_mem_write_enable <= '1';
          run_step_mem_address <= run_step_mem_address_i;
        end if;

      when config =>
        -- signals for counters
        count_column      <= '1';
--Kaa
        reset_sum_address <= '1';
--Kaa
        if column_counter_finished = '1' then
          reset_column_counter <= '1';
          count_row <= '1';
        end if;

        -- signals for sbm bram mgr
        cfg_access <= '1';
        addr_1_conf <= (others => addr);
        for i in 0 to SBM_BRAM_MODULES/2 - 1 loop
          if port_select(1) = '0' then
            cfg_enable_read_1b(i) <= '1';
          else
            cfg_enable_read_1b(i+SBM_BRAM_MODULES/2) <= '1';
          end if;
        end loop;

      when readback =>
        null;
--Kaa
      when write_last =>
        run_step_mem_write_enable <= '1';
        run_step_mem_address <= run_step_mem_address_i;
--Kaa        
      when wait_to_finish =>
        null;

      when others =>
        null;

    end case;
        
  end process;

  
  -----------------------------------------------------------------------------
  -- Fetch1
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      fetch1_access <= control_cfg_access;
      fetch1_port_select <= control_cfg_port_select;

    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Fetch2
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      fetch2_access <= fetch1_access;
      fetch2_port_select <= fetch1_port_select;

    end if;    
  end process;

  -----------------------------------------------------------------------------
  -- Convert1
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rst = '0' then
      lut_addr <= (others => (others => 'Z'));
      convert1_ff <= (others => '0');

    elsif rising_edge (clk) then
      if fetch2_access = '1' then
        for i in 0 to LUTCONVS_PER_CYCLE/ENTRIES_PER_WORD - 1 loop
          for j in 0 to ENTRIES_PER_WORD - 1 loop
          -- read from correct BRAM port
          -- lut_addr is sblock type, used as index in LUT conv table
            if fetch2_port_select = '0' then
              lut_addr(i*ENTRIES_PER_WORD+j) <= 
                type_data_read_1(i*2+1)(TYPE_BUS_SIZE - (j * TYPE_SIZE) - 1
                                      downto TYPE_BUS_SIZE - ((j+1) * TYPE_SIZE));

              convert1_ff(i*ENTRIES_PER_WORD+j) <= 
                state_data_read_1(i*2+1)(STATE_BUS_SIZE - j - 1);
            else
              lut_addr(i*ENTRIES_PER_WORD+j) <= 
                type_data_read_1(i*2+5)(TYPE_BUS_SIZE - (j * TYPE_SIZE) - 1
                                      downto TYPE_BUS_SIZE - ((j+1) * TYPE_SIZE));

              convert1_ff(i*ENTRIES_PER_WORD+j) <= 
                state_data_read_1(i*2+5)(STATE_BUS_SIZE - j - 1);
            end if;
          end loop;
        end loop;
      else
        lut_addr <= (others => (others => 'Z'));
      end if;
    end if;

  end process;

  process (rst, clk)
  begin

    if rising_edge (clk) then

      convert1_access <= fetch2_access;

    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Convert2
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rising_edge (clk) then

      convert2_access <= convert1_access;
      convert2_ff <= convert1_ff;

    end if;
  end process;  

  -----------------------------------------------------------------------------
  -- Convert3
  -----------------------------------------------------------------------------

  process (clk, rst)
  begin

    if rising_edge (clk) then

      convert3_access <= convert2_access;
      convert3_lut <= lut_read;
      convert3_ff  <= convert2_ff;

    end if;
  end process;  

  -----------------------------------------------------------------------------
  -- Buffer1-16
  -----------------------------------------------------------------------------

  -- contains two major registers: The "buffer" that gets filled up with
  -- sblockdata from convert3 (32 sblocks)
  --
  -- This buffer is copied to a "config buffer" each 16th cycle, and then
  -- emptied.
  --
  -- The "config buffer" is used for configuring two bit of 32 sblocks in
  -- parallell.  Each sblock-LUT in the config buffer is shifted one bit
  -- each cycle so that the bits to configure with is always in the same
  -- position


  -- counter for selecting location in sblock buffer to store in

  index_count_to <= to_unsigned (SBM_CFG_SIZE/LUTCONVS_PER_CYCLE - 1, SBM_CFG_INDEX_SIZE);
  index_restart <= (not convert3_access) or index_finished;

  index_counter: counter
    generic map (
      SIZE => SBM_CFG_INDEX_SIZE)
    port map (
      reset    => index_restart,
      count    => convert3_access,
      count_to => index_count_to,
      zero     => open,
      finished => index_finished,
      value    => index,
      clk      => clk);

  -----------------------------------------------------------------------------

  -- selects groups of sblocks in matrix to configure

  reset_ws <= not config_delay(0);

  word_selecter_2: word_select
    generic map (
      NUMBER_OF_WORDS => CONFIG_WORDS)
    port map (
      reset_select  => reset_ws, 
      select_next   => next_delay(0),
      selected_word => selected_word,
      rst           => rst,
      clk           => clk);

  -----------------------------------------------------------------------------

  process (rst, clk)
  begin
    for reg_number in 0 to (SBM_CFG_SIZE / LUTCONVS_PER_CYCLE) - 2 loop
      if rst = '0' then
        for i in 0 to LUTCONVS_PER_CYCLE - 1 loop
        lut_cfg_buffer_i((LUTCONVS_PER_CYCLE * reg_number) + i) <= (others => '0');
        ff_cfg_buffer_i((LUTCONVS_PER_CYCLE * reg_number) + i) <= '0';
        end loop;
      elsif rising_edge (clk) then
        -- write to buffer if index counter equals this buffers number
        if index = to_slv (reg_number, SBM_CFG_INDEX_SIZE) then
          for i in 0 to LUTCONVS_PER_CYCLE - 1 loop
            lut_cfg_buffer_i((LUTCONVS_PER_CYCLE * reg_number) + i) <= convert3_lut(i);
            ff_cfg_buffer_i((LUTCONVS_PER_CYCLE * reg_number) + i) <= convert3_ff(i);
          end loop;
        end if;
      end if;
    end loop;
  end process;

  -- the last LUTCONVS_PER_CYCLE sblocks are not registered in buffer, they go straight to
  -- pipeline register (saves one cycle)
  process(lut_cfg_buffer_i,ff_cfg_buffer_i,convert3_lut,convert3_ff)
  begin
    for i in 0 to LUTCONVS_PER_CYCLE - 1 loop
      lut_cfg_buffer_1(SBM_CFG_SIZE - LUTCONVS_PER_CYCLE + i) <= convert3_lut(i);
      ff_cfg_buffer(SBM_CFG_SIZE - LUTCONVS_PER_CYCLE + i) <= convert3_ff(i);
    end loop;
    lut_cfg_buffer_1(SBM_CFG_SIZE - LUTCONVS_PER_CYCLE - 1 downto 0) 
            <= lut_cfg_buffer_i(SBM_CFG_SIZE - LUTCONVS_PER_CYCLE - 1 downto 0);
    ff_cfg_buffer(SBM_CFG_SIZE - LUTCONVS_PER_CYCLE - 1 downto 0)
            <= ff_cfg_buffer_i(SBM_CFG_SIZE - LUTCONVS_PER_CYCLE - 1 downto 0);
  end process;
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin
    if rst = '0' then
      lut_cfg_buffer_2 <= (others => (others => '0'));
      databus_ff_write <= (others => '0');
    elsif rising_edge (clk) then
      -- load config buffer with new values from buffer
      -- (every 16th cycle)
      if index_finished = '1' then
        lut_cfg_buffer_2 <= lut_cfg_buffer_1;
        databus_ff_write <= ff_cfg_buffer;
      else
        -- shift config buffer so that correct config bits are ready
        -- (each cycle, except when loading)
        for i in 0 to SBM_CFG_SIZE - 1 loop
          lut_cfg_buffer_2(i)(0) <= '0';
          lut_cfg_buffer_2(i)(LUT_SIZE - 1 downto 1) <=
            lut_cfg_buffer_2(i)(LUT_SIZE - 2 downto 0);
        end loop;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------

  -- setup databus for configuring sblock matrix with data from config buffer.
  --
  -- These bits are always taken from the same place in the config buffer
  -- because of the config buffer shifting 
  databus_lut : for i in 0 to SBM_CFG_SIZE - 1 generate
    databus_lut_l_write(i) <= lut_cfg_buffer_2(i)(15);
    databus_lut_h_write(i) <= lut_cfg_buffer_2(i)(31);
  end generate;

  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rst = '0' then

      config_enable_lut <= (others => '0');
      config_enable_ff <= (others => '0');
      config_delay <= (others => '0');

    elsif rising_edge (clk) then

      -- shiftregister used to delay select signal for selecting next group of
      -- sblocks to configure 
      --
      -- Delayed because it takes 16 cycles to finish configuring the existing
      -- set of sblocks
      next_delay(14) <= index_finished;
      next_delay(13 downto 0) <= next_delay(14 downto 1);

      -- shiftregister used for delaying config_enable signal for
      -- sblock matrix.
      --
      -- Delayed because it takes 16 cycles for sblock data to be ready for
      -- configiguration
      config_delay(14) <= convert3_access;
      config_delay(13 downto 0) <= config_delay(14 downto 1);

      -- config_enable
      if config_delay(0) = '1' then
        config_enable_lut <= selected_word;
        config_enable_ff <= selected_word;
      else
        config_enable_lut <= (others => '0');
        config_enable_ff <= (others => '0');
      end if;

    end if;
  end process;  

  -----------------------------------------------------------------------------
  -- Config
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Readback1
  -----------------------------------------------------------------------------

  output_select <= control_rdb_selected_word;

  -----------------------------------------------------------------------------

  process (rst, clk)
  begin

    if rst = '0' then

      readback1_access  <= '0';

    elsif rising_edge (clk) then

      readback1_access  <= control_rdb_access;

    end if;    
  end process;

  -----------------------------------------------------------------------------
  -- Readback2
  -----------------------------------------------------------------------------

  -- counter used to generate addresses for BRAM-1

  rd1_restart <= not readback1_access;
  addr_count_to <= to_unsigned (READBACK_WORDS - 1, ADDR_BUS_SIZE - 1);

  address_counter: counter
    generic map (
      SIZE     => ADDR_BUS_SIZE - 1)
    port map (
      reset    => rd1_restart,
      count    => readback1_access,
      count_to => addr_count_to,
      zero     => open,
      finished => open,
      value    => addr_2,
      clk      => clk);

  -----------------------------------------------------------------------------

  process (clk, rst)
  begin
    if rst = '0' then 
      rdb_access <= '0';
      rdb_enable_write_state_1 <= (others => '0');

      state_data_write_1 <= (others => (others => 'Z'));

      addr_1_rdb <= (others => (others => 'Z'));

    elsif rising_edge (clk) then

      -- enable write
      rdb_enable_write_state_1 <= (others => readback1_access and control_rdb_access);
      rdb_access <= readback1_access;
      if readback1_access = '1' then

        for i in 0 to SBM_BRAM_MODULES - 1 loop
        -- set databus with values from sblock matrix
        -- Sblock matrix gives two words of data every 2nd. cycle, one of wich
        -- is selected here. 
            state_data_write_1(i*2) <= databus_read(ENTRIES_PER_WORD * (i*2 + 1 - (i mod 2)) - 1 
                                     downto ENTRIES_PER_WORD * (i*2 - (i mod 2)));
            state_data_write_1(i*2+1) <= databus_read(ENTRIES_PER_WORD * (i*2+2+((i+1) mod 2)) - 1 
                                     downto ENTRIES_PER_WORD * (i*2+1+((i+1) mod 2)));

        -- set addresses
          addr_1_rdb(i*2) <= addr_2 & '0';
          addr_1_rdb(i*2+1) <= addr_2 & '1';
        end loop;

      else

        state_data_write_1 <= (others => (others => 'Z'));

        addr_1_rdb <= (others => (others => 'Z'));

      end if;

    end if;
  end process;  

  -----------------------------------------------------------------------------
  -- Store
  -----------------------------------------------------------------------------
  addr_1 <= addr_1_rdb when rdb_access = '1' and readback1_access = '1'
             else addr_1_conf when cfg_access = '1' 
             else (others => (others => 'Z'));
end sbm_pipe_arch;
