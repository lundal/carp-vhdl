-------------------------------------------------------------------------------
-- Title      : PCIe Wrapper
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : pcie_wrapper.vhd
-- Author     : Per Thomas Lundal
-- Company    : NTNU
-- Last update: 2014/11/07
-- Platform   : Spartan-6 LX45T
-------------------------------------------------------------------------------
-- Description: A wrapper for the Spartan-6 PCIe integrated endpoint block,
--              configured for the SP605 development board.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/07  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.VCOMPONENTS.all;

entity pcie_wrapper is
  port (
    -- User Interface
    -- General
    clock     : out std_logic;
    reset     : out std_logic;
    link_up   : out std_logic;
    device_id : out std_logic_vector(15 downto 0);

    -- Tx
    tx_ready  : out std_logic;
    tx_valid  : in  std_logic;
    tx_last   : in  std_logic;
    tx_data   : in  std_logic_vector(31 downto 0);
    tx_user   : in  std_logic_vector(3 downto 0);

    -- Rx
    rx_ready  : in  std_logic;
    rx_valid  : out std_logic;
    rx_last   : out std_logic;
    rx_data   : out std_logic_vector(31 downto 0);
    rx_user   : out std_logic_vector(21 downto 0);

    -- System interface
    -- PCIe
    pcie_tx_p : out std_logic;
    pcie_tx_n : out std_logic;
    pcie_rx_p : in  std_logic;
    pcie_rx_n : in  std_logic;

    -- System
    clock_p   : in  std_logic;
    clock_n   : in  std_logic;
    reset_n   : in  std_logic
  );
end pcie_wrapper;

architecture rtl of pcie_wrapper is

  ---------------------------------------------------------
  -- Component declarations
  ---------------------------------------------------------

  component sp605_pcie is
    generic (
      TL_TX_RAM_RADDR_LATENCY           : integer    := 0;
      TL_TX_RAM_RDATA_LATENCY           : integer    := 2;
      TL_RX_RAM_RADDR_LATENCY           : integer    := 0;
      TL_RX_RAM_RDATA_LATENCY           : integer    := 2;
      TL_RX_RAM_WRITE_LATENCY           : integer    := 0;
      VC0_TX_LASTPACKET                 : integer    := 14;
      VC0_RX_RAM_LIMIT                  : bit_vector := x"7FF";
      VC0_TOTAL_CREDITS_PH              : integer    := 32;
      VC0_TOTAL_CREDITS_PD              : integer    := 211;
      VC0_TOTAL_CREDITS_NPH             : integer    := 8;
      VC0_TOTAL_CREDITS_CH              : integer    := 40;
      VC0_TOTAL_CREDITS_CD              : integer    := 211;
      VC0_CPL_INFINITE                  : boolean    := TRUE;
      BAR0                              : bit_vector := x"FFFFF000";
      BAR1                              : bit_vector := x"FFFFF000";
      BAR2                              : bit_vector := x"00000000";
      BAR3                              : bit_vector := x"00000000";
      BAR4                              : bit_vector := x"00000000";
      BAR5                              : bit_vector := x"00000000";
      EXPANSION_ROM                     : bit_vector := "0000000000000000000000";
      DISABLE_BAR_FILTERING             : boolean    := FALSE;
      DISABLE_ID_CHECK                  : boolean    := FALSE;
      TL_TFC_DISABLE                    : boolean    := FALSE;
      TL_TX_CHECKS_DISABLE              : boolean    := FALSE;
      USR_CFG                           : boolean    := FALSE;
      USR_EXT_CFG                       : boolean    := FALSE;
      DEV_CAP_MAX_PAYLOAD_SUPPORTED     : integer    := 2;
      CLASS_CODE                        : bit_vector := x"0B4000";
      CARDBUS_CIS_POINTER               : bit_vector := x"00000000";
      PCIE_CAP_CAPABILITY_VERSION       : bit_vector := x"1";
      PCIE_CAP_DEVICE_PORT_TYPE         : bit_vector := x"0";
      PCIE_CAP_SLOT_IMPLEMENTED         : boolean    := FALSE;
      PCIE_CAP_INT_MSG_NUM              : bit_vector := "00000";
      DEV_CAP_PHANTOM_FUNCTIONS_SUPPORT : integer    := 0;
      DEV_CAP_EXT_TAG_SUPPORTED         : boolean    := FALSE;
      DEV_CAP_ENDPOINT_L0S_LATENCY      : integer    := 7;
      DEV_CAP_ENDPOINT_L1_LATENCY       : integer    := 7;
      SLOT_CAP_ATT_BUTTON_PRESENT       : boolean    := FALSE;
      SLOT_CAP_ATT_INDICATOR_PRESENT    : boolean    := FALSE;
      SLOT_CAP_POWER_INDICATOR_PRESENT  : boolean    := FALSE;
      DEV_CAP_ROLE_BASED_ERROR          : boolean    := TRUE;
      LINK_CAP_ASPM_SUPPORT             : integer    := 1;
      LINK_CAP_L0S_EXIT_LATENCY         : integer    := 7;
      LINK_CAP_L1_EXIT_LATENCY          : integer    := 7;
      LL_ACK_TIMEOUT                    : bit_vector := x"00B7";
      LL_ACK_TIMEOUT_EN                 : boolean    := FALSE;
      LL_REPLAY_TIMEOUT                 : bit_vector := x"00FF";
      LL_REPLAY_TIMEOUT_EN              : boolean    := TRUE;
      MSI_CAP_MULTIMSGCAP               : integer    := 0;
      MSI_CAP_MULTIMSG_EXTENSION        : integer    := 0;
      LINK_STATUS_SLOT_CLOCK_CONFIG     : boolean    := FALSE;
      PLM_AUTO_CONFIG                   : boolean    := FALSE;
      FAST_TRAIN                        : boolean    := FALSE;
      ENABLE_RX_TD_ECRC_TRIM            : boolean    := TRUE;
      DISABLE_SCRAMBLING                : boolean    := FALSE;
      PM_CAP_VERSION                    : integer    := 3;
      PM_CAP_PME_CLOCK                  : boolean    := FALSE;
      PM_CAP_DSI                        : boolean    := FALSE;
      PM_CAP_AUXCURRENT                 : integer    := 0;
      PM_CAP_D1SUPPORT                  : boolean    := TRUE;
      PM_CAP_D2SUPPORT                  : boolean    := TRUE;
      PM_CAP_PMESUPPORT                 : bit_vector := x"0F";
      PM_DATA0                          : bit_vector := x"00";
      PM_DATA_SCALE0                    : bit_vector := x"0";
      PM_DATA1                          : bit_vector := x"00";
      PM_DATA_SCALE1                    : bit_vector := x"0";
      PM_DATA2                          : bit_vector := x"00";
      PM_DATA_SCALE2                    : bit_vector := x"0";
      PM_DATA3                          : bit_vector := x"00";
      PM_DATA_SCALE3                    : bit_vector := x"0";
      PM_DATA4                          : bit_vector := x"00";
      PM_DATA_SCALE4                    : bit_vector := x"0";
      PM_DATA5                          : bit_vector := x"00";
      PM_DATA_SCALE5                    : bit_vector := x"0";
      PM_DATA6                          : bit_vector := x"00";
      PM_DATA_SCALE6                    : bit_vector := x"0";
      PM_DATA7                          : bit_vector := x"00";
      PM_DATA_SCALE7                    : bit_vector := x"0";
      PCIE_GENERIC                      : bit_vector := "000000101111";
      GTP_SEL                           : integer    := 0;
      CFG_VEN_ID                        : std_logic_vector(15 downto 0) := x"DACA";
      CFG_DEV_ID                        : std_logic_vector(15 downto 0) := x"DACA";
      CFG_REV_ID                        : std_logic_vector(7 downto 0)  := x"00";
      CFG_SUBSYS_VEN_ID                 : std_logic_vector(15 downto 0) := x"10EE";
      CFG_SUBSYS_ID                     : std_logic_vector(15 downto 0) := x"0007";
      REF_CLK_FREQ                      : integer    := 1
    );
    port (
      -- PCI Express Fabric Interface
      pci_exp_txp             : out std_logic;
      pci_exp_txn             : out std_logic;
      pci_exp_rxp             : in  std_logic;
      pci_exp_rxn             : in  std_logic;

      user_lnk_up             : out std_logic;
      user_clk_out            : out std_logic;
      user_reset_out          : out std_logic;

      -- Tx
      s_axis_tx_tdata         : in  std_logic_vector(31 downto 0);
      s_axis_tx_tlast         : in  std_logic;
      s_axis_tx_tvalid        : in  std_logic;
      s_axis_tx_tready        : out std_logic;
      s_axis_tx_tkeep         : in  std_logic_vector(3 downto 0);
      s_axis_tx_tuser         : in  std_logic_vector(3 downto 0);
      tx_err_drop             : out std_logic;
      tx_buf_av               : out std_logic_vector(5 downto 0);
      tx_cfg_req              : out std_logic;
      tx_cfg_gnt              : in  std_logic;

      -- Rx
      m_axis_rx_tdata         : out std_logic_vector(31 downto 0);
      m_axis_rx_tlast         : out std_logic;
      m_axis_rx_tvalid        : out std_logic;
      m_axis_rx_tkeep         : out std_logic_vector(3 downto 0);
      m_axis_rx_tready        : in  std_logic;
      m_axis_rx_tuser         : out std_logic_vector(21 downto 0);
      rx_np_ok                : in  std_logic;

      fc_sel                  : in  std_logic_vector(2 downto 0);
      fc_nph                  : out std_logic_vector(7 downto 0);
      fc_npd                  : out std_logic_vector(11 downto 0);
      fc_ph                   : out std_logic_vector(7 downto 0);
      fc_pd                   : out std_logic_vector(11 downto 0);
      fc_cplh                 : out std_logic_vector(7 downto 0);
      fc_cpld                 : out std_logic_vector(11 downto 0);

      -- Host (CFG) Interface
      cfg_do                  : out std_logic_vector(31 downto 0);
      cfg_rd_wr_done          : out std_logic;
      cfg_dwaddr              : in  std_logic_vector(9 downto 0);
      cfg_rd_en               : in  std_logic;
      cfg_err_ur              : in  std_logic;
      cfg_err_cor             : in  std_logic;
      cfg_err_ecrc            : in  std_logic;
      cfg_err_cpl_timeout     : in  std_logic;
      cfg_err_cpl_abort       : in  std_logic;
      cfg_err_posted          : in  std_logic;
      cfg_err_locked          : in  std_logic;
      cfg_err_tlp_cpl_header  : in  std_logic_vector(47 downto 0);
      cfg_err_cpl_rdy         : out std_logic;
      cfg_interrupt           : in  std_logic;
      cfg_interrupt_rdy       : out std_logic;
      cfg_interrupt_assert    : in  std_logic;
      cfg_interrupt_do        : out std_logic_vector(7 downto 0);
      cfg_interrupt_di        : in  std_logic_vector(7 downto 0);
      cfg_interrupt_mmenable  : out std_logic_vector(2 downto 0);
      cfg_interrupt_msienable : out std_logic;
      cfg_turnoff_ok          : in  std_logic;
      cfg_to_turnoff          : out std_logic;
      cfg_pm_wake             : in  std_logic;
      cfg_pcie_link_state     : out std_logic_vector(2 downto 0);
      cfg_trn_pending         : in  std_logic;
      cfg_dsn                 : in  std_logic_vector(63 downto 0);
      cfg_bus_number          : out std_logic_vector(7 downto 0);
      cfg_device_number       : out std_logic_vector(4 downto 0);
      cfg_function_number     : out std_logic_vector(2 downto 0);
      cfg_status              : out std_logic_vector(15 downto 0);
      cfg_command             : out std_logic_vector(15 downto 0);
      cfg_dstatus             : out std_logic_vector(15 downto 0);
      cfg_dcommand            : out std_logic_vector(15 downto 0);
      cfg_lstatus             : out std_logic_vector(15 downto 0);
      cfg_lcommand            : out std_logic_vector(15 downto 0);

      -- System Interface
      sys_clk                 : in  std_logic;
      sys_reset               : in  std_logic;
      received_hot_reset      : out std_logic
    );
  end component sp605_pcie;

  ---------------------------------------------------------
  -- Signal declarations
  ---------------------------------------------------------

  -- Tx
  signal tx_keep                     : std_logic_vector(3 downto 0);
  signal tx_buf_av                   : std_logic_vector(5 downto 0);
  signal tx_cfg_req                  : std_logic;
  signal tx_err_drop                 : std_logic;
  signal tx_cfg_gnt                  : std_logic;

  -- Rx
  signal rx_keep                     : std_logic_vector (3 downto 0);
  signal rx_np_ok                    : std_logic;

  -- Flow Control
  signal fc_cpld                     : std_logic_vector(11 downto 0);
  signal fc_cplh                     : std_logic_vector(7 downto 0);
  signal fc_npd                      : std_logic_vector(11 downto 0);
  signal fc_nph                      : std_logic_vector(7 downto 0);
  signal fc_pd                       : std_logic_vector(11 downto 0);
  signal fc_ph                       : std_logic_vector(7 downto 0);
  signal fc_sel                      : std_logic_vector(2 downto 0);

  -- Config
  signal cfg_dsn                     : std_logic_vector(63 downto 0);
  signal cfg_do                      : std_logic_vector(31 downto 0);
  signal cfg_rd_wr_done              : std_logic;
  signal cfg_dwaddr                  : std_logic_vector(9 downto 0);
  signal cfg_rd_en                   : std_logic;

  -- Error signaling
  signal cfg_err_cor                 : std_logic;
  signal cfg_err_ur                  : std_logic;
  signal cfg_err_ecrc                : std_logic;
  signal cfg_err_cpl_timeout         : std_logic;
  signal cfg_err_cpl_abort           : std_logic;
  signal cfg_err_posted              : std_logic;
  signal cfg_err_locked              : std_logic;
  signal cfg_err_tlp_cpl_header      : std_logic_vector(47 downto 0);
  signal cfg_err_cpl_rdy             : std_logic;

  -- Interrupt signaling
  signal cfg_interrupt               : std_logic;
  signal cfg_interrupt_rdy           : std_logic;
  signal cfg_interrupt_assert        : std_logic;
  signal cfg_interrupt_di            : std_logic_vector(7 downto 0);
  signal cfg_interrupt_do            : std_logic_vector(7 downto 0);
  signal cfg_interrupt_mmenable      : std_logic_vector(2 downto 0);
  signal cfg_interrupt_msienable     : std_logic;

  -- Power management signaling
  signal cfg_turnoff_ok              : std_logic;
  signal cfg_to_turnoff              : std_logic;
  signal cfg_trn_pending             : std_logic;
  signal cfg_pm_wake                 : std_logic;

  -- System configuration and status
  signal cfg_bus_number              : std_logic_vector(7 downto 0);
  signal cfg_device_number           : std_logic_vector(4 downto 0);
  signal cfg_function_number         : std_logic_vector(2 downto 0);
  signal cfg_status                  : std_logic_vector(15 downto 0);
  signal cfg_command                 : std_logic_vector(15 downto 0);
  signal cfg_dstatus                 : std_logic_vector(15 downto 0);
  signal cfg_dcommand                : std_logic_vector(15 downto 0);
  signal cfg_lstatus                 : std_logic_vector(15 downto 0);
  signal cfg_lcommand                : std_logic_vector(15 downto 0);
  signal cfg_pcie_link_state         : std_logic_vector(2 downto 0);

  -- System Interface
  signal sys_clock                   : std_logic;
  signal sys_reset_n                 : std_logic;
  signal sys_reset                   : std_logic;

begin

  ---------------------------------------------------------
  -- Clock Input Buffer for differential system clock
  ---------------------------------------------------------
  clock_buffer : IBUFDS
  port map
  (
    O  => sys_clock,
    I  => clock_p,
    IB => clock_n
  );

  ---------------------------------------------------------
  -- Input buffer for system reset signal
  ---------------------------------------------------------
  reset_buffer : IBUF
  port map
  (
    O  => sys_reset_n,
    I  => reset_n
  );

  sys_reset <= not sys_reset_n;

  ---------------------------------------------------------
  -- PCIe core
  ---------------------------------------------------------
  sp605_pcie_core : sp605_pcie
  port map (
    -- PCI Express (PCI_EXP) Fabric Interface
    pci_exp_txp                        => pcie_tx_p,
    pci_exp_txn                        => pcie_tx_n,
    pci_exp_rxp                        => pcie_rx_p,
    pci_exp_rxn                        => pcie_rx_n,

    -- Transaction (TRN) Interface
    -- Common clock & reset
    user_lnk_up                        => link_up,
    user_clk_out                       => clock,
    user_reset_out                     => reset,
    -- Common flow control
    fc_sel                             => fc_sel,
    fc_nph                             => fc_nph,
    fc_npd                             => fc_npd,
    fc_ph                              => fc_ph,
    fc_pd                              => fc_pd,
    fc_cplh                            => fc_cplh,
    fc_cpld                            => fc_cpld,
    -- Transaction Tx
    s_axis_tx_tready                   => tx_ready,
    s_axis_tx_tdata                    => tx_data,
    s_axis_tx_tkeep                    => tx_keep,
    s_axis_tx_tuser                    => tx_user,
    s_axis_tx_tlast                    => tx_last,
    s_axis_tx_tvalid                   => tx_valid,
    tx_err_drop                        => tx_err_drop,
    tx_buf_av                          => tx_buf_av,
    tx_cfg_req                         => tx_cfg_req,
    tx_cfg_gnt                         => tx_cfg_gnt,
    -- Transaction Rx
    m_axis_rx_tdata                    => rx_data,
    m_axis_rx_tkeep                    => rx_keep,
    m_axis_rx_tlast                    => rx_last,
    m_axis_rx_tvalid                   => rx_valid,
    m_axis_rx_tready                   => rx_ready,
    m_axis_rx_tuser                    => rx_user,
    rx_np_ok                           => rx_np_ok,

    -- Configuration (CFG) Interface
    -- Configuration space access
    cfg_do                             => cfg_do,
    cfg_rd_wr_done                     => cfg_rd_wr_done,
    cfg_dwaddr                         => cfg_dwaddr,
    cfg_rd_en                          => cfg_rd_en,
    -- Error reporting
    cfg_err_ur                         => cfg_err_ur,
    cfg_err_cor                        => cfg_err_cor,
    cfg_err_ecrc                       => cfg_err_ecrc,
    cfg_err_cpl_timeout                => cfg_err_cpl_timeout,
    cfg_err_cpl_abort                  => cfg_err_cpl_abort,
    cfg_err_posted                     => cfg_err_posted,
    cfg_err_locked                     => cfg_err_locked,
    cfg_err_tlp_cpl_header             => cfg_err_tlp_cpl_header,
    cfg_err_cpl_rdy                    => cfg_err_cpl_rdy,
    -- Interrupt generation
    cfg_interrupt                      => cfg_interrupt,
    cfg_interrupt_rdy                  => cfg_interrupt_rdy,
    cfg_interrupt_assert               => cfg_interrupt_assert,
    cfg_interrupt_do                   => cfg_interrupt_do,
    cfg_interrupt_di                   => cfg_interrupt_di,
    cfg_interrupt_mmenable             => cfg_interrupt_mmenable,
    cfg_interrupt_msienable            => cfg_interrupt_msienable,
    -- Power management signaling
    cfg_turnoff_ok                     => cfg_turnoff_ok,
    cfg_to_turnoff                     => cfg_to_turnoff,
    cfg_pm_wake                        => cfg_pm_wake,
    cfg_pcie_link_state                => cfg_pcie_link_state,
    cfg_trn_pending                    => cfg_trn_pending,
    -- System configuration and status
    cfg_dsn                            => cfg_dsn,
    cfg_bus_number                     => cfg_bus_number,
    cfg_device_number                  => cfg_device_number,
    cfg_function_number                => cfg_function_number,
    cfg_status                         => cfg_status,
    cfg_command                        => cfg_command,
    cfg_dstatus                        => cfg_dstatus,
    cfg_dcommand                       => cfg_dcommand,
    cfg_lstatus                        => cfg_lstatus,
    cfg_lcommand                       => cfg_lcommand,

    -- System (SYS) Interface
    sys_clk                            => sys_clock,
    sys_reset                          => sys_reset,
    received_hot_reset                 => OPEN
  );

  ---------------------------------------------------------
  -- PCIe core input tie-offs
  ---------------------------------------------------------
  fc_sel                 <= "000";

  rx_np_ok               <= '1';

  tx_keep                <= "1111";
  tx_cfg_gnt             <= '1';

  cfg_err_cor            <= '0';
  cfg_err_ur             <= '0';
  cfg_err_ecrc           <= '0';
  cfg_err_cpl_timeout    <= '0';
  cfg_err_cpl_abort      <= '0';
  cfg_err_posted         <= '0';
  cfg_err_locked         <= '0';
  cfg_pm_wake            <= '0';
  cfg_trn_pending        <= '0';

  cfg_interrupt_assert   <= '0';
  cfg_interrupt          <= '0';
  cfg_interrupt_di       <= x"00";

  cfg_err_tlp_cpl_header <= (OTHERS => '0');
  cfg_dwaddr             <= (OTHERS => '0');
  cfg_rd_en              <= '0';
  cfg_dsn                <= (OTHERS => '0');

  cfg_turnoff_ok         <= '0';

  device_id              <= cfg_bus_number & cfg_device_number & cfg_function_number;

end rtl;

