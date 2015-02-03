-------------------------------------------------------------------------------
-- Title      : Decode
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : decode.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Instruction decoder
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-23  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.instructions.all;
use work.types.all;

entity decode is
  generic (
    matrix_width     : positive := 8;
    matrix_height    : positive := 8;
    matrix_depth     : positive := 8;
    cell_type_bits   : positive := 8;
    cell_state_bits  : positive := 1;
    cell_write_width : positive := 8;
    instruction_bits : positive := 256
  );
  port (
    instruction : in std_logic_vector(instruction_bits - 1 downto 0);

    cell_writer_reader_operation : out cell_writer_reader_operation_type;
    cell_writer_reader_address_z : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    cell_writer_reader_address_y : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    cell_writer_reader_address_x : out std_logic_vector(bits(matrix_width) - 1 downto 0);
    cell_writer_reader_state     : out std_logic_vector(cell_state_bits - 1 downto 0);
    cell_writer_reader_states    : out std_logic_vector(cell_write_width*cell_state_bits - 1 downto 0);
    cell_writer_reader_type      : out std_logic_vector(cell_type_bits - 1 downto 0);
    cell_writer_reader_types     : out std_logic_vector(cell_write_width*cell_type_bits - 1 downto 0);

    cellular_automata_operation  : out cellular_automata_operation_type;
    cellular_automata_step_count : out std_logic_vector(15 downto 0);

    development_operation : out development_operation_type;

    lut_writer_operation : out lut_writer_operation_type;
    lut_writer_address   : out std_logic_vector(cell_type_bits - 1 downto 0);
    lut_writer_data      : out std_logic_vector(2**if_else(matrix_depth = 1, 5, 7) - 1 downto 0);

    cell_buffer_swap       : out std_logic;
    cell_buffer_mux_select : out cell_buffer_mux_select_type;
    send_buffer_mux_select : out send_buffer_mux_select_type;

    run  : in  std_logic;

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

  instruction_opcode <= instruction (4 downto 0);

  process begin
    wait until rising_edge(clock) and run = '1';

    -- Defaults
    cell_writer_reader_operation <= NOP;
    cellular_automata_operation <= NOP;
    development_operation <= NOP;
    lut_writer_operation <= NOP;
    cell_buffer_swap <= '0';

    case instruction_opcode is

      when INSTRUCTION_READ_STATE_ONE =>
        cell_writer_reader_operation <= READ_STATE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'left + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'left + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'left + 8 downto 8);
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_READ_STATE_ALL =>
        cell_writer_reader_operation <= READ_STATE_ALL;
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_READ_TYPE_ONE =>
        cell_writer_reader_operation <= READ_TYPE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'left + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'left + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'left + 8 downto 8);
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_READ_TYPE_ALL =>
        cell_writer_reader_operation <= READ_TYPE_ALL;
        send_buffer_mux_select       <= CELL_WRITER_READER;

      when INSTRUCTION_FILL_CELLS =>
        cell_writer_reader_operation <= FILL_ALL;
        cell_writer_reader_state     <= instruction(cell_writer_reader_state'left + 8 downto 8);
        cell_writer_reader_type      <= instruction(cell_writer_reader_type'left + 16 downto 16);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_STATE_ONE =>
        cell_writer_reader_operation <= WRITE_STATE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'left + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'left + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'left + 8 downto 8);
        cell_writer_reader_state     <= instruction(cell_writer_reader_state'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_STATE_ROW =>
        cell_writer_reader_operation <= WRITE_STATE_ROW;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'left + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'left + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'left + 8 downto 8);
        cell_writer_reader_states    <= instruction(cell_writer_reader_states'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_TYPE_ONE =>
        cell_writer_reader_operation <= WRITE_TYPE_ONE;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'left + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'left + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'left + 8 downto 8);
        cell_writer_reader_type      <= instruction(cell_writer_reader_type'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_TYPE_ROW =>
        cell_writer_reader_operation <= WRITE_TYPE_ROW;
        cell_writer_reader_address_z <= instruction(cell_writer_reader_address_z'left + 24 downto 24);
        cell_writer_reader_address_y <= instruction(cell_writer_reader_address_y'left + 16 downto 16);
        cell_writer_reader_address_x <= instruction(cell_writer_reader_address_x'left + 8 downto 8);
        cell_writer_reader_types     <= instruction(cell_writer_reader_types'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_SWAP_CELL_BUFFERS =>
        cell_buffer_swap <= '1';

      when INSTRUCTION_RUNSTEP =>
        cellular_automata_operation  <= STEP;
        cellular_automata_step_count <= instruction(cellular_automata_step_count'left + 16 downto 16);

      when INSTRUCTION_CONFIGURE_SBM =>
        cellular_automata_operation <= CONFIGURE;
        cell_buffer_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_READBACK_SBM =>
        cellular_automata_operation <= READBACK;
        cell_buffer_mux_select      <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_LUT =>
        lut_writer_operation <= STORE;
        lut_writer_address   <= instruction(lut_writer_address'left + 32 downto 32);
        lut_writer_data      <= instruction(lut_writer_data'left + 64 downto 64);

      when INSTRUCTION_DEVSTEP =>
        development_operation  <= DEVELOP;
        cell_buffer_mux_select <= DEVELOPMENT;

      when others =>
        null;

    end case;
  end process;

end rtl;
