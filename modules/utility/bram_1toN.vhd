--------------------------------------------------------------------------------
-- Title       : 1-in N-out BRAM
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : BRAM with one write port and N read ports.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity bram_1toN is
  generic (
    address_bits : positive := 8;
    data_bits    : positive := 32;
    read_ports   : positive := 7
  );
  port (
    -- Write port
    write_enabled : in  std_logic;
    write_address : in  std_logic_vector(address_bits - 1 downto 0);
    write_data    : in  std_logic_vector(data_bits - 1 downto 0);

    -- Read ports
    read_address_slv : in  std_logic_vector(read_ports*address_bits - 1 downto 0);
    read_data_slv    : out std_logic_vector(read_ports*data_bits - 1 downto 0);

    clock : in std_logic
  );
end bram_1toN;

architecture rtl of bram_1toN is

  type address_array is array(read_ports - 1 downto 0) of std_logic_vector(address_bits - 1 downto 0);
  type data_array is array(read_ports - 1 downto 0) of std_logic_vector(data_bits - 1 downto 0);

  signal read_address : address_array;
  signal bram_address : address_array;
  signal read_data    : data_array;

begin

  -- XST does not have proper support for VHDL2008 which is needed for generic
  -- arrays in port declarations. Hence the conversion to/from std_logic_vector.

  slv_to_array : for i in 0 to read_ports - 1 generate
    read_address(i) <= read_address_slv((i+1)*address_bits - 1 downto i*address_bits);
  end generate;

  array_to_slv : for i in 0 to read_ports - 1 generate
    read_data_slv((i+1)*data_bits - 1 downto i*data_bits) <= read_data(i);
  end generate;

  ----

  bram_address <= (others => write_address) when write_enabled = '1' else read_address;

  brams : for i in 0 to read_ports/2 - 1 generate
    bram : entity work.bram_tdp
    generic map (
      address_bits => address_bits,
      data_bits    => data_bits,
      write_first  => false
    )
    port map (
      -- Port A
      a_write    => write_enabled,
      a_address  => bram_address(2*i),
      a_data_in  => write_data,
      a_data_out => read_data(2*i),
      -- Port B
      b_write    => write_enabled,
      b_address  => bram_address(2*i+1),
      b_data_in  => write_data,
      b_data_out => read_data(2*i+1),

      clock => clock
    );
  end generate;

  bram_last : if read_ports mod 2 = 1 generate
    bram_last : entity work.bram_tdp
    generic map (
      address_bits => address_bits,
      data_bits    => data_bits,
      write_first  => false
    )
    port map (
      -- Port A
      a_write    => write_enabled,
      a_address  => bram_address(read_ports-1),
      a_data_in  => write_data,
      a_data_out => read_data(read_ports-1),
      -- Port B
      b_write    => '0',
      b_address  => bram_address(read_ports-1),
      b_data_in  => write_data,
      b_data_out => open,

      clock => clock
    );
  end generate;

end rtl;
