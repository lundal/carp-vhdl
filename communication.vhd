-------------------------------------------------------------------------------
-- Title      : Communication Module
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : communication.vhd
-- Author     : Per Thomas Lundal
-- Company    : NTNU
-- Last update: 2014/11/07
-- Platform   : Spartan-6 LX45T
-------------------------------------------------------------------------------
-- Description: Handles communication with host system over PCIe
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/07  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity communication is
  generic (
    tx_buffer_address_bits : integer := 10;
    rx_buffer_address_bits : integer := 10;
    reverse_payload_endian : boolean := true -- Required for x86 systems
  );
  port (
    pcie_tx_p : out std_logic;
    pcie_tx_n : out std_logic;
    pcie_rx_p : in  std_logic;
    pcie_rx_n : in  std_logic;

    clock_p : in  std_logic;
    clock_n : in  std_logic;
    reset_n : in  std_logic;

    tx_buffer_data  : in  std_logic_vector(31 downto 0);
    tx_buffer_count : out std_logic_vector(31 downto 0);
    tx_buffer_write : in  std_logic;

    rx_buffer_data  : out std_logic_vector(31 downto 0);
    rx_buffer_count : out std_logic_vector(31 downto 0);
    rx_buffer_read  : in  std_logic;

    clock : out std_logic;
    reset : out std_logic
  );
end communication;

architecture rtl of communication is

  -- General
  signal clock_i    : std_logic;
  signal reset_i    : std_logic;
  signal link_up    : std_logic;
  signal device_id  : std_logic_vector(15 downto 0);
  
  -- Tx
  signal tx_ready   : std_logic;
  signal tx_valid   : std_logic;
  signal tx_last    : std_logic;
  signal tx_data    : std_logic_vector(31 downto 0);
  signal tx_user    : std_logic_vector(3 downto 0);

  -- Rx
  signal rx_ready   : std_logic;
  signal rx_valid   : std_logic;
  signal rx_last    : std_logic;
  signal rx_data    : std_logic_vector(31 downto 0);
  signal rx_user    : std_logic_vector(21 downto 0);
  
  -- Request
  signal rq_ready   : std_logic;
  signal rq_valid   : std_logic;
  signal rq_address : std_logic_vector(31 downto 0);
  signal rq_length  : std_logic_vector(9 downto 0);
  signal rq_id      : std_logic_vector(15 downto 0);
  signal rq_tag     : std_logic_vector(7 downto 0);
  
  -- FIFO
  signal fifo_tx_in             : std_logic_vector(31 downto 0);
  signal fifo_tx_out            : std_logic_vector(31 downto 0);
  signal fifo_tx_count          : std_logic_vector(tx_buffer_address_bits-1 downto 0);
  signal fifo_tx_count_extended : std_logic_vector(31 downto 0);
  signal fifo_tx_read           : std_logic;
  signal fifo_tx_write          : std_logic;
  signal fifo_rx_in             : std_logic_vector(31 downto 0);
  signal fifo_rx_out            : std_logic_vector(31 downto 0);
  signal fifo_rx_count          : std_logic_vector(rx_buffer_address_bits-1 downto 0);
  signal fifo_rx_count_extended : std_logic_vector(31 downto 0);
  signal fifo_rx_read           : std_logic;
  signal fifo_rx_write          : std_logic;

begin

  tx_engine : entity work.tx_engine
  generic map (
    reverse_payload_endian => reverse_payload_endian
  )
  port map (
    -- General
    clock      => clock_i,
    reset      => reset_i,
    link_up    => link_up,
    device_id  => device_id,
    -- Tx
    tx_ready   => tx_ready,
    tx_valid   => tx_valid,
    tx_last    => tx_last,
    tx_data    => tx_data,
    tx_user    => tx_user,
    -- Request
    rq_ready   => rq_ready,
    rq_valid   => rq_valid,
    rq_address => rq_address,
    rq_length  => rq_length,
    rq_id      => rq_id,
    rq_tag     => rq_tag,
    -- Buffer
    buffer_data  => fifo_tx_out,
    buffer_count => fifo_tx_count_extended,
    buffer_read  => fifo_tx_read
  );

  rx_engine : entity work.rx_engine
  generic map (
    reverse_payload_endian => reverse_payload_endian
  )
  port map (
    -- General
    clock      => clock_i,
    reset      => reset_i,
    link_up    => link_up,
    device_id  => device_id,
    -- Rx
    rx_ready   => rx_ready,
    rx_valid   => rx_valid,
    rx_last    => rx_last,
    rx_data    => rx_data,
    rx_user    => rx_user,
    -- Request
    rq_ready   => rq_ready,
    rq_valid   => rq_valid,
    rq_address => rq_address,
    rq_length  => rq_length,
    rq_id      => rq_id,
    rq_tag     => rq_tag,
    -- Buffer
    buffer_data  => fifo_rx_in,
    buffer_count => fifo_rx_count_extended,
    buffer_write => fifo_rx_write
  );

  tx_fifo : entity work.fifo
  generic map (
    addr_bits => tx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock_i,
    reset      => reset_i,
    data_in    => fifo_tx_in,
    data_out   => fifo_tx_out,
    data_count => fifo_tx_count,
    data_read  => fifo_tx_read,
    data_write => fifo_tx_write
  );

  rx_fifo : entity work.fifo
  generic map (
    addr_bits => rx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock_i,
    reset      => reset_i,
    data_in    => fifo_rx_in,
    data_out   => fifo_rx_out,
    data_count => fifo_rx_count,
    data_read  => fifo_rx_read,
    data_write => fifo_rx_write
  );

  -- FIFO mappings
  fifo_tx_count_extended <= std_logic_vector(resize(unsigned(fifo_tx_count), 32));
  fifo_rx_count_extended <= std_logic_vector(resize(unsigned(fifo_rx_count), 32));

  -- Buffer mappings
  tx_buffer_count <= fifo_tx_count_extended;
  rx_buffer_count <= fifo_rx_count_extended;
  rx_buffer_data <= fifo_rx_out;
  fifo_tx_in <= tx_buffer_data;
  fifo_tx_write <= tx_buffer_write;
  fifo_rx_read  <= rx_buffer_read;

  -- Output mappings
  clock <= clock_i;
  reset <= reset_i;

  pcie : entity work.sp605_pcie_wrapper
  port map (
    -- User Interface
    -- General
    clock     => clock_i,
    reset     => reset_i,
    link_up   => link_up,
    device_id => device_id,

    -- Tx
    tx_ready  => tx_ready,
    tx_valid  => tx_valid,
    tx_last   => tx_last,
    tx_data   => tx_data,
    tx_user   => tx_user,

    -- Rx
    rx_ready  => rx_ready,
    rx_valid  => rx_valid,
    rx_last   => rx_last,
    rx_data   => rx_data,
    rx_user   => rx_user,

    -- System interface
    -- PCIe
    pcie_tx_p => pcie_tx_p,
    pcie_tx_n => pcie_tx_n,
    pcie_rx_p => pcie_rx_p,
    pcie_rx_n => pcie_rx_n,

    -- System
    clock_p   => clock_p,
    clock_n   => clock_n,
    reset_n   => reset_n
  );

end rtl;
