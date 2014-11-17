
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity toplevel2_tb is
end toplevel2_tb;

architecture behavior of toplevel2_tb is 

  signal clock_n : std_logic := '0';
  signal reset_n : std_logic := '0';
  signal clock : std_logic := '0';
  signal reset : std_logic := '0';

  signal leds : std_logic_vector(3 downto 0) := (others => '0');

  constant clock_period : time := 10 ns;

  -- FIFO
  signal fifo_tx_in             : std_logic_vector(31 downto 0) := (others => '0');
  signal fifo_tx_out            : std_logic_vector(31 downto 0) := (others => '0');
  signal fifo_tx_count          : std_logic_vector(4-1 downto 0);
  signal fifo_tx_count_extended : std_logic_vector(31 downto 0);
  signal fifo_tx_read           : std_logic := '0';
  signal fifo_tx_write          : std_logic := '0';
  signal fifo_rx_in             : std_logic_vector(31 downto 0) := (others => '0');
  signal fifo_rx_out            : std_logic_vector(31 downto 0) := (others => '0');
  signal fifo_rx_count          : std_logic_vector(4-1 downto 0);
  signal fifo_rx_count_extended : std_logic_vector(31 downto 0);
  signal fifo_rx_read           : std_logic := '0';
  signal fifo_rx_write          : std_logic := '0';

begin

  uut: entity work.toplevel2
  port map(
    tx_buffer_data  => fifo_tx_in,
    tx_buffer_count => fifo_tx_count_extended,
    tx_buffer_write => fifo_tx_write,

    rx_buffer_data  => fifo_rx_out,
    rx_buffer_count => fifo_rx_count_extended,
    rx_buffer_read  => fifo_rx_read,

    clock_n => clock_n,
    reset_n => reset_n,

    leds => leds
  );

  tx_fifo : entity work.fifo
  generic map (
    addr_bits => 4,
    data_bits => 32
  )
  port map (
    clock      => clock,
    reset      => reset,
    data_in    => fifo_tx_in,
    data_out   => fifo_tx_out,
    data_count => fifo_tx_count,
    data_read  => fifo_tx_read,
    data_write => fifo_tx_write
  );

  rx_fifo : entity work.fifo
  generic map (
    addr_bits => 4,
    data_bits => 32
  )
  port map (
    clock      => clock,
    reset      => reset,
    data_in    => fifo_rx_in,
    data_out   => fifo_rx_out,
    data_count => fifo_rx_count,
    data_read  => fifo_rx_read,
    data_write => fifo_rx_write
  );

  -- FIFO mappings
  fifo_tx_count_extended <= std_logic_vector(resize(unsigned(fifo_tx_count), 32));
  fifo_rx_count_extended <= std_logic_vector(resize(unsigned(fifo_rx_count), 32));
  clock <= not clock_n;
  reset <= not reset_n;

  clock_process: process
  begin
    clock_n <= '0';
    wait for clock_period/2;
    clock_n <= '1';
    wait for clock_period/2;
  end process;

  -- Stimulus process
  stimulus: process
  begin
    reset_n <= '0';
    
    wait for clock_period*10;
    reset_n <= '1';
    
    -- writeState(1, 0,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000004";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"80000000";
    
    -- writeType(11, 0,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000001";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"0000000B";
    
    -- readState(0,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000005";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000000";
    
    -- readType(0,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000002";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000000";
    
    -- null
    
    wait for clock_period;
    fifo_rx_write <= '0';
    fifo_rx_in <= x"00000000";
    
    wait;
  end process;
end;
