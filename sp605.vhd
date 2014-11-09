library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sp605 is
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
end sp605;

architecture rtl of sp605 is

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

begin

  leds <= (others => '0');

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

  -- Link buffers together
  tx_buffer_data <= rx_buffer_data;
  tx_buffer_write <= '0' when rx_buffer_count = (31 downto 0 => '0') else '1';
  rx_buffer_read <= '0' when rx_buffer_count = (31 downto 0 => '0') else '1';

end rtl;
