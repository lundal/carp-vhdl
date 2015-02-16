-------------------------------------------------------------------------------
-- Title      : Bit Counter 32
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : live_counter.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-16
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Calculates the number of ones in a 32 bit signal in one cycle.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-16  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bit_counter_32 is
  port (
    input : in  std_logic_vector(31 downto 0);
    count : out std_logic_vector(5 downto 0);

    clock : in std_logic
  );
end entity;

architecture rtl of bit_counter_32 is

  -- Super efficient bit counter for Spartan-6
  -- https://groups.google.com/forum/#!topic/comp.lang.vhdl/Uv5CzwMz9MI

  function vec32_sum3(in_vec : in unsigned) return unsigned is
    type leaf_type is array (0 to 63) of unsigned(2 downto 0);
    -- Each ROM entry is sum of address bits:
    constant leaf_rom : leaf_type := (
    "000", "001", "001", "010", "001", "010", "010", "011",
    "001", "010", "010", "011", "010", "011", "011", "100",
    "001", "010", "010", "011", "010", "011", "011", "100",
    "010", "011", "011", "100", "011", "100", "100", "101",
    "001", "010", "010", "011", "010", "011", "011", "100",
    "010", "011", "011", "100", "011", "100", "100", "101",
    "010", "011", "011", "100", "011", "100", "100", "101",
    "011", "100", "100", "101", "100", "101", "101", "110");

    type S3_type is array (0 to 4) of unsigned(2 downto 0);
    variable S3 : S3_type;

    variable result    : unsigned( 5 downto 0 );
    variable leaf_bits : natural range 0 to 63;
    variable S4_1      : unsigned( 3 downto 0 );
    variable S4_2      : unsigned( 3 downto 0 );
    variable S5_1      : unsigned( 4 downto 0 );
  begin
    -- Form five 3-bit sums using three 6-LUTs each:
    for i in 0 to 4 loop
      leaf_bits := to_integer(unsigned(in_vec(6 * i + 5 downto 6 * i)));
      S3(i)     := leaf_rom(leaf_bits);
    end loop;
    -- Add two 3-bit sums + leftover leaf bits as a carry in to get 4 bit sums:
    S4_1 := ("0"   & S3(0)) + ("0" & S3(1))
          + ("000" & in_vec(30));
    S4_2 := ("0"   & S3(2)) + ("0" & S3(3))
          + ("000" & in_vec(31));
    -- Add 4 bit sums to get 5 bit sum:
    S5_1 := ("0"  & S4_1) + ("0" & S4_2);
    -- Add leftover 3 bit sum to get 5 bit result:
    result := ("0"   & S5_1)
            + ("000" & S3(4));
    return result;
  end vec32_sum3;

begin

  process begin
    wait until rising_edge(clock);
    count <= std_logic_vector(vec32_sum3(unsigned(input)));
  end process;

end architecture;

