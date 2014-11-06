library ieee;
use ieee.std_logic_1164.all;

entity sp605 is
  port (
    pcie_tx_p : out std_logic;
    pcie_tx_n : out std_logic;
    pcie_rx_p : in  std_logic;
    pcie_rx_n : in  std_logic;

    clock_p   : in  std_logic;
    clock_n   : in  std_logic;
    reset_n   : in  std_logic;

    leds      : out std_logic_vector(3 downto 0)
  );
end sp605;

architecture rtl of sp605 is

  -- General
  signal clock      : std_logic;
  signal reset      : std_logic;
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
  signal fifo_in    : std_logic_vector(31 downto 0);
  signal fifo_out   : std_logic_vector(31 downto 0);
  signal fifo_read  : std_logic;
  signal fifo_write : std_logic;

begin

  leds <= (others => '0');

  tx : entity work.tx_engine
  port map (
    -- General
    clock      => clock,
    reset      => reset,
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
    -- FIFO
    fifo_data  => fifo_out,
    fifo_read  => fifo_read
  );

  rx : entity work.rx_engine
  port map (
    -- General
    clock      => clock,
    reset      => reset,
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
    -- FIFO
    fifo_data  => fifo_in,
    fifo_write => fifo_write
  );

  fifo : entity work.fifo
  generic map (
    addr_bits => 10,
    data_bits => 32
  )
  port map (
    clock      => clock,
    reset      => reset,
    data_in    => fifo_in,
    data_out   => fifo_out,
    data_read  => fifo_read,
    data_write => fifo_write
  );

  pcie : entity work.sp605_pcie_wrapper
  port map (
    -- User Interface
    -- General
    clock     => clock,
    reset     => reset,
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
