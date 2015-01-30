
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity toplevel_sim_tb is
end toplevel_sim_tb;

architecture behavior of toplevel_sim_tb is 

  -- UUT
  signal tx_buffer_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal tx_buffer_count : std_logic_vector(9 downto 0) := (others => '0');
  signal tx_buffer_read  : std_logic := '0';
  signal rx_buffer_data  : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_buffer_count : std_logic_vector(9 downto 0) := (others => '0');
  signal rx_buffer_write : std_logic := '0';
  signal clock_p : std_logic := '1';
  signal clock_n : std_logic := '0';
  signal reset_n : std_logic := '0';
  signal leds : std_logic_vector(3 downto 0) := (others => '0');

  constant clock_period : time := 8 ns;

begin

  uut: entity work.toplevel_sim
  generic map (
    tx_buffer_address_bits => 10,
    rx_buffer_address_bits => 10,
    reverse_payload_endian => true,
    program_counter_bits   => 8,
    matrix_width           => 8,
    matrix_height          => 8,
    matrix_depth           => 8,
    matrix_wrap            => true,
    cell_type_bits         => 8,
    cell_state_bits        => 1,
    cell_write_width       => 8,
    instruction_bits       => 256,
    lut_configuration_bits => 8
  )
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

  clock_process: process begin
    clock_p <= '1';
    clock_n <= '0';
    wait for clock_period/2;
    clock_p <= '0';
    clock_n <= '1';
    wait for clock_period/2;
  end process;

  -- Stimulus process
  stimulus: process begin
    reset_n <= '0';

    wait for clock_period*10;
    reset_n <= '1';

    -- NULL (first instruction disappears in post-translate sim)

    wait for clock_period;
    rx_buffer_write <= '0';
    rx_buffer_data <= x"00000000";

    -- Instructions

    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"0042010B";

    -- NULL

    wait for clock_period;
    rx_buffer_write <= '0';
    rx_buffer_data <= x"00000000";

    wait;
  end process;
end;
