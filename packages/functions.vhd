-------------------------------------------------------------------------------
-- Title      : Function Package
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : functions.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
--            : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-29
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Various functions
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-29  4.2      lundal    Add bits, min and if_else functions
-- 2015-01-20  4.1      lundal    Removed unused functions
-- 2014-11-27  4.0      lundal    Added reverse_endian
-- 2014-02-10  3.0      stoevneng Added reverse
-- 2003-03-06  2.0      aamodt	  Updated
-- 2003-03-06  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package functions is

  -- Reverses the bit order in a signal
  function reverse (
    input : std_logic_vector
  ) return std_logic_vector;

  -- Reverses the byte order in a signal (width must be a multiple of 8)
  function reverse_endian (
    input : std_logic_vector
  ) return std_logic_vector;

  -- Calculates the number of bits required to represent a number
  function bits (
    input : positive
  ) return natural;

  -- Returns the least of two numbers
  function min (
    left  : integer;
    right : integer
  ) return integer;

  -- Allows conditionals in constant declarations
  function if_else (
    condition  : boolean;
    when_true  : integer;
    when_false : integer
  ) return integer;

  -- Converts boolean to std_logic
  function to_std_logic (
    input : boolean
  ) return std_logic;

  -- Converts std_logic to boolean
  function to_boolean (
    input : std_logic
  ) return boolean;

  -- Returns dividend / divisor rounded up
  function divide_ceil (
    dividend : integer;
    divisor  : integer
  ) return integer;

end functions;

package body functions is

  function reverse (
    input: std_logic_vector
  ) return std_logic_vector is
    variable result: std_logic_vector(input'RANGE);
    alias input_reversed: std_logic_vector(input'REVERSE_RANGE) is input;
  begin
    for i in input'RANGE loop
      result(i) := input_reversed(i);
    end loop;
    return result;
  end reverse;

  function reverse_endian (
    input : std_logic_vector
  ) return std_logic_vector is
    variable output    : std_logic_vector(input'range);
    constant num_bytes : natural := input'length / 8;
  begin
    for i in 0 to num_bytes-1 loop
      for j in 7 downto 0 loop
        output(8*i + j) := input(8*(num_bytes-1-i) + j);
      end loop;
    end loop;
    return output;
  end reverse_endian;

  function bits (
    input : positive
  ) return natural is
  begin
    return natural(ceil(log2(real(input))));
  end bits;

  function min (
    left : integer;
    right : integer
  ) return integer is
  begin
    if left < right then
      return left;
    else
      return right;
    end if;
  end min;

  function if_else (
    condition  : boolean;
    when_true  : integer;
    when_false : integer
  ) return integer is
  begin
    if (condition) then
      return when_true;
    else
      return when_false;
    end if;
  end if_else;

  function to_std_logic (
    input : boolean
  ) return std_logic is
  begin
    if (input) then
      return '1';
    else
      return '0';
    end if;
  end to_std_logic;

  function to_boolean (
    input : std_logic
  ) return boolean is
  begin
    return input = '1';
  end to_boolean;

  function divide_ceil (
    dividend : integer;
    divisor  : integer
  ) return integer is
  begin
    if (dividend mod divisor /= 0) then
      return dividend / divisor + 1;
    else
      return dividend / divisor;
    end if;
  end divide_ceil;

end functions;
