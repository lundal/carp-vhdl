-------------------------------------------------------------------------------
-- Title      : Live Counter
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : live_counter.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-30
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Stores the total number of live cells to bram.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-30  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity live_counter is
  generic (
    cell_amount : positive := 1024
  );
  port (
    run         : in  std_logic;
    cell_states : in  std_logic_vector(cell_amount - 1 downto 0);
    live_count  : out std_logic_vector(bits(cell_amount) downto 0);
    write_count : out std_logic;

    clock : in std_logic
  );
end entity;

architecture rtl of live_counter is

  constant bitcounter_delay : positive := bits(cell_amount) - 4;

  signal write_delay_register : std_logic_vector(bitcounter_delay - 1 downto 0);

begin

  -- Calculate number of live cells
  -- Finishes in bits(cell_amount) - 4 cycles
  bit_counter : entity work.bit_counter_N
  generic map (
    input_bits => cell_amount
  )
  port map (
    input => cell_states,
    count => live_count,

    clock => clock
  );

  -- Delay write signal to match bit_counter
  process begin
    wait until rising_edge(clock);
    write_delay_register <= write_delay_register(write_delay_register'high - 1 downto 0) & run;
  end process;

  write_count <= write_delay_register(write_delay_register'high);

end architecture;
