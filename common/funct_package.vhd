-------------------------------------------------------------------------------
-- Title      : Function Package
-- Project    : 
-------------------------------------------------------------------------------
-- File       : funct_package.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/02/10
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Functions
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/02/10  3.0      stoevneng Added reverse_slv
-- 2003/03/06  2.0      aamodt	  Updated
-- 2003/03/06  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

package funct_package is
  -- calculates the ceiling function
  function ceil (
    division : integer;
    modulo   : integer)
    return integer;

  -- convertes integer to std_logic_vector
  function to_slv (
    arg : integer;
    size : integer)
    return std_logic_vector;

--Kaa
  -- returning a vector padded with '0' in front
  function padded_array (
    input_vector  : std_logic_vector;
    input_width   : integer;
    output_width  : integer)
    return std_logic_vector;
--Kaa

  function reverse_slv (
    a : std_logic_vector)
    return std_logic_vector;

end funct_package;

-------------------------------------------------------------------------------

package body funct_package is

  
  function ceil (
    division : integer;
    modulo   : integer)
    return integer is

  begin
    if modulo > 0 then
      return division + 1;
    else
      return division;
    end if;
  end ceil;

  -----------------------------------------------------------------------------

  function to_slv (
    arg : integer;
    size : integer)
    return std_logic_vector is

  begin
    return std_logic_vector (to_unsigned (arg, size));
  end to_slv;

--Kaa
  -----------------------------------------------------------------------------
   function padded_array(
     input_vector  : std_logic_vector;
     input_width   : integer;
     output_width  : integer)
     return std_logic_vector is

     variable temp : std_logic_vector(output_width - 1 downto 0);
   begin

     if(input_width = output_width) then
       temp := input_vector;
      else
       temp(output_width - 1 downto input_width) := (others => '0');
       temp(input_width - 1 downto 0) := input_vector;
      end if;
     return temp;
   end padded_array;
--Kaa

  function reverse_slv (
    a: std_logic_vector)
    return std_logic_vector is
    variable result: std_logic_vector(a'RANGE);
    alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
  begin
    for i in aa'RANGE loop
      result(i) := aa(i);
    end loop;
    return result;
  end reverse_slv;

end funct_package;
