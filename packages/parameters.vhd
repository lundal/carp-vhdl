-------------------------------------------------------------------------------
-- Title      : Parameters
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : parameters.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Default parameters for toplevel generics
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-03-22  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package parameters is

  constant COMMUNICATION_BUFFER_SIZE_LG : positive := 10; -- PCIe packet length field is 10 bits
  constant COMMUNICATION_REVERSE_ENDIAN : boolean  := true; -- Required for x86 systems
  constant PROGRAM_COUNTER_BITS         : positive := 8;
  constant MATRIX_WIDTH                 : positive := 10;
  constant MATRIX_HEIGHT                : positive := 10;
  constant MATRIX_DEPTH                 : positive := 8;
  constant MATRIX_WRAP                  : boolean  := true;
  constant TYPE_BITS                    : positive := 8;
  constant STATE_BITS                   : positive := 1; -- Must be 1 due to implementation of CA
  constant COUNTER_AMOUNT               : positive := 4;
  constant COUNTER_BITS                 : positive := 16;
  constant INSTRUCTION_BITS             : positive := 256; -- Must be 256 due to implementation of fetch_communication
  constant LUT_CONFIGURATION_BITS       : positive := 1; -- Max 2 for 2D and 8 for 3D to use integrated shift registers
  constant RULE_AMOUNT                  : positive := 256;
  constant RULES_TESTED_IN_PARALLEL     : positive := 8;
  constant RULE_VECTOR_BUFFER_SIZE      : positive := 32;
  constant LIVE_COUNT_BUFFER_SIZE       : positive := 256;
  constant FITNESS_BUFFER_SIZE          : positive := 256;

end parameters;
