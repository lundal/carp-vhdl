-------------------------------------------------------------------------------
-- Title      : Load, Send and Store Pipeline
-- Project    :
-------------------------------------------------------------------------------
-- File       : lss.vhd
-- Author     : Asbjrn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
--            : Per Thomas Lundal
-- Company    :
-- Last update: 2014/11/21
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Pipeline for reading and modifying BRAM-0 contents and
--              write sum memory and rulestorage to pci
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/21  3.6      lundal    Replaced non-implementable logic
-- 2014/04/09  3.5      stoevneng Updated for 3D
-- 2014/02/20  3.1      stoevneng Updated
-- 2014/01/13  3.0      stoevneng Updated to match the new memory setup
-- 2005/04/06  2.1      aamodt    Added usedrule sending
-- 2005/03/17  2.0      aamodt    Added bit counting
-- 2003/03/27  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;
use work.funct_package.all;

entity lss is

  port (
    -- BRAM control signals
    --b
    type_data_write_0 : out bram_type_bus_t;
    --b
    state_data_write_0 : out bram_state_bus_t;

    addr_0 : out bram_addr_t;

    --a
    type_data_read_0 : in bram_type_bus_t;
    --a
    state_data_read_0 : in bram_state_bus_t;

--Kaa
    sum_data_read        :  in std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    sum_address          : out std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    enable_sum_data_read : out std_logic;

    usedrules_data       :  in std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
    usedrules_read_enable: out std_logic;
    usedrules_read_addr  : out std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);

    rulevector_data      : in std_logic_vector(RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
    read_next_rulevector : out std_logic;
    reset_rulevector_addr: out std_logic;

    fitness_reg_data       :  in std_logic_vector(FITNESS_DATA_BUS_SIZE - 1 downto 0);
    fitness_reg_read_enable: out std_logic;
--Kaa

    lss_enable_write_type_0b : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);

    lss_enable_write_state_0b : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);

    lss_enable_read_0a : out std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);

    -- com40

    send      : out std_logic;
    ack_send  : in  std_logic;
    data_send : out std_logic_vector(63 downto 0);

    -- decode

    dec_read_sblock : in std_logic;

    dec_send_type   : in std_logic;
    dec_send_types  : in std_logic;
    dec_send_state  : in std_logic;
    dec_send_states : in std_logic;

--Kaa
    dec_read_usedrules : in std_logic;

    dec_number_of_readback_values: in std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    dec_send_sums              : in std_logic;
    dec_send_used_rules        : in std_logic;
    dec_send_rulevector        : in std_logic;
    dec_send_fitness           : in std_logic;
--Kaa

    dec_write_type  : in std_logic;
    dec_write_state : in std_logic;
    dec_write_word  : in std_logic;

    dec_address       : in std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
    dec_port_select   : in std_logic_vector(2 downto 0);
    dec_sblock_number : in std_logic_vector(COORD_SIZE_X - 2 downto 0);

    dec_type_data  : in std_logic_vector(TYPE_SIZE - 1 downto 0);
    dec_state_data : in std_logic;
    dec_type_word  : in std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
    dec_state_words : in std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);

    dec_clear_bram : in std_logic;

    -- hazard

    stall           : in  std_logic;
    lss_idle        : out std_logic;
    lss_ld2_sending : out std_logic;
    lss_ack_send_i  : out std_logic;

    -- other

    rst : in std_logic;
    clk : in std_logic);

end lss;

architecture lss_arch of lss is

  signal lss_sending_i    : std_logic;
  signal lss_writing_i    : std_logic;

  -----------------------------------------------------------------------------
  -- Setup

  type lss_state_type is (idle, clear_bram, send_states, send_types,
                          send_sums, send_usedrules,
                          send_vector, wait_to_finish);

  signal lss_state : lss_state_type;

  signal counter_reset    : std_logic;
  signal counter_count    : std_logic;
  signal addr_count_to    : unsigned(COORD_SIZE_Y + COORD_SIZE_Z downto 0);
  signal addr             : std_logic_vector(COORD_SIZE_Y + COORD_SIZE_Z downto 0);
  signal counter_finished : std_logic;

  signal address          : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal read_sblock      : std_logic;
--Kaa
  signal read_usedrules : std_logic;
  signal usedrules_select : std_logic_vector(1 downto 0);
--Kaa

  signal old_type_data  : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal old_state_data : std_logic;

--Kaa
  --Addresscounter for readback
  signal read_count_mem : std_logic;
  signal send_counter_reset    : std_logic;
  signal send_counter_count    : std_logic;
  signal send_counter_count_to : unsigned (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal send_mem_address      : std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal send_counter_finished : std_logic;
--Kaa

  -- pipeline signals

  -- write to BRAM-0
  signal setup_write_type     : std_logic;
  signal setup_write_state    : std_logic;
  signal setup_write_all      : std_logic;
  signal setup_write_word     : std_logic;
  -- send single sblock to PCI
  signal setup_send_type      : std_logic;
  signal setup_send_state     : std_logic;

--Kaa
  signal setup_send_fitness   : std_logic;
  signal setup_send_sums      : std_logic;
  signal setup_buffer_sums    : std_logic;
--Kaa
  -- address of current sblocks (see addr_gen.vhd for details)
  signal setup_address        : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);

  signal setup_port_select    : std_logic_vector(2 downto 0);
  signal setup_sblock_number  : std_logic_vector(COORD_SIZE_X - 2 downto 0);
  -- data to write to BRAM-0
  signal setup_type_data      : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal setup_state_data     : std_logic;
  signal setup_type_word      : std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
  signal setup_state_words    : std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);

  -- signals that this is the last access for this instruction
  -- When finished reaches Send, pipe is assumed to be ready for new
  -- instruction
  signal setup_finished       : std_logic;
  -- signals that Send should buffer this sblock - sblocks gets
  -- buffered when several sblocks gets packed into a word before
  -- sending (sendTypes, sendStates)
  signal setup_buffer_state   : std_logic;
  signal setup_buffer_type    : std_logic;
  -- send buffered sblocks to PCI
  signal setup_send_type_reg  : std_logic;
  signal setup_send_state_reg : std_logic;
--Kaa
  signal setup_send_usedrules  : std_logic;
  signal setup_usedrules_select : std_logic_vector(1 downto 0);
  signal setup_buffer_usedrules: std_logic;
  signal setup_send_vector     : std_logic;
  signal setup_read_next_rulevector  : std_logic;
  signal setup_reset_rulevector_addr : std_logic;
  -- vector is 8 * 32 bit
  signal setup_send_vector_shift : std_logic_vector(3 downto 0);
--Kaa

  -----------------------------------------------------------------------------
  -- Load1

  signal ld1_write_type     : std_logic;
  signal ld1_write_state    : std_logic;
  signal ld1_write_all      : std_logic;
  signal ld1_write_word     : std_logic;
  signal ld1_send_type      : std_logic;
  signal ld1_send_state     : std_logic;
--Kaa
  signal ld1_send_fitness   : std_logic;
  signal ld1_send_sums      : std_logic;
  signal ld1_buffer_sums    : std_logic;
--Kaa
  signal ld1_address        : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal ld1_port_select    : std_logic_vector(2 downto 0);
  signal ld1_sblock_number  : std_logic_vector(COORD_SIZE_X - 2 downto 0);
  signal ld1_type_data      : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal ld1_state_data     : std_logic;
  signal ld1_type_word      : std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
  signal ld1_state_words    : std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);
  signal ld1_finished       : std_logic;
  signal ld1_buffer_state   : std_logic;
  signal ld1_buffer_type    : std_logic;
  signal ld1_send_type_reg  : std_logic;
  signal ld1_send_state_reg : std_logic;
--Kaa
  signal ld1_buffer_usedrules: std_logic;
  signal ld1_send_usedrules  : std_logic;
  signal ld1_usedrules_data  : std_logic_vector(USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  signal ld1_send_vector     : std_logic;
  signal ld1_read_next_rulevector : std_logic;
  signal ld1_send_vector_shift    : std_logic_vector(3 downto 0);
  signal ld1_reset_rulevector_addr: std_logic;
--Kaa

  -----------------------------------------------------------------------------
  -- Load2

  signal ld2_write_type     : std_logic;
  signal ld2_write_state    : std_logic;
  signal ld2_write_all      : std_logic;
  signal ld2_write_word     : std_logic;
  signal ld2_sending        : std_logic;
  signal ld2_send_type      : std_logic;
  signal ld2_send_state     : std_logic;
--Kaa
  signal ld2_send_fitness   : std_logic;
  signal ld2_send_sums      : std_logic;
  signal ld2_buffer_sums    : std_logic;
--Kaa
  signal ld2_address        : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal ld2_port_select    : std_logic_vector(2 downto 0);
  signal ld2_sblock_number  : std_logic_vector(COORD_SIZE_X - 2 downto 0);
  signal ld2_type_data      : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal ld2_state_data     : std_logic;
  signal ld2_type_word      : std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
  signal ld2_state_words    : std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);
  signal ld2_data           : std_logic;
  signal ld2_finished       : std_logic;
  signal ld2_buffer_state   : std_logic;
  signal ld2_buffer_type    : std_logic;
  signal ld2_send_type_reg  : std_logic;
  signal ld2_send_state_reg : std_logic;
--  signal ld2_sblock_number_i : integer;
--Kaa
  signal ld2_buffer_usedrules: std_logic;
  signal ld2_send_usedrules  : std_logic;
  signal ld2_usedrules_data  : std_logic_vector(USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  signal ld2_send_vector     : std_logic;
  signal ld2_read_next_rulevector : std_logic;
  signal ld2_send_vector_shift    : std_logic_vector(3 downto 0);
  signal ld2_reset_rulevector_addr: std_logic;
--Kaa

  -----------------------------------------------------------------------------
  -- Send

  type send_state_type is (idle, sending);
  signal send_ctrl_state : send_state_type;

  signal ack_send_i  : std_logic;
  signal ack_send_ii : std_logic;

  signal insert_result_type  : std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
  signal insert_result_state : std_logic_vector(STATE_BUS_SIZE - 1 downto 0);

  signal extract_result_type  : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal extract_result_state : std_logic;
--Kaa
  signal extract_rulevector   : std_logic_vector(63 downto 0);
--Kaa
  signal type_data_read  : std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
  signal state_data_read : std_logic_vector(STATE_BUS_SIZE - 1 downto 0);
--  signal type_data_read_more  : std_logic_vector(TYPE_BUS_SIZE * 2 - 1 downto 0);
  signal state_data_read_more : std_logic_vector(STATE_BUS_SIZE * 4 - 1 downto 0);

  signal send_i : std_logic;

  signal state_reg     : std_logic_vector(63 downto 0);
  signal type_reg      : std_logic_vector(63 downto 0);
--Kaa
  signal sum_data_reg  : std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
  signal usedrules_reg : std_logic_vector(63 downto 0);
--Kaa

  -- pipeline signals
  signal send_write_type  : std_logic;
  signal send_write_state : std_logic;
  signal send_write_all   : std_logic;
  signal send_write       : std_logic;
  signal send_address     : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal send_port_select : std_logic_vector(2 downto 0);
  signal send_type_data   : std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
  signal send_state_data  : bram_state_bus_half_t;
  signal send_finished    : std_logic;

  signal addr_0_read  : bram_addr_half_t;
  signal addr_0_write : bram_addr_half_t;
  
  constant zero : std_logic_vector(7 downto 0) := (others => '0');

  -----------------------------------------------------------------------------
  -- Store

begin

  lss_ld2_sending <= ld2_sending;
  lss_ack_send_i <= ack_send_i;

  -----------------------------------------------------------------------------
  -- Setup
  -----------------------------------------------------------------------------

  -- counter used to generate addresses when processing the complete sblock
  -- matrix

--  addr_count_to <=
--    to_unsigned ((ROWS * COLUMNS / 8) - 1, COORD_SIZE_X + COORD_SIZE_Y - 3);

  address_counter: counter
    generic map (
      SIZE     => COORD_SIZE_Y + COORD_SIZE_Z + 1)
    port map (
      reset    => counter_reset,
      count    => counter_count,
      count_to => addr_count_to,
      zero     => open,
      finished => counter_finished,
      value    => addr,
      clk      => clk);

--Kaa
  --counter used when sending all sums or rulevectors from BRAM
  send_counter_count_to <= unsigned(dec_number_of_readback_values);

  send_counter: counter
    generic map (
      SIZE => RUN_STEP_ADDR_BUS_SIZE)
    port map (
      reset    => send_counter_reset,
      count    => send_counter_count,
      count_to => send_counter_count_to,
      zero     => open,
      finished => send_counter_finished,
      value    => send_mem_address,
      clk      => clk);
--Kaa

  -----------------------------------------------------------------------------
  -- clocked part of FSM

  process (rst, clk)
  begin

    if rst = '0' then
      lss_state <= idle;
      setup_write_type <= '0';
      setup_write_state <= '0';
      setup_write_all <= '0';
      setup_write_word <= '0';
      setup_send_type <= '0';
      setup_send_state <= '0';
--Kaa
      setup_send_fitness <= '0';
      setup_send_sums <= '0';
      setup_buffer_sums <= '0';
      setup_send_vector <= '0';
--Kaa
      setup_address <= (others => '0');
      setup_port_select <= (others => '0');
      setup_sblock_number <= (others => '0');
      setup_type_data <= (others => '0');
      setup_state_data <= '0';
      setup_finished <= '0';
      setup_buffer_type <= '0';
      setup_buffer_state <= '0';
      setup_send_type_reg <= '0';
      setup_send_state_reg <= '0';
--Kaa
      setup_buffer_usedrules <= '0';
      setup_send_usedrules <= '0';
      setup_send_vector_shift <= "1000";

      setup_usedrules_select <= (others => '0');
--Kaa

    elsif rising_edge (clk) then
      if stall = '0' then

        case lss_state is

          -- wait for instruction
          when idle =>
            if dec_send_types = '1' then
              lss_state <= send_types;

            elsif dec_send_states = '1' then
              lss_state <= send_states;
--Kaa
            elsif dec_send_sums = '1' then
              lss_state <= send_sums;

            elsif dec_send_used_rules = '1' then
              lss_state <= send_usedrules;
              setup_usedrules_select <= usedrules_select;

            elsif dec_send_rulevector = '1' then
              lss_state <= send_vector;

            elsif dec_send_fitness = '1' then
              --one-cycle instruction
              lss_state <= wait_to_finish;

              setup_send_fitness <= dec_send_fitness;
              setup_finished <= dec_send_fitness;
--Kaa
            elsif dec_clear_bram = '1' then
              lss_state <= clear_bram;
              old_type_data <= dec_type_data;
              old_state_data <= dec_state_data;

            elsif dec_read_sblock = '1' then
              -- all one-cycle instructions: pipeline registers are taken
              -- directly from decode stage
              lss_state <= wait_to_finish;

              setup_write_type <= dec_write_type;
              setup_write_state <= dec_write_state;
              setup_write_word <= dec_write_word;
              setup_send_type <= dec_send_type;
              setup_send_state <= dec_send_state;
              setup_address <= dec_address;
              setup_port_select <= dec_port_select;
              setup_sblock_number <= dec_sblock_number;
              setup_type_data <= dec_type_data;
              setup_state_data <= dec_state_data;
              setup_type_word <= dec_type_word;
              setup_state_words <= dec_state_words;
              setup_finished <= dec_read_sblock;
            end if;

          -- set all of BRAM-0 to a given value
          when clear_bram =>
            setup_write_type <= '1';
            setup_write_state <= '1';
            setup_address <= addr(ADDR_BUS_SIZE - 1 downto 0);
            setup_port_select <= (others => '0');--addr(COORD_SIZE_X - 2) & addr(0);
            setup_type_data <= old_type_data;
            setup_state_data <= old_state_data;
            setup_finished <= counter_finished;
            setup_write_all <= '1';
            if counter_finished = '0' then
              lss_state <= clear_bram;
            else
              lss_state <= wait_to_finish;
            end if;

          -- send all states in BRAM-0
          when send_states =>
            if addr(0) = '1' then
              -- send buffered sblocks every other cycle
              setup_send_state_reg <= '1';
              setup_buffer_state <= '0';
            else
              -- all other cycles is used to buffer sblocks
              setup_send_state_reg <= '0';
              setup_buffer_state <= '1';
            end if;

            setup_address <= address;
            setup_port_select <= addr(COORD_SIZE_Y - 1) & "00";
            setup_finished <= counter_finished;

            if counter_finished = '0' then
              lss_state <= send_states;
            else
              lss_state <= wait_to_finish;
            end if;

          -- send all types in BRAM-0
          when send_types =>
            --if addr(0) = '1' then
              -- send buffered sblocks every 2nd cycle
              setup_send_type_reg <= '1';
              setup_buffer_type <= '0';
            --else
              -- buffer sblocks all other cycles
            --  setup_send_type_reg <= '0';
            --  setup_buffer_type <= '1';
            --end if;

            setup_address <= address;
            setup_port_select <= addr(COORD_SIZE_Y+1) & addr(1 downto 0);
            setup_finished <= counter_finished;

            if counter_finished = '0' then
              lss_state <= send_types;
            else
              lss_state <= wait_to_finish;
            end if;
--Kaa
          when send_sums =>
            if send_mem_address(0) = '1' then
              setup_send_sums <=  '1';
              setup_buffer_sums <= '0';
            else
              setup_send_sums <= '0';
              setup_buffer_sums <= '1';
            end if;

            setup_finished  <= send_counter_finished;

            if send_counter_finished = '0' then
              lss_state <= send_sums;
            else
              lss_state <= wait_to_finish;
            end if;

          when send_usedrules =>
--            if addr(0) = '1' then
--              -- send buffered "used rules" every 2nd cycle
              setup_send_usedrules <= '1';
              setup_buffer_usedrules <= '0';
--            else
--              -- buffer "used rules" all other cycles
--              setup_send_usedrules <= '0';
--              setup_buffer_usedrules <= '1';
--            end if;

            setup_finished <= counter_finished;

            if counter_finished = '0' then
              lss_state <= send_usedrules;
            else
              lss_state <= wait_to_finish;
            end if;

          when send_vector =>
            setup_send_vector <= '1';

            setup_finished <= send_counter_finished;
            setup_send_vector_shift <= setup_send_vector_shift(2 downto 0)
                                       & setup_send_vector_shift(3);

            -- using send_counter
            if send_counter_finished = '0' then
              lss_state <= send_vector;
            else
              lss_state <= wait_to_finish;
            end if;

--Kaa
          -- wait until pipe is empty before going to idle
          when wait_to_finish =>
            setup_write_type <= '0';
            setup_write_state <= '0';
            setup_write_all <= '0';
            setup_write_word <= '0';
            setup_send_type <= '0';
            setup_send_state <= '0';
--Kaa
            setup_send_fitness <= '0';
            setup_send_sums <= '0';
            setup_buffer_sums <= '0';
            setup_send_vector <= '0';
--Kaa
            setup_address <= (others => '0');
            setup_port_select <= (others => '0');
            setup_sblock_number <= (others => '0');
            setup_type_data <= (others => '0');
            setup_state_data <= '0';
            setup_finished <= '0';
            setup_buffer_type <= '0';
            setup_buffer_state <= '0';
            setup_send_type_reg <= '0';
            setup_send_state_reg <= '0';
--Kaa
            setup_send_usedrules <= '0';
            setup_buffer_usedrules <= '0';
--Kaa
            if send_finished = '1' then
              lss_state <= idle;
            else
              lss_state <= wait_to_finish;
            end if;

          when others =>
            lss_state <= idle;

        end case;

      end if;
    end if;

  end process;

  -----------------------------------------------------------------------------
  -- comb. part of FSM

  process (lss_state, stall, dec_read_sblock, dec_read_usedrules,
           dec_address, addr, send_mem_address, dec_send_sums,
           setup_send_vector_shift, send_counter_finished)
  begin

    counter_reset <= '0';
    counter_count <= '0';
    addr_count_to <=
      to_unsigned ((ROWS * LAYERS * 2) - 1, COORD_SIZE_Y + COORD_SIZE_Z + 1);
--Kaa
    send_counter_reset <= '0';
    send_counter_count <= '0';

    read_count_mem <= '0';
    enable_sum_data_read <= '0';

    read_usedrules <= '0';
    usedrules_read_enable <= '0';

    setup_reset_rulevector_addr <= '0';
    setup_read_next_rulevector <= '0';
--Kaa

    lss_enable_read_0a <= (others => '0');
    address <= (others => '0');
--    address((COORD_SIZE_X + COORD_SIZE_Y - 5) downto COORD_SIZE_X - 3)
--      <= addr(COORD_SIZE_X + COORD_SIZE_Y - 4 downto COORD_SIZE_X - 2);
--    address(COORD_SIZE_X - 4 downto 0)
--      <= addr(COORD_SIZE_X - 4 downto 0);
    read_sblock <= '0';

    lss_idle <= '0';

    case lss_state is

      when idle =>
        counter_reset <= not stall;
--Kaa
        send_counter_reset <= not stall;
        read_count_mem <= dec_send_sums;
--Kaa
        lss_enable_read_0a <= (others => dec_read_sblock);
        address <= dec_address;
        read_sblock <= dec_read_sblock;
        lss_idle <= '1';
--Kaa
        usedrules_read_enable <= dec_read_usedrules;
        read_usedrules <= dec_read_usedrules;
--Kaa

      when clear_bram =>
        addr_count_to <=
          to_unsigned ((ROWS * LAYERS / 4) - 1, COORD_SIZE_Y + COORD_SIZE_Z + 1);
        address <= addr(ADDR_BUS_SIZE - 1 downto 0);
        read_sblock <= '1';
        lss_enable_read_0a <= (others => '1');
        counter_count <= not stall;

      when send_states =>
        addr_count_to <=
          to_unsigned ((ROWS * LAYERS / 2) - 1, COORD_SIZE_Y + COORD_SIZE_Z + 1);
        address(COORD_SIZE_Z + COORD_SIZE_Y - 3 downto 0)
          <= addr(COORD_SIZE_Z - 2 + COORD_SIZE_Y downto COORD_SIZE_Y)
           & addr(COORD_SIZE_Y - 2 downto 0);
        read_sblock <= '1';
        lss_enable_read_0a <= (others => '1');
        counter_count <= not stall;

      when send_types =>
        addr_count_to <=
          to_unsigned ((ROWS * LAYERS * 2) - 1, COORD_SIZE_Y + COORD_SIZE_Z + 1);
        address <= addr(ADDR_BUS_SIZE + 2 downto COORD_SIZE_Y + 2) & addr(COORD_SIZE_Y downto 2);
        read_sblock <= '1';
        lss_enable_read_0a <= (others => '1');
        counter_count <= not stall;
--Kaa
      when send_sums =>
        read_count_mem <= '1';
        enable_sum_data_read <= '1';
        send_counter_count <=  not stall;

      when send_usedrules =>
        read_usedrules <= '1';
        usedrules_read_enable <= '1';
        counter_count <= not stall;

      when send_vector =>
        -- testing on bit 5 because it give right functionality
        -- (tested with simulation)
        if setup_send_vector_shift(2) = '1' then
          setup_read_next_rulevector <= '1';
          send_counter_count <= not stall;
        else
          setup_read_next_rulevector <= '0';
          send_counter_count <= '0';
        end if;

        if send_counter_finished = '1' then
          setup_reset_rulevector_addr <= '1';
        else
          setup_reset_rulevector_addr <= '0';
        end if;
--Kaa
      when wait_to_finish =>
        null;

      when others =>
        null;

    end case;

  end process;

  -----------------------------------------------------------------------------
  --
  process(read_count_mem, send_mem_address)
  begin
    if read_count_mem = '1' then
      sum_address <= send_mem_address;
    else
      sum_address <= (others => 'Z');
    end if;
  end process;

  -----------------------------------------------------------------------------
  --tristate buffer for address
  process (read_sblock, address)
  begin
    if read_sblock = '1' then
      addr_0_read <= (others => address);
    else
      addr_0_read <= (others => (others => 'Z'));
    end if;
  end process;

  process(read_usedrules, addr)
  begin
    if read_usedrules = '1' then
      usedrules_read_addr <= padded_array(addr(COORD_SIZE_Y + COORD_SIZE_Z downto 2),
                                          COORD_SIZE_Y + COORD_SIZE_Z - 1, -- input width
                                          USEDRULES_ADDR_BUS_SIZE);        -- output width
      usedrules_select <= addr(1 downto 0);
    else
      usedrules_read_addr <= (others => 'Z');
      usedrules_select <= (others => 'Z');
    end if;
  end process;

  --setup fifo-reg with correct output data
  fitness_reg_read_enable <= setup_send_fitness;

  -----------------------------------------------------------------------------
  -- Load1
  -----------------------------------------------------------------------------

  process (clk)
  begin
    if rising_edge (clk) then
      if stall = '0' then
        ld1_write_type <= setup_write_type;
        ld1_write_state <= setup_write_state;
        ld1_write_all <= setup_write_all;
        ld1_write_word <= setup_write_word;
        ld1_send_type <= setup_send_type;
        ld1_send_state <= setup_send_state;
--Kaa
        ld1_send_fitness <= setup_send_fitness;
        ld1_send_sums <=  setup_send_sums;
        ld1_buffer_sums <= setup_buffer_sums;
--Kaa
        ld1_address <= setup_address;
        ld1_port_select <= setup_port_select;
        ld1_sblock_number <= setup_sblock_number;
        ld1_type_data <= setup_type_data;
        ld1_state_data <= setup_state_data;
        ld1_type_word <= setup_type_word;
        ld1_state_words <= setup_state_words;
        ld1_finished <= setup_finished;
        ld1_buffer_type <= setup_buffer_type;
        ld1_buffer_state <= setup_buffer_state;
        ld1_send_type_reg <= setup_send_type_reg;
        ld1_send_state_reg <= setup_send_state_reg;
--Kaa
        ld1_buffer_usedrules <= setup_buffer_usedrules;
        ld1_send_usedrules <= setup_send_usedrules;
        ld1_usedrules_data <= usedrules_data;
        ld1_send_vector <= setup_send_vector;
        ld1_read_next_rulevector <= setup_read_next_rulevector;
        ld1_send_vector_shift <= setup_send_vector_shift;
        ld1_reset_rulevector_addr <= setup_reset_rulevector_addr;
--Kaa
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Load2
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin
    if rst = '0' then
      ld2_sending <= '0';
      ld2_sblock_number <= (others => '0');
    elsif rising_edge (clk) then
      if stall = '0' then
        ld2_write_type <= ld1_write_type;
        ld2_write_state <= ld1_write_state;
        ld2_write_all <= ld1_write_all;
        ld2_write_word <= ld1_write_word;
        ld2_sending <= ld1_send_type or ld1_send_state or
                       ld1_send_type_reg or ld1_send_state_reg
--Kaa
                       or ld1_send_sums or ld1_send_usedrules
                       or ld1_send_vector or ld1_send_fitness;
--Kaa
        ld2_send_type <= ld1_send_type;
        ld2_send_state <= ld1_send_state;
--Kaa
        ld2_send_fitness <= ld1_send_fitness;
        ld2_send_sums <= ld1_send_sums;
        ld2_buffer_sums <= ld1_buffer_sums;
--Kaa
        ld2_address <= ld1_address;
        ld2_port_select <= ld1_port_select;
        ld2_sblock_number <= ld1_sblock_number;
        ld2_type_data <= ld1_type_data;
        ld2_state_data <= ld1_state_data;
        ld2_type_word <= ld1_type_word;
        ld2_state_words <= ld1_state_words;
        ld2_finished <= ld1_finished;
        ld2_buffer_type <= ld1_buffer_type;
        ld2_buffer_state <= ld1_buffer_state;
        ld2_send_type_reg <= ld1_send_type_reg;
        ld2_send_state_reg <= ld1_send_state_reg;
--Kaa
        ld2_buffer_usedrules <= ld1_buffer_usedrules;
        ld2_send_usedrules <= ld1_send_usedrules;
        ld2_usedrules_data <= ld1_usedrules_data;
        ld2_send_vector <= ld1_send_vector;
        ld2_read_next_rulevector <= ld1_read_next_rulevector;
        ld2_send_vector_shift <= ld1_send_vector_shift;
        ld2_reset_rulevector_addr <= ld1_reset_rulevector_addr;
--Kaa
      end if;
    end if;
  end process;

  -- clearing rulevector address before sending and after finished sending
  reset_rulevector_addr <= ld2_reset_rulevector_addr or dec_send_rulevector;
  read_next_rulevector <= ld2_read_next_rulevector;

  -----------------------------------------------------------------------------
  -- Send
  -----------------------------------------------------------------------------

  -- get type and state data from correct BRAM-port
  process (ld2_port_select, type_data_read_0,
           state_data_read_0)
  begin
    type_data_read  <= type_data_read_0(to_integer(unsigned(ld2_port_select)) * 2);
    state_data_read <= state_data_read_0(to_integer(unsigned(ld2_port_select)) * 2);
    for i in 0 to 3 loop
      --type_data_read_more(TYPE_BUS_SIZE*(i+1) - 1 downto TYPE_BUS_SIZE * i) <= type_data_read_0(to_integer(unsigned(ld2_port_select(2 downto 1))) * 4 + (1-i)*2);
      state_data_read_more(STATE_BUS_SIZE*(i+1) - 1 downto STATE_BUS_SIZE * i) <= state_data_read_0(to_integer(unsigned(ld2_port_select(2 downto 2))) * 8 + (3-i)*2);
    end loop;
  end process;

  -----------------------------------------------------------------------------

  -- extract an sblock from databus after reading from BRAM
  --
  -- databus from BRAM is two sblocks wide; this mux selects if low or high
  -- word is the one to use

  --ld2_sblock_number_i <= (3 - to_integer(unsigned(ld2_sblock_number))); Fails for some reason
  process (ld2_sblock_number, type_data_read, state_data_read)
  begin
    extract_result_type <= type_data_read(((ENTRIES_PER_WORD-1 - to_integer(unsigned(ld2_sblock_number))) + 1) * TYPE_SIZE - 1
                            downto (ENTRIES_PER_WORD-1 - to_integer(unsigned(ld2_sblock_number))) * TYPE_SIZE);
    extract_result_state <= state_data_Read((ENTRIES_PER_WORD-1 - to_integer(unsigned(ld2_sblock_number))));
  end process;

  -- merge old BRAM contents with new sblock data before writing to BRAM
  
  combine_type: entity work.combiner
  generic map (
    data_long_width  => TYPE_BUS_SIZE,
    data_short_width => TYPE_SIZE,
    offset_width     => COORD_SIZE_X - 1,
    offset_unit      => TYPE_SIZE,
    offset_from_left => true
  )
  port map (
    data_long_in  => type_data_read,
    data_short_in => ld2_type_data,
    data_out      => insert_result_type,
    offset        => ld2_sblock_number
  );

  combine_state: entity work.combiner
  generic map (
    data_long_width  => STATE_BUS_SIZE,
    data_short_width => STATE_SIZE,
    offset_width     => COORD_SIZE_X - 1,
    offset_unit      => STATE_SIZE,
    offset_from_left => true
  )
  port map (
    data_long_in  => state_data_read,
    data_short_in => (0 => ld2_state_data),
    data_out      => insert_result_state,
    offset        => ld2_sblock_number
  );

  -----------------------------------------------------------------------------
  -- extract 64 bit from 256 bit vector

  process (ld2_send_vector_shift, rulevector_data)
  begin  -- process
    case ld2_send_vector_shift is
      when "0001" =>
        extract_rulevector <= rulevector_data(63 downto 0);
      when "0010" =>
        extract_rulevector <= rulevector_data(127 downto 64);
      when "0100" =>
        extract_rulevector <= rulevector_data(191 downto 128);
      when "1000" =>
        extract_rulevector <= rulevector_data(RULEVECTOR_DATA_BUS_SIZE - 1 downto 192);
      when others =>
        extract_rulevector <= (others => '0');
    end case;
  end process;
  -----------------------------------------------------------------------------


  -- synchronize acknowledge signal from COM40 to local clock
  process (rst, clk)
  begin
    if rst = '0' then
      ack_send_ii <= '0';
      ack_send_i <= '0';
    elsif rising_edge (clk) then
      ack_send_ii <= ack_send;
      ack_send_i <= ack_send_ii;
    end if;
  end process;

  -----------------------------------------------------------------------------

  -- setup data_send signal, i.e determine which data to send
  -- depending on instruction
  process (rst, clk)
  begin
    if rst = '0' then
      data_send <= (others => '0');
    elsif rising_edge (clk) then
      if ld2_send_type = '1' then
        data_send(31 downto TYPE_SIZE) <= (others => '0');
        data_send(TYPE_SIZE - 1 downto 0) <= extract_result_type;
      elsif ld2_send_state = '1' then
        data_send(31 downto 1) <= (others => '0');
        data_send(0) <= extract_result_state;
--Kaa
      elsif ld2_send_fitness = '1' then
        data_send(31 downto 0) <= fitness_reg_data;

      elsif ld2_send_sums = '1' then
        data_send(RUN_STEP_DATA_BUS_SIZE + 15 downto 16) <= sum_data_read;
        data_send(RUN_STEP_DATA_BUS_SIZE - 1 downto  0) <= sum_data_reg;
--Kaa
      elsif ld2_send_type_reg = '1' then
        for i in 0 to ENTRIES_PER_WORD - 1 loop
          data_send(8 * (i+1) - 1 downto 8 * i) <= 
            zero(8 - TYPE_SIZE - 1 downto 0) & 
            type_data_read(TYPE_SIZE * (i+1) - 1 downto TYPE_SIZE * i);
        end loop;
      elsif ld2_send_state_reg = '1' then
        data_send(STATE_BUS_SIZE * 4 - 1 downto 0) <= state_data_read_more;
        data_send(63 downto STATE_BUS_SIZE * 4) <=
          state_reg(63 - STATE_BUS_SIZE * 4 downto 0);
--Kaa
      elsif ld2_send_usedrules = '1' then
        data_send(64 - 1 downto 0) 
          <= usedrules_data((to_integer(unsigned(setup_usedrules_select)) + 1)*64 - 1
                             downto to_integer(unsigned(setup_usedrules_select))*64 );
--        data_send(31 downto 16) <=
--          usedrules_reg(15 downto 0);

      elsif ld2_send_vector = '1' then
        data_send(63 downto 0) <= extract_rulevector;

      end if;
--Kaa
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- clocked part of FSM

  process (rst, clk)
  begin
    if rst = '0' then
      send_ctrl_state <= idle;
    elsif rising_edge (clk) then
      case send_ctrl_state is

        -- wait for send instruction
        when idle =>

          -- start send, if COM40 is ready
          if ack_send_i = '0' and ld2_sending = '1' then
            send_ctrl_state <= sending;
          else
            send_ctrl_state <= idle;
          end if;

          -- send finished must be set also for instructions not send
          if ld2_sending = '0' then
            send_finished <= ld2_finished;
          else
            send_finished <= '0';
          end if;

        -- send to COM40
        when sending =>
          if ack_send_i = '1' then
            send_ctrl_state <= idle;
            send_finished <= ld2_finished;
          else
            send_ctrl_state <= sending;
          end if;

        when others =>

      end case;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- comb. part of FSM

  process (send_ctrl_state, ack_send_i, ld2_send_type, ld2_send_state,
           ld2_send_sums, ld2_send_usedrules, ld2_send_vector)
  begin
    send_i <= '0';

    case send_ctrl_state is

      when idle =>
        null;

      when sending =>
        send_i <= '1';

      when others =>
        null;

    end case;
  end process;

  send <= send_i;

  -----------------------------------------------------------------------------

  -- fill sblock buffers
  process (rst, clk)
  begin
    if rising_edge (clk) then
      if stall = '0' then
        -- insert sblock into state buffer
        if ld2_buffer_state = '1' then
          state_reg(STATE_BUS_SIZE*4 - 1 downto 0) <= state_data_read_more;
          state_reg(63 downto STATE_BUS_SIZE*4) <=
            state_reg(63 - STATE_BUS_SIZE*4 downto 0);
        end if;

        -- insert sblock into type buffer
        --if ld2_buffer_type = '1' then
        --  type_reg(TYPE_BUS_SIZE - 1 downto 0) <= type_data_read;
        --  type_reg(63 downto TYPE_BUS_SIZE) <=
        --    type_reg(63 - TYPE_BUS_SIZE downto 0);
        --end if;
        -- insert sblock into type buffer
--Kaa
        if ld2_buffer_sums = '1' then
          sum_data_reg <= sum_data_read;
        end if;

        if ld2_buffer_usedrules = '1' then
--          usedrules_reg(USEDRULES_DATA_BUS_SIZE - 1 downto 0) <= usedrules_data;
--          usedrules_reg(31 downto USEDRULES_DATA_BUS_SIZE) <=
--            usedrules_reg(USEDRULES_DATA_BUS_SIZE - 1 downto 0);
        end if;
--Kaa
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------

  -- pipeline registers
  process (rst, clk)
  begin
    if rst = '0' then
      send_address <= (others => 'Z');
      send_write <= '0';
      send_state_data <= (others => (others => 'Z'));
      send_type_data <= (others => 'Z');
      send_write_type <= '0';
      send_write_state <= '0';
      send_write_all <= '0';
      send_port_select <= (others => '0');
    elsif rising_edge (clk) then
      if stall = '0' then
        -- pipeline registers for store instructions
        send_write_type <= ld2_write_type;
        send_write_state <= ld2_write_state;
        send_write_all <= ld2_write_all;
        send_address <= ld2_address;
        send_port_select <= ld2_port_select;
        send_write <= ld2_write_type or ld2_write_state;

        if ld2_write_type = '1' and ld2_write_state = '1' then
          -- store two new sblocks
          for i in 0 to 3 loop
            send_type_data(TYPE_SIZE * (i+1) - 1 downto TYPE_SIZE * i) <= ld2_type_data;
            send_state_data <= (others => (others => ld2_state_data));
          end loop;
        elsif ld2_write_word = '1' then
          if ld2_write_state = '1' then
            send_write_all <= '1';
          end if;
          send_type_data <= ld2_type_word;
          for i in SBM_BRAM_MODULES - 1 downto 0 loop
            send_state_data(i) <= ld2_state_words(STATE_BUS_SIZE * (i+1) - 1 downto STATE_BUS_SIZE * i);
          end loop;
        else
          -- store merged sblocks (one new, one old)
          send_type_data <= insert_result_type;
          send_state_data <= (others => insert_result_state);
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Store
  -----------------------------------------------------------------------------

  writebram_b: for i in 0 to SBM_BRAM_MODULES - 1 generate
    addr_0_write(i) <= send_address when send_write = '1' else (others => 'Z');
    type_data_write_0(i*2) <= (others => 'Z');
    type_data_write_0(i*2+1) <= send_type_data when send_write_type = '1'
                                else (others => 'Z');
    state_data_write_0(i*2) <= (others => 'Z');
    state_data_write_0(i*2+1) <= send_state_data(i) when send_write_state = '1'
                                 else (others => 'Z');

    lss_enable_write_type_0b(i) <= send_write_type when send_write_all = '1' or to_integer(unsigned(send_port_select)) = i
                                   else '0';
    lss_enable_write_state_0b(i) <= send_write_state when send_write_all = '1' or to_integer(unsigned(send_port_select)) = i
                                    else '0';
  end generate writebram_b;

  addr0: for i in 0 to SBM_BRAM_MODULES - 1 generate
    addr_0(i*2) <= addr_0_read(i);
    addr_0(i*2+1) <= addr_0_write(i);
  end generate addr0;
end lss_arch;
