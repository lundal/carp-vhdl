-------------------------------------------------------------------------------
-- Title      : True Dual Port BRAM
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : bram_tdp.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2014-12-05
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: A true dual port BRAM inferrer with some extra logic to allow
--            : write-first mode to function across ports (see UG383 page 15)
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014-12-05  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_tdp is
  generic (
    address_bits : positive := 8;
    data_bits    : positive := 32;
    write_first  : boolean := true
  );
  port (
    -- Port A
    a_write    : in  std_logic;
    a_address  : in  std_logic_vector(address_bits - 1 downto 0);
    a_data_in  : in  std_logic_vector(data_bits - 1 downto 0);
    a_data_out : out std_logic_vector(data_bits - 1 downto 0);

    -- Port B
    b_write    : in  std_logic;
    b_address  : in  std_logic_vector(address_bits - 1 downto 0);
    b_data_in  : in  std_logic_vector(data_bits - 1 downto 0);
    b_data_out : out std_logic_vector(data_bits - 1 downto 0);

    clock : in std_logic
  );
end bram_tdp;

architecture rtl of bram_tdp is

  signal a_data_out_i : std_logic_vector(data_bits - 1 downto 0) := (others => '0');
  signal b_data_out_i : std_logic_vector(data_bits - 1 downto 0) := (others => '0');
  signal a_send_b     : boolean := false;
  signal b_send_a     : boolean := false;

  type memory_t is array((2**address_bits) - 1 downto 0) of std_logic_vector(data_bits - 1 downto 0);
  shared variable memory : memory_t := (others => (others => '0'));

begin

  -- Port A
  process begin
    wait until rising_edge(clock);

    if (not write_first) then
      a_data_out_i <= memory(to_integer(unsigned(a_address)));
    end if;

    if (a_write = '1') then
      memory(to_integer(unsigned(a_address))) := a_data_in;
    end if;

    if (write_first) then
      a_data_out_i <= memory(to_integer(unsigned(a_address)));
    end if;

  end process;

  -- Port B
  process begin
    wait until rising_edge(clock);

    if (not write_first) then
      b_data_out_i <= memory(to_integer(unsigned(b_address)));
    end if;

    if (b_write = '1') then
      memory(to_integer(unsigned(b_address))) := b_data_in;
    end if;

    if (write_first) then
      b_data_out_i <= memory(to_integer(unsigned(b_address)));
    end if;

  end process;

  -- Allows write-first mode to function across ports
  process begin
    wait until rising_edge(clock);

    if (write_first) then
      a_send_b <= (a_address = b_address) and a_write = '0' and b_write = '1';
      b_send_a <= (a_address = b_address) and a_write = '1' and b_write = '0';
    else
      a_send_b <= false;
      b_send_a <= false;
    end if;

  end process;

  a_data_out <= b_data_out_i when a_send_b else a_data_out_i;
  b_data_out <= a_data_out_i when b_send_a else b_data_out_i;

end rtl;
