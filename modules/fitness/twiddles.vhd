-------------------------------------------------------------------------------
-- Title      : Twiddles
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : twiddles.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Calculates the twiddle factors required for DFT.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2015-02-20  1.0      lundal Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_complex.all;

library work;
use work.functions.all;

entity twiddles is
  generic (
    result_index_first  : natural  := 0;
    result_index_amount : positive := 2;
    transform_size      : positive := 128;
    twiddle_bits        : positive := 8;
    twiddle_precision   : positive := 6
  );
  port (
    index : in unsigned(bits(result_index_amount*transform_size) - 1 downto 0);

    twiddle_real : out signed(twiddle_bits - 1 downto 0);
    twiddle_imag : out signed(twiddle_bits - 1 downto 0);

    clock : in std_logic
  );
end entity;

architecture rtl of twiddles is

  type twiddles_type is array (0 to 2**index'length - 1)
    of signed(2*twiddle_bits - 1 downto 0);

  -- Calculates T(k,n,N)
  function calculate_twiddle (
    result_index   : natural;
    input_index    : natural;
    transform_size : natural
  ) return complex is
    constant i   : complex := math_cbase_j;
    constant tau : real    := math_2_pi;
    constant k   : real    := real(result_index);
    constant n   : real    := real(input_index);
    constant NN  : real    := real(transform_size);
  begin
    return exp((-i)*tau*k*n / NN);
  end function;

  -- Converts real into signed
  function to_signed (
    number    : real;
    size      : positive;
    precision : positive
  ) return signed is
  begin
    return to_signed(integer(number * real(2**precision)), size);
  end function;

  -- Generates an array of twiddles for a range of k's
  -- The real and imaginary parts of each twiddle is stored sequentially in each entry
  function generate_twiddles (
    result_index_first  : natural;
    result_index_amount : positive;
    transform_size      : positive;
    twiddle_bits        : positive;
    twiddle_precision   : positive
  ) return twiddles_type is
    variable twiddle  : complex;
    variable twiddles : twiddles_type := (others => (others => '0'));
    variable index    : natural := 0;
  begin
    for result_index in result_index_first to result_index_first + result_index_amount - 1 loop
      for input_index in 0 to transform_size - 1 loop
        index := (result_index - result_index_first)*transform_size + input_index;
        twiddle := calculate_twiddle(result_index, input_index, transform_size);
        twiddles(index) := to_signed(twiddle.re, twiddle_bits, twiddle_precision)
                         & to_signed(twiddle.im, twiddle_bits, twiddle_precision);
      end loop;
    end loop;
    return twiddles;
  end function;

  signal twiddles : twiddles_type := generate_twiddles(
    result_index_first, result_index_amount, transform_size, twiddle_bits, twiddle_precision
  );

begin

  process begin
    wait until rising_edge(clock);
    twiddle_real <= twiddles(to_integer(index))(2*twiddle_bits - 1 downto 1*twiddle_bits);
    twiddle_imag <= twiddles(to_integer(index))(1*twiddle_bits - 1 downto 0*twiddle_bits);
  end process;

end architecture;
