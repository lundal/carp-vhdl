library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.VCOMPONENTS.all;

entity communication_sim is
  generic (
    tx_buffer_address_bits : integer := 10; -- PCIe packet length field is 10 bits
    rx_buffer_address_bits : integer := 10;
    reverse_payload_endian : boolean := true -- Required for x86 systems
  );
  port (
    sim_tx_buffer_out   : out std_logic_vector(31 downto 0);
    sim_tx_buffer_count : out std_logic_vector(tx_buffer_address_bits - 1 downto 0);
    sim_tx_buffer_read  : in  std_logic;

    sim_rx_buffer_in    : in  std_logic_vector(31 downto 0);
    sim_rx_buffer_count : out std_logic_vector(rx_buffer_address_bits - 1 downto 0);
    sim_rx_buffer_write : in  std_logic;

    clock_p : in  std_logic;
    clock_n : in  std_logic;
    reset_n : in  std_logic;

    tx_buffer_in    : in  std_logic_vector(31 downto 0);
    tx_buffer_count : out std_logic_vector(tx_buffer_address_bits - 1 downto 0);
    tx_buffer_write : in  std_logic;

    rx_buffer_out   : out std_logic_vector(31 downto 0);
    rx_buffer_count : out std_logic_vector(rx_buffer_address_bits - 1 downto 0);
    rx_buffer_read  : in  std_logic;

    clock : out std_logic;
    reset : out std_logic
  );
end communication_sim;

architecture rtl of communication_sim is

  -- General
  signal clock_i    : std_logic;
  signal reset_i    : std_logic;
  signal reset_n_i  : std_logic;
  
  -- Buffers
  signal tx_buffer_out            : std_logic_vector(31 downto 0);
  signal tx_buffer_count_i        : std_logic_vector(tx_buffer_address_bits - 1 downto 0);
  signal tx_buffer_read           : std_logic;
  signal rx_buffer_in             : std_logic_vector(31 downto 0);
  signal rx_buffer_count_i        : std_logic_vector(rx_buffer_address_bits - 1 downto 0);
  signal rx_buffer_write          : std_logic;

begin

  tx_buffer : entity work.fifo
  generic map (
    addr_bits => tx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock_i,
    reset      => reset_i,
    data_in    => tx_buffer_in,
    data_out   => tx_buffer_out,
    data_count => tx_buffer_count_i,
    data_read  => tx_buffer_read,
    data_write => tx_buffer_write
  );

  rx_buffer : entity work.fifo
  generic map (
    addr_bits => rx_buffer_address_bits,
    data_bits => 32
  )
  port map (
    clock      => clock_i,
    reset      => reset_i,
    data_in    => rx_buffer_in,
    data_out   => rx_buffer_out,
    data_count => rx_buffer_count_i,
    data_read  => rx_buffer_read,
    data_write => rx_buffer_write
  );
  
  -- Simulation mappings
  sim_tx_buffer_out   <= tx_buffer_out;
  sim_tx_buffer_count <= tx_buffer_count_i;
  tx_buffer_read      <= sim_tx_buffer_read;
  rx_buffer_in        <= sim_rx_buffer_in;
  sim_rx_buffer_count <= rx_buffer_count_i;
  rx_buffer_write     <= sim_rx_buffer_write;

  -- Buffer mappings
  tx_buffer_count <= tx_buffer_count_i;
  rx_buffer_count <= rx_buffer_count_i;

  -- Output mappings
  clock <= clock_i;
  reset <= reset_i;

  ---------------------------------------------------------
  -- Clock Input Buffer for differential system clock
  ---------------------------------------------------------
  clock_buffer : IBUFDS
  port map
  (
    O  => clock_i,
    I  => clock_p,
    IB => clock_n
  );

  ---------------------------------------------------------
  -- Input buffer for system reset signal
  ---------------------------------------------------------
  reset_buffer : IBUF
  port map
  (
    O  => reset_n_i,
    I  => reset_n
  );

  reset_i <= not reset_n_i;

end rtl;
