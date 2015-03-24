
library ieee;
use ieee.std_logic_1164.all;

entity test_config_readback is
end test_config_readback;

architecture behavior of test_config_readback is 

  signal tx_buffer_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal tx_buffer_count : std_logic_vector(9 downto 0) := (others => '0');
  signal tx_buffer_read  : std_logic := '0';
  signal rx_buffer_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_buffer_count : std_logic_vector(9 downto 0) := (others => '0');
  signal rx_buffer_write : std_logic := '0';

  signal clock_p : std_logic := '1';
  signal clock_n : std_logic := '0';
  signal reset_n : std_logic := '0';

  constant clock_period : time := 8 ns;

begin

  toplevel : entity work.toplevel
  generic map (
    simulation_mode => true
  )
  port map (
    sim_tx_buffer_data  => tx_buffer_data,
    sim_tx_buffer_count => tx_buffer_count,
    sim_tx_buffer_read  => tx_buffer_read,

    sim_rx_buffer_data  => rx_buffer_data,
    sim_rx_buffer_count => rx_buffer_count,
    sim_rx_buffer_write => rx_buffer_write,

    pcie_tx_p => open,
    pcie_tx_n => open,
    pcie_rx_p => '0',
    pcie_rx_n => '0',

    clock_p => clock_p,
    clock_n => clock_n,
    reset_n => reset_n,

    leds => open
  );

  clock_process: process begin
    clock_p <= '1';
    clock_n <= '0';
    wait for clock_period/2;
    clock_p <= '0';
    clock_n <= '1';
    wait for clock_period/2;
  end process;

  stimulus: process begin
    wait for clock_period;
    reset_n <= '1';

    -- Instructions

    -- Fill (x42, 1)
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"0042010B";

    -- State(3,2,1) = 0
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"0302012C";
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";

    -- Swap
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000014";

    -- Configure
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000012";

    -- Readback
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000013";

    -- Null

    wait for clock_period;
    rx_buffer_write <= '0';
    rx_buffer_data <= x"00000000";

    wait;
  end process;
end;
