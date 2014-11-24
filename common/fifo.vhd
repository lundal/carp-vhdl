-------------------------------------------------------------------------------
-- Title      : FIFO Buffer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : fifo.vhd
-- Author     : Per Thomas Lundal
-- Company    : NTNU
-- Last update: 2014/11/07
-- Platform   : Spartan-6 LX45T
-------------------------------------------------------------------------------
-- Description: A circular first-in first-out buffer
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/07  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
  generic (
    addr_bits : integer := 4;
    data_bits : integer := 32
  );
  port (
    clock      : in  std_logic;
    reset      : in  std_logic;
    data_in    : in  std_logic_vector(data_bits - 1 downto 0);
    data_out   : out std_logic_vector(data_bits - 1 downto 0);
    data_count : out std_logic_vector(addr_bits - 1 downto 0);
    data_read  : in  std_logic;
    data_write : in  std_logic
  );
end fifo;

architecture rtl of fifo is

  signal read_address  : std_logic_vector(addr_bits - 1 downto 0);
  signal write_address : std_logic_vector(addr_bits - 1 downto 0);

  signal pointer_read  : std_logic_vector(addr_bits - 1 downto 0);
  signal pointer_write : std_logic_vector(addr_bits - 1 downto 0);

  signal bram_out : std_logic_vector(data_bits - 1 downto 0);

  signal data_buffer_enable : boolean;
  signal data_buffer        : std_logic_vector(data_bits - 1 downto 0);

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
      data_buffer_enable <= false;
    else
      if (data_read = '1') then
        pointer_read <= std_logic_vector(unsigned(pointer_read) + 1);
      end if;
      if (data_write = '1') then
        pointer_write <= std_logic_vector(unsigned(pointer_write) + 1);
      end if;
      -- Buffer data when empty (write and read addresses are the same).
      -- This is a workaround to allow the data to be available in the
      -- following cycle, as the BRAM operates in read before write mode.
      data_buffer_enable <= read_address = write_address and data_write = '1';
      data_buffer        <= data_in;
    end if;
  end process;

  data_out <= data_buffer when data_buffer_enable else bram_out;

  bram : entity work.bram_inferrer
  generic map (
    addr_bits => addr_bits,
    data_bits => data_bits
  )
  port map (
    clk_a    => clock,
    clk_b    => clock,

    addr_a   => read_address,
    data_i_a => (others => '0'),
    data_o_a => bram_out,
    we_a     => '0',
    en_a     => '1',
    rst_a    => '0',

    addr_b   => write_address,
    data_i_b => data_in,
    data_o_b => open,
    we_b     => '1',
    en_b     => '1',
    rst_b    => '0'
  );

end rtl;
