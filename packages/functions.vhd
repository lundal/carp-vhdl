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
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Various functions
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-20  4.1      lundal    Removed unused functions
-- 2014-11-27  4.0      lundal    Added reverse_endian
-- 2014-02-10  3.0      stoevneng Added reverse_slv
-- 2003-03-06  2.0      aamodt	  Updated
-- 2003-03-06  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package functions is

  -- reverses the bit order in a signal
  function reverse (
    a : std_logic_vector
  ) return std_logic_vector;

  -- reverses the byte order in a signal
  -- signal width must be a multiple of 8
  function reverse_endian (
    input : std_logic_vector
  ) return std_logic_vector;

end functions;

package body functions is

  function reverse (
    a: std_logic_vector
  ) return std_logic_vector is
    variable result: std_logic_vector(a'RANGE);
    alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
  begin
    for i in aa'RANGE loop
      result(i) := aa(i);
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

end functions;
