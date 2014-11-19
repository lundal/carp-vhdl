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
    sim_tx_buffer_data  : out std_logic_vector(31 downto 0);
    sim_tx_buffer_count : out std_logic_vector(31 downto 0);
    sim_tx_buffer_read  : in  std_logic;

    sim_rx_buffer_data  : in  std_logic_vector(31 downto 0);
    sim_rx_buffer_count : out std_logic_vector(31 downto 0);
    sim_rx_buffer_write : in  std_logic;

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
end communication_sim;

architecture rtl of communication_sim is

  -- General
  signal clock_i    : std_logic;
  signal reset_i    : std_logic;
  signal reset_n_i  : std_logic;
  
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
  
  -- Simulation mappings
  fifo_tx_read  <= sim_tx_buffer_read;
  fifo_rx_write <= sim_rx_buffer_write;
  sim_tx_buffer_data <= fifo_tx_out;
  fifo_rx_in <= sim_rx_buffer_data;
  
  reset_i <= not reset_n_i;

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

end rtl;
