--------------------------------------------------------------------------------
-- Title       : Types
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Custom signal types
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package types is

  type cell_storage_mux_select_type is (
    WRITER_READER_AND_CELLULAR_AUTOMATA, DEVELOPMENT
  );

  type send_buffer_mux_select_type is (
    CELL_WRITER_READER, INFORMATION_SENDER, RULE_VECTOR_READER, RULE_NUMBERS_READER, FITNESS_SENDER
  );

  type information_sender_operation_type is (
    NOP, SEND
  );

  type cell_writer_reader_operation_type is (
    NOP, FILL_ALL,
    READ_STATE_ONE, READ_STATE_ALL, READ_TYPE_ONE, READ_TYPE_ALL,
    WRITE_STATE_ONE, WRITE_STATE_ROW, WRITE_TYPE_ONE, WRITE_TYPE_ROW
  );

  type cellular_automata_operation_type is (
    NOP, CONFIGURE, READBACK, STEP
  );

  type lut_writer_operation_type is (
    NOP, STORE
  );

  type rule_writer_operation_type is (
    NOP, STORE
  );

  type development_operation_type is (
    NOP, DEVELOP, SET_RULES_ACTIVE
  );

  type rule_vector_reader_operation_type is (
    NOP, READ_N
  );

  type rule_numbers_reader_operation_type is (
    NOP, READ_ALL
  );

  type fitness_sender_operation_type is (
    NOP, SEND
  );

  type cell_storage_operation_type is (
    NOP, SWAP
  );

  type resetter_operation_type is (
    NOP, RESET_BUFFERS
  );

end types;
