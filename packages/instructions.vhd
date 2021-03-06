--------------------------------------------------------------------------------
-- Title       : Instructions
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Instruction opcodes
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package instructions is

  constant INSTRUCTION_NOP               : std_logic_vector(4 downto 0) := "00000";
  constant INSTRUCTION_READ_INFORMATION  : std_logic_vector(4 downto 0) := "00001";
  constant INSTRUCTION_READ_RULE_VECTOR  : std_logic_vector(4 downto 0) := "00010";
  constant INSTRUCTION_READ_RULE_NUMBERS : std_logic_vector(4 downto 0) := "00011";

  constant INSTRUCTION_READ_STATE_ONE    : std_logic_vector(4 downto 0) := "00100";
  constant INSTRUCTION_READ_STATE_ALL    : std_logic_vector(4 downto 0) := "00101";
  constant INSTRUCTION_READ_TYPE_ONE     : std_logic_vector(4 downto 0) := "00110";
  constant INSTRUCTION_READ_TYPE_ALL     : std_logic_vector(4 downto 0) := "00111";

  constant INSTRUCTION_WRITE_LUT         : std_logic_vector(4 downto 0) := "01000";
  constant INSTRUCTION_WRITE_RULE        : std_logic_vector(4 downto 0) := "01001";
  constant INSTRUCTION_SET_RULES_ACTIVE  : std_logic_vector(4 downto 0) := "01010";
  constant INSTRUCTION_FILL_CELLS        : std_logic_vector(4 downto 0) := "01011";

  constant INSTRUCTION_WRITE_STATE_ONE   : std_logic_vector(4 downto 0) := "01100";
  constant INSTRUCTION_WRITE_STATE_ROW   : std_logic_vector(4 downto 0) := "01101";
  constant INSTRUCTION_WRITE_TYPE_ONE    : std_logic_vector(4 downto 0) := "01110";
  constant INSTRUCTION_WRITE_TYPE_ROW    : std_logic_vector(4 downto 0) := "01111";

  constant INSTRUCTION_DEVELOP           : std_logic_vector(4 downto 0) := "10000";
  constant INSTRUCTION_STEP              : std_logic_vector(4 downto 0) := "10001";
  constant INSTRUCTION_CONFIGURE         : std_logic_vector(4 downto 0) := "10010";
  constant INSTRUCTION_READBACK          : std_logic_vector(4 downto 0) := "10011";

  constant INSTRUCTION_SWAP_CELL_BUFFERS : std_logic_vector(4 downto 0) := "10100";
  constant INSTRUCTION_RESET_BUFFERS     : std_logic_vector(4 downto 0) := "10101";

  constant INSTRUCTION_FITNESS_READ      : std_logic_vector(4 downto 0) := "10110";

  constant INSTRUCTION_BREAK             : std_logic_vector(4 downto 0) := "11000";
  constant INSTRUCTION_STORE             : std_logic_vector(4 downto 0) := "11010";
  constant INSTRUCTION_END               : std_logic_vector(4 downto 0) := "11011";

  constant INSTRUCTION_JUMP              : std_logic_vector(4 downto 0) := "11100";
  constant INSTRUCTION_JUMP_EQUAL        : std_logic_vector(4 downto 0) := "11101";
  constant INSTRUCTION_COUNTER_INCREMENT : std_logic_vector(4 downto 0) := "11110";
  constant INSTRUCTION_COUNTER_RESET     : std_logic_vector(4 downto 0) := "11111";

end instructions;
