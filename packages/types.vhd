-------------------------------------------------------------------------------
-- Title      : Types
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : types.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Signal types
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-23  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package types is

  type cell_buffer_mux_select_type is (
    WRITER_READER_AND_CELLULAR_AUTOMATA, DEVELOPMENT
  );

end types;
