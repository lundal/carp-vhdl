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
    cell_write_width : positive := 4;
    send_buffer_address_bits : positive := 10
  );
  port (
    buffer_address      : out std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
    buffer_types_write  : out std_logic;
    buffer_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_states_write : out std_logic;
    buffer_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    buffer_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    send_buffer_data  : out std_logic_vector(31 downto 0);
    send_buffer_count : in  std_logic_vector(send_buffer_address_bits - 1 downto 0);
    send_buffer_write : out std_logic;

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
    IDLE, FILL, WRITE_STATE_OR_TYPE, SEND_ONE, SEND_ALL
  );

  signal state : state_type := IDLE;

  -- Fill signals
  signal state_repeated : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal type_repeated  : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);

  -- Combined signals
  signal combined_state  : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal combined_states : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal combined_type   : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
  signal combined_types  : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);

  -- Shifted signals
  signal shifted_states : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal shifted_types  : std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);

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
    send_buffer_data    <= (others => '0');
    send_buffer_write   <= '0';

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
            when WRITE_STATE_ONE | WRITE_STATE_ROW | WRITE_TYPE_ONE | WRITE_TYPE_ROW =>
              state <= WRITE_STATE_OR_TYPE;
            when READ_STATE_ONE | READ_TYPE_ONE =>
              state <= SEND_ONE;
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
            buffer_states_out <= combined_state;
          when WRITE_STATE_ROW =>
            buffer_states_out <= combined_states;
          when WRITE_TYPE_ONE =>
            buffer_types_out <= combined_type;
          when WRITE_TYPE_ROW =>
            buffer_types_out <= combined_types;
          when others =>
            null;
        end case;

        buffer_types_write <= '1';

        state <= IDLE;
        done_i <= '1';

      when SEND_ONE =>
        send_buffer_write <= '1';

        case operation is
          when READ_STATE_ONE =>
            send_buffer_data(cell_state_bits - 1 downto 0) <= shifted_states(cell_state_bits - 1 downto 0);
          when READ_TYPE_ONE =>
            send_buffer_data(cell_type_bits - 1 downto 0) <= shifted_types(cell_type_bits - 1 downto 0);
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

  -- Shifters
  shifter_state : entity work.shifter_dynamic
  generic map (
    data_width         => matrix_width*cell_state_bits,
    shift_amount_width => bits(matrix_width),
    shift_unit         => cell_state_bits
  )
  port map (
    data_in      => buffer_states_in,
    data_out     => shifted_states,
    left         => '0',
    arithmetic   => '0',
    shift_amount => address_x
  );

  shifter_type : entity work.shifter_dynamic
  generic map (
    data_width         => matrix_width*cell_type_bits,
    shift_amount_width => bits(matrix_width),
    shift_unit         => cell_type_bits
  )
  port map (
    data_in      => buffer_types_in,
    data_out     => shifted_types,
    left         => '0',
    arithmetic   => '0',
    shift_amount => address_x
  );

  -- Internally used out ports
  buffer_address <= address_zy;
  done <= done_i;

end rtl;
