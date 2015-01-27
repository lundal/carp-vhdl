-------------------------------------------------------------------------------
-- Title      : Cell Writer Reader
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : cell_writer_reader.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Writes cell data to buffer and sends cell data to host.
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
use work.types.all;

entity cell_writer_reader is
  generic (
    matrix_width     : positive := 8;
    matrix_height    : positive := 8;
    matrix_depth     : positive := 8;
    cell_type_bits   : positive := 8;
    cell_state_bits  : positive := 1;
    cell_write_width : positive := 4
  );
  port (
    buffer_address      : out std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
    buffer_types_write  : out std_logic;
    buffer_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_states_write : out std_logic;
    buffer_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    buffer_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    decode_operation : in cell_writer_reader_operation_type;
    decode_zyx       : in std_logic_vector(bits(matrix_depth) + bits(matrix_height) + bits(matrix_width) - 1 downto 0);
    decode_state     : in std_logic_vector(cell_state_bits - 1 downto 0);
    decode_states    : in std_logic_vector(cell_write_width*cell_state_bits - 1 downto 0);
    decode_type      : in std_logic_vector(cell_type_bits - 1 downto 0);
    decode_types     : in std_logic_vector(cell_write_width*cell_type_bits - 1 downto 0);

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end cell_writer_reader;

architecture rtl of cell_writer_reader is

  type state_type is (
    IDLE, FILL, WRITE_STATE_OR_TYPE, SEND
  );

  signal state : state_type := IDLE;

  -- Fill signals
  signal state_repeated : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal type_repeated  : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);

  -- Combined signals
  signal combined_type   : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal combined_types  : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal combined_state  : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal combined_states : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

  -- Input registers
  signal operation  : cell_writer_reader_operation_type;
  signal address_zy : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal address_x  : std_logic_vector(bits(matrix_width) - 1 downto 0);
  signal state_new  : std_logic_vector(cell_state_bits - 1 downto 0);
  signal states_new : std_logic_vector(cell_write_width*cell_state_bits - 1 downto 0);
  signal type_new   : std_logic_vector(cell_type_bits - 1 downto 0);
  signal types_new  : std_logic_vector(cell_write_width*cell_type_bits - 1 downto 0);

  -- Internally used out ports
  signal done_i : std_logic := '1';

begin

  repeated : for i in 0 to matrix_width - 1 generate
    state_repeated((i+1)*cell_state_bits - 1 downto i*cell_state_bits) <= decode_state;
    type_repeated((i+1)*cell_type_bits - 1 downto i*cell_type_bits) <= decode_type;
  end generate;

  process begin
    wait until rising_edge(clock);

    -- Defaults
    buffer_types_write  <= '0';
    buffer_states_write <= '0';

    case state is

      when IDLE =>
        if (run = '1') then
          done_i <= '0';

          -- Copy values
          operation  <= decode_operation;
          address_zy <= decode_zyx(bits(matrix_depth) + bits(matrix_height) + bits(matrix_width) - 1 downto bits(matrix_width));
          address_x  <= decode_zyx(bits(matrix_width) - 1 downto 0);
          state_new  <= decode_state;
          states_new <= decode_states;
          type_new   <= decode_type;
          types_new  <= decode_types;

          case decode_operation is
            when FILL_ALL =>
              address_zy          <= (others => '0');
              buffer_types_out    <= type_repeated;
              buffer_types_write  <= '1';
              buffer_states_out   <= state_repeated;
              buffer_states_write <= '1';
              state <= FILL;
            when WRITE_STATE_ONE =>
              state <= WRITE_STATE_OR_TYPE;
            when WRITE_STATE_ROW =>
              state <= WRITE_STATE_OR_TYPE;
            when WRITE_TYPE_ONE =>
              state <= WRITE_STATE_OR_TYPE;
            when WRITE_TYPE_ROW =>
              state <= WRITE_STATE_OR_TYPE;
            when others =>
              done_i <= '1';
          end case;
        end if;

      when FILL =>
        -- Iterate through buffer
        address_zy          <= std_logic_vector(unsigned(address_zy) + 1);
        buffer_types_write  <= '1';
        buffer_states_write <= '1';
        if (unsigned(address_zy) + 1 = matrix_depth*matrix_height - 1) then
          state <= IDLE;
          done_i <= '1';
        end if;

      when WRITE_STATE_OR_TYPE =>
        case operation is
          when WRITE_STATE_ONE =>
            buffer_states_out   <= combined_state;
            buffer_states_write <= '1';
          when WRITE_STATE_ROW =>
            buffer_states_out   <= combined_states;
            buffer_states_write <= '1';
          when WRITE_TYPE_ONE =>
            buffer_types_out   <= combined_type;
            buffer_types_write <= '1';
          when WRITE_TYPE_ROW =>
            buffer_types_out   <= combined_types;
            buffer_types_write <= '1';
          when others =>
            null;
        end case;

        state <= IDLE;
        done_i <= '1';

      when others =>
       null;

    end case;
  end process;

  -- Combiners
  combine_with_type : entity work.combiner
  generic map (
    data_width     => matrix_width*cell_type_bits,
    data_new_width => cell_type_bits,
    offset_width   => bits(matrix_width),
    offset_unit    => cell_type_bits,
    offset_to_left => true
  )
  port map (
    data_original => buffer_types_in,
    data_new      => type_new,
    data_combined => combined_type,
    offset        => address_x
  );

  combine_with_types : entity work.combiner
  generic map (
    data_width     => matrix_width*cell_type_bits,
    data_new_width => cell_write_width*cell_type_bits,
    offset_width   => bits(matrix_width),
    offset_unit    => cell_type_bits,
    offset_to_left => true
  )
  port map (
    data_original => buffer_types_in,
    data_new      => types_new,
    data_combined => combined_types,
    offset        => address_x
  );

  combine_with_state : entity work.combiner
  generic map (
    data_width     => matrix_width*cell_state_bits,
    data_new_width => cell_state_bits,
    offset_width   => bits(matrix_width),
    offset_unit    => cell_state_bits,
    offset_to_left => true
  )
  port map (
    data_original => buffer_states_in,
    data_new      => state_new,
    data_combined => combined_state,
    offset        => address_x
  );

  combine_with_states : entity work.combiner
  generic map (
    data_width     => matrix_width*cell_state_bits,
    data_new_width => cell_write_width*cell_state_bits,
    offset_width   => bits(matrix_width),
    offset_unit    => cell_state_bits,
    offset_to_left => true
  )
  port map (
    data_original => buffer_states_in,
    data_new      => states_new,
    data_combined => combined_states,
    offset        => address_x
  );

  buffer_address <= address_zy;

  -- Internally used out ports
  done <= done_i;

end rtl;
