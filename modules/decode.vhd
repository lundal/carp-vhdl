--------------------------------------------------------------------------------
-- Title       : Decode
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Decodes instructions into control signals and parameters
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.instructions.all;
use work.types.all;

entity decode is
  generic (
    matrix_width           : positive := 8;
    matrix_height          : positive := 8;
    matrix_depth           : positive := 8;
    cell_type_bits         : positive := 8;
    cell_state_bits        : positive := 1;
    cell_type_write_width  : positive := 8;
    cell_state_write_width : positive := 8;
    instruction_bits       : positive := 256;
    rule_amount            : positive := 256;
    rule_vector_amount     : positive := 64
  );
  port (
    instruction : in std_logic_vector(instruction_bits - 1 downto 0);

    information_sender_operation : out information_sender_operation_type;

    cell_writer_reader_operation : out cell_writer_reader_operation_type;
    cell_writer_reader_address_z : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    cell_writer_reader_address_y : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    cell_writer_reader_address_x : out std_logic_vector(bits(matrix_width) - 1 downto 0);
    cell_writer_reader_state     : out std_logic_vector(cell_state_bits - 1 downto 0);
    cell_writer_reader_states    : out std_logic_vector(cell_state_write_width*cell_state_bits - 1 downto 0);
    cell_writer_reader_type      : out std_logic_vector(cell_type_bits - 1 downto 0);
    cell_writer_reader_types     : out std_logic_vector(cell_type_write_width*cell_type_bits - 1 downto 0);

    cellular_automata_operation  : out cellular_automata_operation_type;
    cellular_automata_step_count : out std_logic_vector(15 downto 0);

    development_operation    : out development_operation_type;
    development_rules_active : out std_logic_vector(bits(rule_amount) - 1 downto 0);

    lut_writer_operation : out lut_writer_operation_type;
    lut_writer_address   : out std_logic_vector(cell_type_bits - 1 downto 0);
    lut_writer_data      : out std_logic_vector(2**if_else(matrix_depth = 1, 5, 7) - 1 downto 0);

    rule_writer_operation : out rule_writer_operation_type;
    rule_writer_address   : out std_logic_vector(bits(rule_amount) - 1 downto 0);
    rule_writer_data      : out std_logic_vector((cell_type_bits + 1 + cell_state_bits + 1) * if_else(matrix_depth = 1, 6, 8) - 1 downto 0);

    rule_vector_reader_operation : out rule_vector_reader_operation_type;
    rule_vector_reader_count     : out std_logic_vector(bits(rule_vector_amount) - 1 downto 0);

    rule_numbers_reader_operation : out rule_numbers_reader_operation_type;

    fitness_sender_operation : out fitness_sender_operation_type;

    cell_storage_operation : out cell_storage_operation_type;

    resetter_operation : out resetter_operation_type;

    cell_storage_mux_select : out cell_storage_mux_select_type;
    send_buffer_mux_select  : out send_buffer_mux_select_type;

    run : in std_logic;

    clock : in std_logic
  );
end decode;

architecture rtl of decode is

  signal instruction_opcode : std_logic_vector(4 downto 0);

begin

  -- Generic checks
  assert (matrix_width <= 256)  report "Unsupported matrix_width. Supported values are [2-256]."  severity FAILURE;
  assert (matrix_height <= 256) report "Unsupported matrix_height. Supported values are [1-256]." severity FAILURE;
  assert (matrix_depth <= 256)  report "Unsupported matrix_depth. Supported values are [1-256]."  severity FAILURE;
  assert (cell_type_bits <= 32) report "Unsupported cell_type_bits. Supported values are [1-32]."  severity FAILURE; -- Write LUT

  instruction_opcode <= instruction (4 downto 0);

  process begin
    wait until rising_edge(clock) and run = '1';

    -- Defaults
    information_sender_operation <= NOP;
    cell_writer_reader_operation <= NOP;
    cellular_automata_operation <= NOP;
    development_operation <= NOP;
    lut_writer_operation <= NOP;
    rule_writer_operation <= NOP;
    rule_vector_reader_operation <= NOP;
    rule_numbers_reader_operation <= NOP;
    fitness_sender_operation <= NOP;
    cell_storage_operation <= NOP;
    resetter_operation <= NOP;

    case instruction_opcode is

      when INSTRUCTION_READ_INFORMATION =>
        information_sender_operation <= SEND;
        send_buffer_mux_select       <= INFORMATION_SENDER;

      when INSTRUCTION_READ_STATE_ONE =>
        cell_writer_reader_operation <= READ_STATE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'high + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'high + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'high + 8 downto 8);
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_READ_STATE_ALL =>
        cell_writer_reader_operation <= READ_STATE_ALL;
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_READ_TYPE_ONE =>
        cell_writer_reader_operation <= READ_TYPE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'high + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'high + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'high + 8 downto 8);
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_READ_TYPE_ALL =>
        cell_writer_reader_operation <= READ_TYPE_ALL;
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_FILL_CELLS =>
        cell_writer_reader_operation <= FILL_ALL;
        cell_writer_reader_state     <= instruction(cell_writer_reader_state'high + 8 downto 8);
        cell_writer_reader_type      <= instruction(cell_writer_reader_type'high + 16 downto 16);
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_STATE_ONE =>
        cell_writer_reader_operation <= WRITE_STATE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'high + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'high + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'high + 8 downto 8);
        cell_writer_reader_state     <= instruction(cell_writer_reader_state'high + 32 downto 32);
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_STATE_ROW =>
        cell_writer_reader_operation <= WRITE_STATE_ROW;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'high + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'high + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'high + 8 downto 8);
        cell_writer_reader_states    <= instruction(cell_writer_reader_states'high + 32 downto 32);
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_TYPE_ONE =>
        cell_writer_reader_operation <= WRITE_TYPE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'high + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'high + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'high + 8 downto 8);
        cell_writer_reader_type      <= instruction(cell_writer_reader_type'high + 32 downto 32);
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_TYPE_ROW =>
        cell_writer_reader_operation <= WRITE_TYPE_ROW;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'high + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'high + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'high + 8 downto 8);
        cell_writer_reader_types     <= instruction(cell_writer_reader_types'high + 32 downto 32);
        cell_storage_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_SWAP_CELL_BUFFERS =>
        cell_storage_operation <= SWAP;

      when INSTRUCTION_STEP =>
        cellular_automata_operation  <= STEP;
        cellular_automata_step_count <= instruction(cellular_automata_step_count'high + 16 downto 16);

      when INSTRUCTION_CONFIGURE =>
        cellular_automata_operation <= CONFIGURE;
        cell_storage_mux_select     <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_READBACK =>
        cellular_automata_operation <= READBACK;
        cell_storage_mux_select     <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_LUT =>
        lut_writer_operation <= STORE;
        lut_writer_address   <= instruction(lut_writer_address'high + 32 downto 32);
        lut_writer_data      <= instruction(lut_writer_data'high + 64 downto 64);

      when INSTRUCTION_WRITE_RULE =>
        rule_writer_operation <= STORE;
        rule_writer_address   <= instruction(rule_writer_address'high + 32 downto 32);
        rule_writer_data      <= instruction(rule_writer_data'high + 64 downto 64);

      when INSTRUCTION_DEVELOP =>
        development_operation   <= DEVELOP;
        cell_storage_mux_select <= DEVELOPMENT;

      when INSTRUCTION_READ_RULE_VECTOR =>
        rule_vector_reader_operation <= READ_N;
        rule_vector_reader_count     <= instruction(rule_vector_reader_count'high + 16 downto 16);
        send_buffer_mux_select       <= RULE_VECTOR_READER;

      when INSTRUCTION_READ_RULE_NUMBERS =>
        rule_numbers_reader_operation <= READ_ALL;
        send_buffer_mux_select        <= RULE_NUMBERS_READER;

      when INSTRUCTION_SET_RULES_ACTIVE =>
        development_operation    <= SET_RULES_ACTIVE;
        development_rules_active <= instruction(development_rules_active'high + 16 downto 16);

      when INSTRUCTION_FITNESS_READ =>
        fitness_sender_operation <= SEND;
        send_buffer_mux_select   <= FITNESS_SENDER;

      when INSTRUCTION_RESET_BUFFERS =>
        resetter_operation <= RESET_BUFFERS;

      when others =>
        null;

    end case;
  end process;

end rtl;
