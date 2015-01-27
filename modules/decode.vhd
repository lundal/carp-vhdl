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
    cell_writer_reader_zyx       : out std_logic_vector(bits(matrix_depth) + bits(matrix_height) + bits(matrix_width) - 1 downto 0);
    cell_writer_reader_state     : out std_logic_vector(cell_state_bits - 1 downto 0);
    cell_writer_reader_states    : out std_logic_vector(cell_write_width*cell_state_bits - 1 downto 0);
    cell_writer_reader_type      : out std_logic_vector(cell_type_bits - 1 downto 0);
    cell_writer_reader_types     : out std_logic_vector(cell_write_width*cell_type_bits - 1 downto 0);

    cell_buffer_swap       : out std_logic;
    cell_buffer_mux_select : out cell_buffer_mux_select_type;

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end decode;

architecture rtl of decode is

  signal instruction_opcode : std_logic_vector(4 downto 0);

begin

  instruction_opcode <= instruction (4 downto 0);

  process begin
    wait until rising_edge(clock) and run = '1';

    -- Defaults
    cell_writer_reader_operation <= NOP;

    case instruction_opcode is

      when INSTRUCTION_FILL_CELLS =>
        cell_writer_reader_operation <= FILL_ALL;
        cell_writer_reader_state     <= instruction(cell_writer_reader_state'left + 8 downto 8);
        cell_writer_reader_type      <= instruction(cell_writer_reader_type'left + 16 downto 16);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_STATE_ONE =>
        cell_writer_reader_operation <= WRITE_STATE_ONE;
        cell_writer_reader_zyx       <= instruction(cell_writer_reader_zyx'left + 8 downto 8);
        cell_writer_reader_state     <= instruction(cell_writer_reader_state'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_STATE_ROW =>
        cell_writer_reader_operation <= WRITE_STATE_ROW;
        cell_writer_reader_zyx       <= instruction(cell_writer_reader_zyx'left + 8 downto 8);
        cell_writer_reader_states    <= instruction(cell_writer_reader_states'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_TYPE_ONE =>
        cell_writer_reader_operation <= WRITE_TYPE_ONE;
        cell_writer_reader_zyx       <= instruction(cell_writer_reader_zyx'left + 8 downto 8);
        cell_writer_reader_type      <= instruction(cell_writer_reader_type'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when INSTRUCTION_WRITE_TYPE_ROW =>
        cell_writer_reader_operation <= WRITE_TYPE_ROW;
        cell_writer_reader_zyx       <= instruction(cell_writer_reader_zyx'left + 8 downto 8);
        cell_writer_reader_types     <= instruction(cell_writer_reader_types'left + 32 downto 32);
        cell_buffer_mux_select       <= WRITER_READER_AND_CELLULAR_AUTOMATA;

      when others =>
        null;

    end case;
  end process;

  -- Always finishes in one cycle
  done <= '1';

end rtl;
