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

library IEEE;
use IEEE.std_logic_1164.all;

entity toplevel3 is
  port (
    pcie_tx_p : out std_logic;
    pcie_tx_n : out std_logic;
    pcie_rx_p : in  std_logic;
    pcie_rx_n : in  std_logic;

    clock_p : in  std_logic;
    clock_n : in  std_logic;
    reset_n : in  std_logic;

    leds : out std_logic_vector(3 downto 0)
  );
end toplevel3;

architecture rtl of toplevel3 is

  -- General
  signal clock : std_logic;
  signal reset : std_logic;

  -- Communication
  signal tx_buffer_data  : std_logic_vector(31 downto 0);
  signal tx_buffer_count : std_logic_vector(31 downto 0);
  signal tx_buffer_write : std_logic;

  signal rx_buffer_data  : std_logic_vector(31 downto 0);
  signal rx_buffer_count : std_logic_vector(31 downto 0);
  signal rx_buffer_read  : std_logic;

  -- Com40
  signal send         : std_logic;
  signal ack_send     : std_logic;
  signal receive      : std_logic;
  signal ack_receive  : std_logic;
  signal data_send    : std_logic_vector(63 downto 0);
  signal data_receive : std_logic_vector(63 downto 0);

begin

  leds <= "0000";

  -----------------------------------------------------------------------------

  com_unit : entity work.communication
  generic map (
    tx_buffer_address_bits => 10,
    rx_buffer_address_bits => 10,
    reverse_payload_endian => true -- Required for x86 systems
  )
  port map (
    pcie_tx_p => pcie_tx_p,
    pcie_tx_n => pcie_tx_n,
    pcie_rx_p => pcie_rx_p,
    pcie_rx_n => pcie_rx_n,

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

  receive <= not ack_receive;
  send <= ack_receive;

  data_send <= data_receive;

end rtl;
