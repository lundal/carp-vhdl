--------------------------------------------------------------------------------
-- Title       : Bit Counter N
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Calculates the number of ones in an N-bit signal in
--             : bits(input_bits) - 4 cycles.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity bit_counter_N is
  generic (
    input_bits : positive := 1024
  );
  port (
    input : in  std_logic_vector(input_bits - 1 downto 0);
    count : out std_logic_vector(bits(input_bits) downto 0);

    clock : in std_logic
  );
end entity;

architecture rtl of bit_counter_N is

  constant input_bits_next_pow2 : positive := 2**bits(input_bits);

  signal input_extended : std_logic_vector(input_bits_next_pow2 - 1 downto 0);

  signal count_A : std_logic_vector(bits(input_bits_next_pow2 / 2 + 1) - 1 downto 0);
  signal count_B : std_logic_vector(bits(input_bits_next_pow2 / 2 + 1) - 1 downto 0);

begin

  process (input) begin
    input_extended <= (others => '0');
    input_extended(input'range) <= input;
  end process;

  trival : if (input_bits_next_pow2 = 32) generate    
    bit_counter : entity work.bit_counter_32
    port map (
      input => input_extended,
      count => count,

      clock => clock
    );
  end generate;

  recurse : if (input_bits_next_pow2 > 32) generate
  
    bit_counter_A : entity work.bit_counter_N
    generic map (
      input_bits => input_bits_next_pow2 / 2
    )
    port map (
      input => input_extended(input_bits_next_pow2 - 1 downto input_bits_next_pow2 / 2),
      count => count_A,

      clock => clock
    );

    bit_counter_B : entity work.bit_counter_N
    generic map (
      input_bits => input_bits_next_pow2 / 2
    )
    port map (
      input => input_extended(input_bits_next_pow2 / 2 - 1 downto 0),
      count => count_B,

      clock => clock
    );

    process begin
      wait until rising_edge(clock);
      count <= std_logic_vector(unsigned('0' & count_A) + unsigned('0' & count_B));
    end process;

  end generate;

end architecture;
