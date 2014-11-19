
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity toplevel_sim_tb is
end toplevel_sim_tb;

architecture behavior of toplevel_sim_tb is 

  -- UUT
  signal tx_buffer_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal tx_buffer_count : std_logic_vector(31 downto 0) := (others => '0');
  signal tx_buffer_read  : std_logic := '0';
  signal rx_buffer_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_buffer_count : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_buffer_write : std_logic := '0';
  signal clock_p : std_logic := '1';
  signal clock_n : std_logic := '0';
  signal reset_n : std_logic := '0';
  signal leds : std_logic_vector(3 downto 0) := (others => '0');

  constant clock_period : time := 8 ns;

begin

  uut: entity work.toplevel_sim
  port map(
    sim_tx_buffer_data  => tx_buffer_data,
    sim_tx_buffer_count => tx_buffer_count,
    sim_tx_buffer_read  => tx_buffer_read,

    sim_rx_buffer_data  => rx_buffer_data,
    sim_rx_buffer_count => rx_buffer_count,
    sim_rx_buffer_write => rx_buffer_write,

    clock_p => clock_p,
    clock_n => clock_n,
    reset_n => reset_n,

    leds => leds
  );

  clock_process: process
  begin
    clock_p <= '1';
    clock_n <= '0';
    wait for clock_period/2;
    clock_p <= '0';
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
    
    -- writeState(0, 1,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000104";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000000";
    
    -- writeState(1, 2,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000204";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"80000000";
    
    -- writeState(0, 3,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000304";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000000";
    
    -- readState(0,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000005";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000000";
    
    -- readState(1,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000105";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000000";
    
    -- readState(2,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000205";
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000000";
    
    -- readState(3,0,0)
    
    wait for clock_period;
    fifo_rx_write <= '1';
    fifo_rx_in <= x"00000305";
    
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
