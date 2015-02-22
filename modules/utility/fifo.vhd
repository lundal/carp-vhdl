-------------------------------------------------------------------------------
-- Title      : FIFO Buffer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : fifo.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: A circular first-in first-out buffer
--            : Note: Count becomes 0 when completely filled
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-20  1.1      lundal    Use updated bram module
-- 2014-11-07  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
  generic (
    address_bits : positive := 8;
    data_bits    : positive := 32
  );
  port (
    clock      : in  std_logic;
    reset      : in  std_logic;
    data_in    : in  std_logic_vector(data_bits - 1 downto 0);
    data_out   : out std_logic_vector(data_bits - 1 downto 0);
    data_count : out std_logic_vector(address_bits - 1 downto 0);
    data_read  : in  std_logic;
    data_write : in  std_logic
  );
end fifo;

architecture rtl of fifo is

  signal read_address  : std_logic_vector(address_bits - 1 downto 0);
  signal write_address : std_logic_vector(address_bits - 1 downto 0);

  signal pointer_read  : std_logic_vector(address_bits - 1 downto 0) := (others => '0');
  signal pointer_write : std_logic_vector(address_bits - 1 downto 0) := (others => '0');

begin

  -- Pre-increase read address so data is available after only one clock cycle
  read_address  <= pointer_read when data_read = '0' else
                   std_logic_vector(unsigned(pointer_read) + 1);
  write_address <= pointer_write;

  data_count <= std_logic_vector(unsigned(pointer_write) - unsigned(pointer_read));

  process begin
    wait until rising_edge(clock);
    if (reset = '1') then
      pointer_read  <= (others => '0');
      pointer_write <= (others => '0');
    else
      if (data_read = '1') then
        pointer_read <= std_logic_vector(unsigned(pointer_read) + 1);
      end if;
      if (data_write = '1') then
        pointer_write <= std_logic_vector(unsigned(pointer_write) + 1);
      end if;
    end if;
  end process;

  bram : entity work.bram_tdp
  generic map (
    address_bits => address_bits,
    data_bits => data_bits,
    write_first => true
  )
  port map (
    a_write    => '0',
    a_address  => read_address,
    a_data_in  => (others => '0'),
    a_data_out => data_out,

    b_write    => data_write,
    b_address  => write_address,
    b_data_in  => data_in,
    b_data_out => open,

    clock      => clock
  );

end rtl;
