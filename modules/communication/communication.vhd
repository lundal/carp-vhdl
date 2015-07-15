--------------------------------------------------------------------------------
-- Title       : Communication
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Communicates with host over PCI Express
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2014  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity communication is
  generic (
    tx_buffer_address_bits : positive := 10; -- PCIe packet length field is 10 bits
    rx_buffer_address_bits : positive := 10;
    reverse_payload_endian : boolean := true -- Required for x86 systems
  );
  port (
    pcie_tx_p : out std_logic;
    pcie_tx_n : out std_logic;
    pcie_rx_p : in  std_logic;
    pcie_rx_n : in  std_logic;

    pcie_clock_p : in  std_logic;
    pcie_clock_n : in  std_logic;
    pcie_reset_n : in  std_logic;

    tx_buffer_in    : in  std_logic_vector(31 downto 0);
    tx_buffer_count : out std_logic_vector(tx_buffer_address_bits - 1 downto 0);
    tx_buffer_write : in  std_logic;

    rx_buffer_out   : out std_logic_vector(31 downto 0);
    rx_buffer_count : out std_logic_vector(rx_buffer_address_bits - 1 downto 0);
    rx_buffer_read  : in  std_logic;

    clock : in std_logic
  );
end communication;

architecture rtl of communication is

  -- General
  signal clock_625  : std_logic;
  signal reset_625  : std_logic;
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
  signal rq_bar_hit : std_logic_vector(5 downto 0);

  -- Special
  signal rq_special      : std_logic;
  signal rq_special_data : std_logic_vector(31 downto 0);

  -- Buffers 62.5 MHz
  signal tx_buffer_625_in    : std_logic_vector(31 downto 0);
  signal tx_buffer_625_out   : std_logic_vector(31 downto 0);
  signal tx_buffer_625_count : std_logic_vector(tx_buffer_address_bits - 1 downto 0);
  signal tx_buffer_625_read  : std_logic;
  signal tx_buffer_625_write : std_logic;
  signal rx_buffer_625_in    : std_logic_vector(31 downto 0);
  signal rx_buffer_625_out   : std_logic_vector(31 downto 0);
  signal rx_buffer_625_count : std_logic_vector(rx_buffer_address_bits - 1 downto 0);
  signal rx_buffer_625_read  : std_logic;
  signal rx_buffer_625_write : std_logic;

  -- Buffers 125 MHz
  signal tx_buffer_out     : std_logic_vector(31 downto 0);
  signal tx_buffer_count_i : std_logic_vector(tx_buffer_address_bits - 1 downto 0);
  signal tx_buffer_read    : std_logic;
  signal rx_buffer_in      : std_logic_vector(31 downto 0);
  signal rx_buffer_count_i : std_logic_vector(rx_buffer_address_bits - 1 downto 0);
  signal rx_buffer_write   : std_logic;

begin

  tx_engine : entity work.tx_engine
  generic map (
    reverse_payload_endian => reverse_payload_endian
  )
  port map (
    -- General
    clock      => clock_625,
    reset      => reset_625,
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
    -- Special
    rq_special      => rq_special,
    rq_special_data => rq_special_data,
    -- Buffer
    buffer_data  => tx_buffer_625_out,
    buffer_read  => tx_buffer_625_read
  );

  rx_engine : entity work.rx_engine
  generic map (
    reverse_payload_endian => reverse_payload_endian
  )
  port map (
    -- General
    clock      => clock_625,
    reset      => reset_625,
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
    rq_bar_hit => rq_bar_hit,
    -- Buffer
    buffer_data  => rx_buffer_625_in,
    buffer_write => rx_buffer_625_write
  );

  rq_special_handler : entity work.rq_special
  generic map (
    tx_buffer_address_bits => tx_buffer_address_bits,
    rx_buffer_address_bits => rx_buffer_address_bits
  )
  port map (
    -- General
    clock      => clock_625,
    reset      => reset_625,
    link_up    => link_up,
    device_id  => device_id,
    -- Request
    rq_ready   => rq_ready,
    rq_valid   => rq_valid,
    rq_address => rq_address,
    rq_bar_hit => rq_bar_hit,
    -- Special
    rq_special      => rq_special,
    rq_special_data => rq_special_data,
    -- Buffer
    tx_buffer_count => tx_buffer_625_count,
    rx_buffer_count => rx_buffer_625_count
  );

  -- Internal 62.5 MHz buffers

  tx_buffer_625 : entity work.fifo
  generic map (
    address_bits => tx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock_625,
    reset      => reset_625,
    data_in    => tx_buffer_625_in,
    data_out   => tx_buffer_625_out,
    data_count => tx_buffer_625_count,
    data_read  => tx_buffer_625_read,
    data_write => tx_buffer_625_write
  );

  rx_buffer_625 : entity work.fifo
  generic map (
    address_bits => rx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock_625,
    reset      => reset_625,
    data_in    => rx_buffer_625_in,
    data_out   => rx_buffer_625_out,
    data_count => rx_buffer_625_count,
    data_read  => rx_buffer_625_read,
    data_write => rx_buffer_625_write
  );

  -- External 125 MHz buffers

  tx_buffer : entity work.fifo
  generic map (
    address_bits => tx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock,
    reset      => '0',
    data_in    => tx_buffer_in,
    data_out   => tx_buffer_out,
    data_count => tx_buffer_count_i,
    data_read  => tx_buffer_read,
    data_write => tx_buffer_write
  );

  rx_buffer : entity work.fifo
  generic map (
    address_bits => rx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock,
    reset      => '0',
    data_in    => rx_buffer_in,
    data_out   => rx_buffer_out,
    data_count => rx_buffer_count_i,
    data_read  => rx_buffer_read,
    data_write => rx_buffer_write
  );

  -- Synchronizers

  tx_synchronizer : entity work.fifo_synchronizer
  generic map (
    buffer_a_size => 2 ** tx_buffer_address_bits,
    buffer_b_size => 2 ** tx_buffer_address_bits,
    buffer_bits   => 32
  )
  port map (
    buffer_a_read  => tx_buffer_read,
    buffer_a_data  => tx_buffer_out,
    buffer_a_count => tx_buffer_count_i,

    buffer_b_write => tx_buffer_625_write,
    buffer_b_data  => tx_buffer_625_in,
    buffer_b_count => tx_buffer_625_count,

    clock_a => clock,
    clock_b => clock_625
  );

  rx_synchronizer : entity work.fifo_synchronizer
  generic map (
    buffer_a_size => 2 ** rx_buffer_address_bits,
    buffer_b_size => 2 ** rx_buffer_address_bits,
    buffer_bits   => 32
  )
  port map (
    buffer_a_read  => rx_buffer_625_read,
    buffer_a_data  => rx_buffer_625_out,
    buffer_a_count => rx_buffer_625_count,

    buffer_b_write => rx_buffer_write,
    buffer_b_data  => rx_buffer_in,
    buffer_b_count => rx_buffer_count_i,

    clock_a => clock_625,
    clock_b => clock
  );

  pcie : entity work.pcie_wrapper
  port map (
    -- User Interface
    -- General
    clock_625 => clock_625,
    reset_625 => reset_625,
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
    pcie_clock_p => pcie_clock_p,
    pcie_clock_n => pcie_clock_n,
    pcie_reset_n => pcie_reset_n
  );

  -- Buffer mappings
  tx_buffer_count <= tx_buffer_count_i;
  rx_buffer_count <= rx_buffer_count_i;

end rtl;