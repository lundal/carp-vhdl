-------------------------------------------------------------------------------
-- Title      : Constants
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : constants.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
--            : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Constants
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-20  3.1      lundal    Removed component declarations
-- 2014-05-19  3.0      stoevneng
-- 2005-05-23  2.0      aamodt 
-- 2003-01-17  1.1      djupdal
-- 2002-10-20  1.0      djupdal   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package constants is

  -- constants set by preprosessor

  constant COORD_SIZE_X : integer := 3;
  constant COORD_SIZE_Y : integer := 3;
  constant COORD_SIZE_Z : integer := 3;

  -- constants
  -- 5 for 2d and 7 for 3d
  constant NEIGH_SIZE : integer := 7;

  constant ROWS    : integer := 2 ** COORD_SIZE_Y;
  constant COLUMNS : integer := 2 ** COORD_SIZE_X;
  constant LAYERS  : integer := 2 ** COORD_SIZE_Z;

  constant LUT_SIZE  : integer := 2**NEIGH_SIZE;
  constant TYPE_SIZE : integer := 5; --max 8
  constant STATE_SIZE : integer := 1; --must be 1

  constant INSTR_ADDR_SIZE   : integer := 8;
  constant INSTR_SIZE        : integer := 192;

  constant RULE_SIZE         : integer := 89;--6*(TYPE_SIZE+STATE_SIZE+2)+1;
  -- Change this to change the maximum amount of rules:
  constant RULE_NBR_BUS_SIZE : integer := 8;
  -- Change this to change the amount of rules in a set:
  constant RULES_IN_SET_SIZE : integer := 2;
  -- Do not change these three:
  constant RULES_IN_SET      : integer := 2 ** RULES_IN_SET_SIZE;
  constant RULE_SET_SELECT_SIZE : integer := RULE_NBR_BUS_SIZE - RULES_IN_SET_SIZE;
  constant RULE_SETS_MAX     : integer := 2 ** RULE_SET_SELECT_SIZE;

  constant DEV_ROW_CYCLES_SIZE : integer := COORD_SIZE_X - 3;
  -- How many cycles are spent to develop one row of cells
  constant DEV_ROW_CYCLES : integer := 2 ** DEV_ROW_CYCLES_SIZE;
  constant DEV_PAR_SIZE : integer := COORD_SIZE_X - 1;
  -- How many cells are developed concurrently
  constant DEV_PARALLELITY : integer := 2**DEV_PAR_SIZE;

  -- SBM BRAM addr bus size
  constant ADDR_BUS_SIZE : integer := COORD_SIZE_Y + COORD_SIZE_Z - 2;

  -- for memory contain data generated on run-steps
  -- address bus can be changed to expand the numbers of values that can be stored
  constant RUN_STEP_ADDR_BUS_SIZE : integer := 13;
  constant RUN_STEP_DATA_BUS_SIZE : integer := COORD_SIZE_X + COORD_SIZE_Y + COORD_SIZE_Z + 1;

  -- for BRAM used to store fired rules for many dev-steps
  -- can NOT be changed, BRAM not dynamic
  constant RULEVECTOR_ADDR_BUS_SIZE : integer := 8;
  constant RULEVECTOR_DATA_BUS_SIZE : integer := 256;

  -- for BRAM used to store fired rules for one dev-step
  constant USEDRULES_ADDR_BUS_SIZE : integer := COORD_SIZE_Y + COORD_SIZE_Z + 1;
  constant USEDRULES_DATA_BUS_SIZE : integer := RULE_NBR_BUS_SIZE * DEV_PARALLELITY;

  -- for fitness result storage
  constant FITNESS_RESULT_SIZE  : integer := 4 * 32; 
  constant FITNESS_DATA_BUS_SIZE: integer := 32;

  -- How many cells are configured per cycle
  constant LUTCONVS_PER_CYCLE : integer := COLUMNS/8;

  -- How many types/states per word in the SBM BRAM
  constant ENTRIES_PER_WORD : integer := COLUMNS/2;

  -- The number of words of cell data that is developed at a time.  
  constant PARALLEL_DEV_WORDS : integer := DEV_PARALLELITY / ENTRIES_PER_WORD;

  -- SBM BRAM's type and state bus sizes.
  constant TYPE_BUS_SIZE  : integer := TYPE_SIZE * ENTRIES_PER_WORD;
  constant STATE_BUS_SIZE : integer := STATE_SIZE * ENTRIES_PER_WORD;

  -- How many BRAM module per BRAM-A and BRAM-B.
  constant SBM_BRAM_MODULES : integer := 8;

  constant SRL_IN_SIZE  : integer := 4;
  --The size of the inferred SRL modules.
  constant SRL_LENGTH   : integer := 2**SRL_IN_SIZE;
  constant SRLS_PER_LUT : integer := (2**NEIGH_SIZE)/SRL_LENGTH;

  constant LUTCONV_SELECT_SIZE : integer := 3;
  -- The number of parts the LUTs are split up in in the memory.
  constant LUTCONV_READS_PER_LUT : integer := 2 ** LUTCONV_SELECT_SIZE;
  -- How much of a LUT is read at a time
  constant LUTCONV_READ_SIZE : integer := LUT_SIZE / LUTCONV_READS_PER_LUT;
  -- How many read ports the LUTconv needs.
  constant LUTCONV_READS_PER_CYCLE : integer := LUTCONVS_PER_CYCLE * LUTCONV_READS_PER_LUT;

  -- How many cells are configured concurrently
  constant SBM_CFG_SIZE : integer := LUTCONVS_PER_CYCLE * SRL_LENGTH;
  -- How many states are read back to BRAM1 each cycle
  constant SBM_RDB_SIZE : integer := ENTRIES_PER_WORD * SBM_BRAM_MODULES * 2;
  constant RSF_READS_SIZE : integer := 2;
  -- How many cycles the RSF spends reading states each run step.
  constant RSF_READS    : integer := 2**RSF_READS_SIZE;
  -- How many states are read by the RSF each cycle
  constant SBM_FNK_SIZE : integer := ROWS * COLUMNS * LAYERS / RSF_READS;
  -- bits required to represent SBM_FNK_SIZE
  constant RSF_VAL_SIZE : integer := COORD_SIZE_X + COORD_SIZE_Y + COORD_SIZE_Z + 1 - RSF_READS_SIZE;--13;
  -- very dependent on RSF_VAL_SIZE:
  --  6-8->1, 9-10->2, 11-12->3, 13-14->4, 15-16->5 and so on.
  constant RSF_PIPE_LEN : integer := (RSF_VAL_SIZE - 5)/2;

  -- How many words needs to be read back to BRAM1 to read all the states
  constant READBACK_WORDS : integer := 
    integer(ceil(real(ROWS * COLUMNS * LAYERS) / real(SBM_RDB_SIZE)));
  -- How many times the config unit must config SBM_CFG_SIZE cells to configure the whole matrix
  constant CONFIG_WORDS : integer := 
    integer(ceil(real(ROWS * COLUMNS * LAYERS) / real(SBM_CFG_SIZE)));

  -----------------------------------------------------------------------------
  -- types

  type rule_set_t is array (RULES_IN_SET - 1 downto 0)
    of std_logic_vector(RULE_SIZE - 1 downto 0);

  type exec_result_type_t is array (RULES_IN_SET - 1 downto 0)
    of std_logic_vector(TYPE_SIZE - 1 downto 0);

  type selected_rule_t is array(DEV_PARALLELITY - 1 downto 0) 
    of std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);

  type bram_addr_t is array (SBM_BRAM_MODULES * 2 - 1 downto 0)
    of std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);

  type bram_type_bus_t is array (SBM_BRAM_MODULES * 2 - 1 downto 0)
    of std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);

  type bram_state_bus_t is array (SBM_BRAM_MODULES * 2 - 1 downto 0)
    of std_logic_vector(STATE_BUS_SIZE - 1 downto 0);

  type bram_addr_half_t is array (SBM_BRAM_MODULES - 1 downto 0)
    of std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);

  type bram_type_bus_half_t is array (SBM_BRAM_MODULES - 1 downto 0)
    of std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);

  type bram_state_bus_half_t is array (SBM_BRAM_MODULES - 1 downto 0)
    of std_logic_vector(STATE_BUS_SIZE - 1 downto 0);

  type lutconv_type_bus_t is array (LUTCONV_READS_PER_CYCLE - 1 downto 0)
    of std_logic_vector(TYPE_SIZE - 1 downto 0);

  type lutconv_lut_bus_t is array (LUTCONV_READS_PER_CYCLE - 1 downto 0)
    of std_logic_vector(LUTCONV_READ_SIZE - 1 downto 0);

  type rule_type_t is array (NEIGH_SIZE - 1 downto 0) 
    of std_logic_vector(TYPE_SIZE - 1 downto 0);

  -----------------------------------------------------------------------------
  -- DFT Constants
  -- Must be numbers and not expressions for twiddle_generator.py to work

  -- Twiddle factor precision
  constant TW_PRES      : integer := 6;
  -- Number of values in DFT input
  constant DFT_SIZE	    : integer := 128;
  -- The logarithm of how many DSPS are used
  constant DFT_LG_DSPS  : integer := 5;

    --------------------------------------------------------------

  constant TWIDDLE_SIZE : integer := (TW_PRES+2)*2;
  constant DFT_DSPS     : integer := 2**DFT_LG_DSPS;
  constant PERDSP	      : integer := DFT_SIZE/DFT_DSPS;
  constant VALSIZE	    : integer := 18;
  constant TWLEN        : integer := 16;
  constant DFT_INW      : integer := RUN_STEP_DATA_BUS_SIZE;

  type dft_res_t is array(0 to DFT_SIZE/2-1) of STD_LOGIC_VECTOR (18-1 downto 0);

end constants;
