-------------------------------------------------------------------------------
-- Title      : Sblock Matrix BRAM Manager
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sbm_bram_mgr.vhd
-- Author     : Asbjørn Djupdal  <djupdal@harryklein>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/01/13
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Manager for sblock matrix BRAMs
--              Takes care of transparently switching BRAMs 
--              Registers data on both in and out ports to ease timing
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/01/13  2.0      stoevneng Parameterized busses.
-- 2003/02/14  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

entity sbm_bram_mgr is
  
  port (
    -- Signals connected to SBM BRAM 0

    type_data_read_0   : out bram_type_bus_t;
    type_data_write_0  : in bram_type_bus_t;
    state_data_read_0  : out bram_state_bus_t;
    state_data_write_0 : in bram_state_bus_t;
    addr_0             : in bram_addr_t;

    -- Signals connected to SBM BRAM 1

    type_data_read_1   : out bram_type_bus_t;
    type_data_write_1  : in bram_type_bus_t;
    state_data_read_1  : out bram_state_bus_t;
    state_data_write_1 : in bram_state_bus_t;
    addr_1             : in bram_addr_t;

    -- enable signals from dev pipe

    dev_enable_read_0   : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
    dev_enable_read_1b  : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
    dev_enable_write_1a : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);
    
    -- enable signals from lss pipe

    lss_enable_read_0a : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);

    lss_enable_write_type_0b : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);

    lss_enable_write_state_0b : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);

    -- enable signals from sbm pipe; config

    cfg_enable_read_1b : in std_logic_vector(SBM_BRAM_MODULES - 1 downto 0);

    -- enable signals from sbm pipe; readback

    rdb_enable_write_state_1 : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);

    -- Other

    -- selects which BRAM is used as BRAM-0 and BRAM-1
    select_sbm : in std_logic;

    stall : in std_logic;

    rst : in std_logic;
    clk : in std_logic);

end sbm_bram_mgr;

architecture sbm_bram_mgr_arch of sbm_bram_mgr is

  -- SBM BRAM A

  signal type_data_read_a   : bram_type_bus_t;
  signal type_data_write_a  : bram_type_bus_t;
  signal state_data_read_a  : bram_state_bus_t;
  signal state_data_write_a : bram_state_bus_t;
  signal addr_a             : bram_addr_t;

  signal enable_read_a        : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
  signal enable_type_write_a  : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
  signal enable_state_write_a : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);

  signal type_data_a_reg  : bram_type_bus_t;
  
  signal state_data_a_reg : bram_state_bus_t;
  
  -- SBM BRAM B

  signal type_data_read_b   : bram_type_bus_t;
  signal type_data_write_b  : bram_type_bus_t;
  signal state_data_read_b  : bram_state_bus_t;
  signal state_data_write_b : bram_state_bus_t;
  signal addr_b             : bram_addr_t;

  signal enable_read_b        : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
  signal enable_type_write_b  : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
  signal enable_state_write_b : std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);

  signal type_data_b_reg :  bram_type_bus_t;

  signal state_data_b_reg : bram_state_bus_t;

begin  -- sbm_bram_mgr_arch

  process (type_data_a_reg, state_data_a_reg, type_data_b_reg, 
           state_data_b_reg, select_sbm)

  begin

    if select_sbm = '0' then
      -- SBM BRAM 0
      type_data_read_0 <= type_data_a_reg;
      state_data_read_0 <= state_data_a_reg;

      -- SBM BRAM 1
      type_data_read_1 <= type_data_b_reg;
      state_data_read_1 <= state_data_b_reg;

    else
      -- SBM BRAM 0
      type_data_read_0 <= type_data_b_reg;
      state_data_read_0 <= state_data_b_reg;

      -- SBM BRAM 1
      type_data_read_1 <= type_data_a_reg;
      state_data_read_1 <= state_data_a_reg;

    end if;
  end process;

  process (clk, rst)
  begin  -- process
    if rst = '0' then

      -- SBM BRAM A

      type_data_write_a    <= (others => (others => '0'));
      state_data_write_a   <= (others => (others => '0'));
      addr_a               <= (others => (others => '0'));
      enable_read_a        <= (others => '0');
      enable_type_write_a  <= (others => '0');
      enable_state_write_a <= (others => '0');

      -- SBM BRAM B

      type_data_write_b    <= (others => (others => '0'));
      state_data_write_b   <= (others => (others => '0'));
      addr_b               <= (others => (others => '0'));
      enable_read_b        <= (others => '0');
      enable_type_write_b  <= (others => '0');
      enable_state_write_b <= (others => '0');

    elsif rising_edge (clk) then
      if stall = '0' then

        -- SBM BRAM A
        type_data_a_reg  <= type_data_read_a;
        state_data_a_reg <= state_data_read_a;
        
        -- SBM BRAM B
        type_data_b_reg  <= type_data_read_b;
        state_data_b_reg <= state_data_read_b;

        if select_sbm = '0' then
          
          -- SBM BRAM A
          type_data_write_a    <= type_data_write_0;
          state_data_write_a   <= state_data_write_0;
          addr_a               <= addr_0;

          for i in 0 to SBM_BRAM_MODULES - 1 loop
            enable_read_a(i*2)          <= dev_enable_read_0(i*2) or lss_enable_read_0a(i);
            enable_read_a(i*2+1)        <= dev_enable_read_0(i*2+1);
            enable_type_write_a(i*2)    <= '0';
            enable_type_write_a(i*2+1)  <= lss_enable_write_type_0b(i);
            enable_state_write_a(i*2)   <= '0';
            enable_state_write_a(i*2+1) <= lss_enable_write_state_0b(i);
          end loop;
          -- SBM BRAM B
          addr_b               <= addr_1;
          type_data_write_b    <= type_data_write_1;
          state_data_write_b   <= state_data_write_1;

          for i in 0 to SBM_BRAM_MODULES - 1 loop
            enable_read_b(i*2)          <= '0';
            enable_read_b(i*2+1)        <= cfg_enable_read_1b(i) or dev_enable_read_1b(i);
            enable_type_write_b(i*2)    <= dev_enable_write_1a(i);
            enable_type_write_b(i*2+1)  <= '0';
            enable_state_write_b(i*2)   <= dev_enable_write_1a(i) or rdb_enable_write_state_1(i*2);
            enable_state_write_b(i*2+1) <= rdb_enable_write_state_1(i*2+1);
          end loop;

        else
          
          -- SBM BRAM A
          addr_a               <= addr_1;
          type_data_write_a    <= type_data_write_1;
          state_data_write_a   <= state_data_write_1;
          for i in 0 to SBM_BRAM_MODULES - 1 loop
            enable_read_a(i*2)          <= '0';
            enable_read_a(i*2+1)        <= cfg_enable_read_1b(i) or dev_enable_read_1b(i);
            enable_type_write_a(i*2)    <= dev_enable_write_1a(i);
            enable_type_write_a(i*2+1)  <= '0';
            enable_state_write_a(i*2)   <= dev_enable_write_1a(i) or rdb_enable_write_state_1(i*2);
            enable_state_write_a(i*2+1) <= rdb_enable_write_state_1(i*2+1);
          end loop;

          -- SBM BRAM B
          type_data_write_b    <= type_data_write_0;
          state_data_write_b   <= state_data_write_0;
          addr_b               <= addr_0;

          for i in 0 to SBM_BRAM_MODULES - 1 loop
            enable_read_b(i*2)          <= dev_enable_read_0(i*2) or lss_enable_read_0a(i);
            enable_read_b(i*2+1)        <= dev_enable_read_0(i*2+1);
            enable_type_write_b(i*2)    <= '0';
            enable_type_write_b(i*2+1)  <= lss_enable_write_type_0b(i);
            enable_state_write_b(i*2)   <= '0';
            enable_state_write_b(i*2+1) <= lss_enable_write_state_0b(i);
          end loop;

        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------

  sbm_a : sbm_bram
    port map (
      type_data_read     => type_data_read_a,
      state_data_read    => state_data_read_a,
      type_data_write    => type_data_write_a,
      state_data_write   => state_data_write_a,
      addr               => addr_a,
      enable_read        => enable_read_a,
      enable_type_write  => enable_type_write_a,
      enable_state_write => enable_state_write_a,
      stall              => stall,
      clk                => clk,
      rst                => rst);

  sbm_b : sbm_bram
    port map (
      type_data_read     => type_data_read_b,
      state_data_read    => state_data_read_b,
      type_data_write    => type_data_write_b,
      state_data_write   => state_data_write_b,
      addr               => addr_b,
      enable_read        => enable_read_b,
      enable_type_write  => enable_type_write_b,
      enable_state_write => enable_state_write_b,
      stall              => stall,
      clk                => clk,
      rst                => rst);

end sbm_bram_mgr_arch;
