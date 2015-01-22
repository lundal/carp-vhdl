-------------------------------------------------------------------------------
-- Title      : Toplevel - Simulation Edition
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : toplevel.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Connects all main components
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-20  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity toplevel_sim is
  generic (
    tx_buffer_address_bits : positive := 10; -- PCIe packet length field is 10 bits
    rx_buffer_address_bits : positive := 10;
    reverse_payload_endian : boolean := true; -- Required for x86 systems
    program_counter_bits   : positive := 8;
    instruction_bits       : positive := 256
  );
  port (
    sim_tx_buffer_data  : out std_logic_vector(31 downto 0);
    sim_tx_buffer_count : out std_logic_vector(tx_buffer_address_bits - 1 downto 0);
    sim_tx_buffer_read  : in  std_logic;

    sim_rx_buffer_data  : in  std_logic_vector(31 downto 0);
    sim_rx_buffer_count : out std_logic_vector(rx_buffer_address_bits - 1 downto 0);
    sim_rx_buffer_write : in  std_logic;

    clock_p : in  std_logic;
    clock_n : in  std_logic;
    reset_n : in  std_logic;

    leds : out std_logic_vector(3 downto 0)
  );
end toplevel_sim;

architecture rtl of toplevel_sim is

  -- General
  signal clock : std_logic;
  signal reset : std_logic;

  -- Communication
  signal tx_buffer_data  : std_logic_vector(31 downto 0);
  signal tx_buffer_count : std_logic_vector(tx_buffer_address_bits - 1 downto 0);
  signal tx_buffer_write : std_logic;

  signal rx_buffer_data  : std_logic_vector(31 downto 0);
  signal rx_buffer_count : std_logic_vector(rx_buffer_address_bits - 1 downto 0);
  signal rx_buffer_read  : std_logic;

  -- Fetch
  signal fetch_instruction : std_logic_vector(instruction_bits - 1 downto 0);
  signal fetch_run         : std_logic;
  signal fetch_done        : std_logic;

begin

  leds <= "0101";

  -----------------------------------------------------------------------------

  communication : entity work.communication_sim
  generic map (
    tx_buffer_address_bits => tx_buffer_address_bits,
    rx_buffer_address_bits => rx_buffer_address_bits,
    reverse_payload_endian => reverse_payload_endian
  )
  port map (
    sim_tx_buffer_out   => sim_tx_buffer_data,
    sim_tx_buffer_count => sim_tx_buffer_count,
    sim_tx_buffer_read  => sim_tx_buffer_read,

    sim_rx_buffer_in    => sim_rx_buffer_data,
    sim_rx_buffer_count => sim_rx_buffer_count,
    sim_rx_buffer_write => sim_rx_buffer_write,

    clock_p => clock_p,
    clock_n => clock_n,
    reset_n => reset_n,

    tx_buffer_in    => tx_buffer_data,
    tx_buffer_count => tx_buffer_count,
    tx_buffer_write => tx_buffer_write,

    rx_buffer_out   => rx_buffer_data,
    rx_buffer_count => rx_buffer_count,
    rx_buffer_read  => rx_buffer_read,

    clock => clock,
    reset => reset
  );

  fetch : entity work.fetch
  generic map (
    buffer_address_bits  => rx_buffer_address_bits,
    program_counter_bits => program_counter_bits,
    instruction_bits     => instruction_bits
  )
  port map (
    buffer_data  => rx_buffer_data,
    buffer_count => rx_buffer_count,
    buffer_read  => rx_buffer_read,

    instruction => fetch_instruction,

    run  => fetch_run,
    done => fetch_done,

    clock => clock
  );

end rtl;
