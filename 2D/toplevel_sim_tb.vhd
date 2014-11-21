
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
    
    -- #WRITES
    
    -- writeType(1, 0,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000001";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000081";

    -- writeType(2, 1,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000101";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000082";
    
    -- writeType(3, 2,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000201";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000083";
    
    -- writeType(4, 3,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000301";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000084";
    
    -- writeType(5, 4,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000401";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000085";
    
    -- writeType(6, 5,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000501";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000086";
    
    -- writeType(7, 6,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000601";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000087";
    
    -- writeType(8, 7,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000701";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000088";
    
    -- #READS
    
    -- readType(0,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000002";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(1,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000102";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(2,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000202";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(3,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000302";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(4,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000402";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(5,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000502";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(6,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000602";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(7,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000702";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- #REVERSE WRITES
    
    -- writeType(8, 7,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000701";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000088";
    
    -- writeType(7, 6,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000601";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000087";
    
    -- writeType(6, 5,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000501";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000086";
    
    -- writeType(5, 4,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000401";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000085";
    
    -- writeType(4, 3,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000301";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000084";
    
    -- writeType(3, 2,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000201";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000083";
    
    -- writeType(2, 1,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000101";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000082";
    
    -- writeType(1, 0,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000001";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000081";
    
    -- #READS
    
    -- readType(0,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000002";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(1,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000102";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(2,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000202";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(3,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000302";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(4,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000402";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(5,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000502";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(6,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000602";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- readType(7,0,0)
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000702";
    
    wait for clock_period;
    rx_buffer_write <= '1';
    rx_buffer_data <= x"00000000";
    
    -- NULL
    
    wait for clock_period;
    rx_buffer_write <= '0';
    rx_buffer_data <= x"00000000";
    
    wait;
  end process;
end;
