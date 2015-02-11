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
    buffer_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    buffer_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
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
    decode_address_z : in std_logic_vector(bits(matrix_depth) - 1 downto 0);
    decode_address_y : in std_logic_vector(bits(matrix_height) - 1 downto 0);
    decode_address_x : in std_logic_vector(bits(matrix_width) - 1 downto 0);
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

  constant states_per_word     : positive := min(matrix_width, 32/cell_state_bits);
  constant state_words_per_row : positive := matrix_width / states_per_word;
  constant types_per_word      : positive := min(matrix_width, 32/cell_type_bits);
  constant type_words_per_row  : positive := matrix_width / types_per_word;

  type state_type is (
    IDLE, FILL, WRITE_STATE, WRITE_TYPE, SEND_ONE, SEND_ALL_STATES, SEND_ALL_TYPES
  );

  signal state : state_type := IDLE;

  -- Send buffer input source
  type send_buffer_source_type is (STATE_ONE, STATE_ROW, TYPE_ONE, TYPE_ROW);
  signal send_buffer_source : send_buffer_source_type;

  -- Buffer checks
  signal buffer_has_space_one : boolean;

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
  signal shift_amount   : std_logic_vector(bits(matrix_width) - 1 downto 0);

  -- Input registers
  signal operation  : cell_writer_reader_operation_type;
  signal address_z  : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal address_y  : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal address_x  : std_logic_vector(bits(matrix_width) - 1 downto 0);
  signal state_new  : std_logic_vector(cell_state_bits - 1 downto 0);
  signal states_new : std_logic_vector(cell_write_width*cell_state_bits - 1 downto 0);
  signal type_new   : std_logic_vector(cell_type_bits - 1 downto 0);
  signal types_new  : std_logic_vector(cell_write_width*cell_type_bits - 1 downto 0);

  -- Cell buffer source
  type buffer_source_type is (ONE, ROW, REPEATED);
  signal buffer_source : buffer_source_type;

  -- Internally used out ports
  signal done_i : std_logic := '1';

begin

  -- Generic checks
  assert (cell_type_bits <= 32) report "Unsupported cell_type_bits. Supported values are [1-32]." severity FAILURE;

  buffer_has_space_one <= signed(send_buffer_count) /= -1;

  repeated_states_and_types : for i in 0 to matrix_width - 1 generate
    state_repeated((i+1)*cell_state_bits - 1 downto i*cell_state_bits) <= decode_state;
    type_repeated((i+1)*cell_type_bits - 1 downto i*cell_type_bits) <= decode_type;
  end generate;

  process begin
    wait until rising_edge(clock);

    -- Defaults
    buffer_types_write  <= '0';
    buffer_states_write <= '0';
    send_buffer_write   <= '0';

    case state is

      when IDLE =>
        if (run = '1') then
          done_i <= '0';

          -- Copy values
          operation  <= decode_operation;
          address_z  <= decode_address_z;
          address_y  <= decode_address_y;
          address_x  <= decode_address_x;
          state_new  <= decode_state;
          states_new <= decode_states;
          type_new   <= decode_type;
          types_new  <= decode_types;

          case decode_operation is
            when FILL_ALL =>
              address_z <= (others => '0');
              address_y <= (others => '0');
              buffer_source <= REPEATED;
              buffer_types_write  <= '1';
              buffer_states_write <= '1';
              state <= FILL;
            when WRITE_STATE_ONE | WRITE_STATE_ROW =>
              state <= WRITE_STATE;
            when WRITE_TYPE_ONE | WRITE_TYPE_ROW =>
              state <= WRITE_TYPE;
            when READ_STATE_ONE | READ_TYPE_ONE =>
              state <= SEND_ONE;
            when READ_STATE_ALL =>
              address_z <= (others => '0');
              address_y <= (others => '0');
              address_x <= (others => '0');
              state <= SEND_ALL_STATES;
            when READ_TYPE_ALL =>
              address_z <= (others => '0');
              address_y <= (others => '0');
              address_x <= (others => '0');
              state <= SEND_ALL_TYPES;
            when others =>
              done_i <= '1';
          end case;
        end if;

      when FILL =>
        buffer_types_write  <= '1';
        buffer_states_write <= '1';
        -- Iterate through buffer
        address_y <= std_logic_vector(unsigned(address_y) + 1);
        if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
          address_z <= std_logic_vector(unsigned(address_z) + 1);
          if (unsigned(address_z) = matrix_depth-1 or matrix_depth = 1) then
            state <= IDLE;
            done_i <= '1';
          end if;
        end if;

      when WRITE_STATE =>
        case operation is
          when WRITE_STATE_ONE =>
            buffer_source <= ONE;
          when WRITE_STATE_ROW =>
            buffer_source <= ROW;
          when others =>
            null;
        end case;

        buffer_states_write <= '1';
        state <= IDLE;
        done_i <= '1';

      when WRITE_TYPE =>
        case operation is
          when WRITE_TYPE_ONE =>
            buffer_source <= ONE;
          when WRITE_TYPE_ROW =>
            buffer_source <= ROW;
          when others =>
            null;
        end case;

        buffer_types_write <= '1';
        state <= IDLE;
        done_i <= '1';

      when SEND_ONE =>
        case operation is
          when READ_STATE_ONE =>
            send_buffer_source <= STATE_ONE;
          when READ_TYPE_ONE =>
            send_buffer_source <= TYPE_ONE;
          when others =>
            null;
        end case;

        if (buffer_has_space_one) then
          send_buffer_write <= '1';
          state <= IDLE;
          done_i <= '1';
        end if;

      when SEND_ALL_STATES =>
        if (buffer_has_space_one) then
          send_buffer_source <= STATE_ROW;
          send_buffer_write <= '1';
          shift_amount <= address_x;
          -- Iterate in raster order (x, then y, then z)
          -- Fit as many as possible in each word, but align between each state and row
          if (unsigned(address_x) = states_per_word*state_words_per_row - states_per_word) then
            address_x <= (others => '0');
            address_y <= std_logic_vector(unsigned(address_y) + 1);
            if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
              address_z <= std_logic_vector(unsigned(address_z) + 1);
              if (unsigned(address_z) = matrix_depth-1 or matrix_depth = 1) then
                state <= IDLE;
                done_i <= '1';
              end if;
            end if;
          else
            address_x <= std_logic_vector(unsigned(address_x) + states_per_word);
          end if;
        end if;

      when SEND_ALL_TYPES =>
        if (buffer_has_space_one) then
          send_buffer_source <= TYPE_ROW;
          send_buffer_write <= '1';
          shift_amount <= address_x;
          -- Iterate in raster order (x, then y, then z)
          -- Fit as many as possible in each word, but align between each type and row
          if (unsigned(address_x) = types_per_word*type_words_per_row - types_per_word) then
            address_x <= (others => '0');
            address_y <= std_logic_vector(unsigned(address_y) + 1);
            if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
              address_z <= std_logic_vector(unsigned(address_z) + 1);
              if (unsigned(address_z) = matrix_depth-1 or matrix_depth = 1) then
                state <= IDLE;
                done_i <= '1';
              end if;
            end if;
          else
            address_x <= std_logic_vector(unsigned(address_x) + types_per_word);
          end if;
        end if;

    end case;
  end process;

  -- This part is not clocked 
  process (send_buffer_source, shifted_states, shifted_types,
           buffer_source, combined_state, combined_type, combined_states, combined_types) begin
    -- Default
    send_buffer_data <= (others => '0');

    case send_buffer_source is
      when STATE_ONE =>
        send_buffer_data(cell_state_bits - 1 downto 0) <= shifted_states(cell_state_bits - 1 downto 0);
      when STATE_ROW =>
        send_buffer_data(states_per_word*cell_state_bits - 1 downto 0) <= shifted_states(states_per_word*cell_state_bits - 1 downto 0);
      when TYPE_ONE =>
        send_buffer_data(cell_type_bits - 1 downto 0) <= shifted_types(cell_type_bits - 1 downto 0);
      when TYPE_ROW =>
        send_buffer_data(types_per_word*cell_type_bits - 1 downto 0) <= shifted_types(types_per_word*cell_type_bits - 1 downto 0);
    end case;

    case buffer_source is
      when ONE =>
        buffer_states_out <= combined_state;
        buffer_types_out  <= combined_type;
      when ROW =>
        buffer_states_out <= combined_states;
        buffer_types_out  <= combined_types;
      when REPEATED =>
        buffer_states_out <= state_repeated;
        buffer_types_out  <= type_repeated;
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
    shift_amount => shift_amount
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
    shift_amount => shift_amount
  );

  -- Internally used out ports
  buffer_address_z <= address_z;
  buffer_address_y <= address_y;
  done <= done_i;

end rtl;
