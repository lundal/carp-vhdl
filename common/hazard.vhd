-------------------------------------------------------------------------------
-- Title      : Hazard Detection Unit
-- Project    : 
-------------------------------------------------------------------------------
-- File       : hazard.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2005/05/24
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Checks different conditions in the pipelines, stalls pipeline
--              stages if needed to ensure correct execution
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/05/08  3.0      stoevneng updated to include dft
-- 2005/05/24  2.0      kjetila
-- 2003/04/10  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

entity hazard is

  port (
    -- decode should not issue an instruction to any pipe this cycle

    dont_issue_dec : out std_logic;

    -- outgoing stall signals

    stall_lss          : out std_logic;
    stall_dec          : out std_logic;
    stall_fetch        : out std_logic;
    stall_sbm_bram_mgr : out std_logic;
--Kaa
    stall_usedrules_mem : out std_logic;
    stall_run_step_mem  : out std_logic;
    stall_rulevector_mem: out std_logic;
    stall_fitness       : out std_logic;
--Kaa
    -- incoming signals from fetch

    fetch_valid : in std_logic;

    -- incoming signals from decode

    dec_lss_access      : in std_logic;
    dec_sbm_pipe_access : in std_logic;
    dec_start_devstep   : in std_logic;
--Kaa
    dec_start_fitness   : in std_logic;
--Kaa
    dec_start_dft : in std_logic;
    -- incoming signals from lss pipe

    lss_idle        : in std_logic;
    lss_ld2_sending : in std_logic;
    lss_ack_send_i  : in std_logic;
    send            : in std_logic;

    -- incoming signals from dev pipe

    dev_idle : in std_logic;

    -- incoming signals from sbm pipe

    sbm_pipe_idle : in std_logic;

--Kaa
    -- incoming signals from fitness pipe
    fitness_pipe_idle: in std_logic;
--Kaa
    -- incoming signals from dft
    dft_idle      : in std_logic;
    -- other

    rst : in std_logic;
    clk : in std_logic);

end hazard;

architecture hazard_arch_simple of hazard is

  signal stall_dec_i : std_logic;
  signal stall_lss_i : std_logic;
--Kaa
  signal stall_fitness_i : std_logic;
--Kaa
  signal dont_issue_i : std_logic;

  signal dev_busy      : std_logic;
  signal sbm_pipe_busy : std_logic;
  signal lss_busy      : std_logic;
--Kaa
  signal fitness_busy  : std_logic;
--Kaa
  signal dft_busy      : std_logic;
begin

  dev_busy      <= dec_start_devstep or not dev_idle;
  sbm_pipe_busy <= dec_sbm_pipe_access or not sbm_pipe_idle;
  lss_busy      <= dec_lss_access or not lss_idle;
--Kaa
  fitness_busy  <= dec_start_fitness or not fitness_pipe_idle;
--Kaa
  dft_busy      <= dec_start_dft or not dft_idle;
  -----------------------------------------------------------------------------

  dont_issue_i <= dev_busy or sbm_pipe_busy or lss_busy
--Kaa
                 or dft_busy or fitness_busy;
--Kaa
  dont_issue_dec <= dont_issue_i;

  -----------------------------------------------------------------------------

  stall_lss_i <= (not send and lss_ld2_sending) or
                 (send and not lss_ack_send_i);
  stall_lss <= stall_lss_i;

  -----------------------------------------------------------------------------

  stall_fetch <= (fetch_valid and dont_issue_i) or stall_dec_i;

  -----------------------------------------------------------------------------

  stall_dec_i <= stall_lss_i and dec_lss_access;
  stall_dec <= stall_dec_i;

  -----------------------------------------------------------------------------

  stall_fitness_i <= '0';               -- when should fitness pipe be stalled?
  stall_fitness <= stall_fitness_i;
  
  -----------------------------------------------------------------------------
  
  stall_sbm_bram_mgr <= stall_lss_i;
--Kaa
  stall_usedrules_mem <= stall_lss_i;
  stall_run_step_mem  <= stall_lss_i;
  stall_rulevector_mem<= stall_lss_i;
--Kaa

end hazard_arch_simple;

