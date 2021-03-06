--------------------------------------------------------------------------------
-- Title       : Cellular Automaton
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : CA based on an sblock matrix.
--             : One row is configured and readback at a time.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity cellular_automata is
  generic (
    matrix_width           : positive := 8;
    matrix_height          : positive := 8;
    matrix_depth           : positive := 8;
    matrix_wrap            : boolean := true;
    cell_type_bits         : positive := 8;
    cell_state_bits        : positive := 1;
    lut_configuration_bits : positive := 8;
    live_count_buffer_size : positive := 256
  );
  port (
    bram_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    bram_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    bram_types_write  : out std_logic;
    bram_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_states_write : out std_logic;
    bram_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    bram_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    lut_storage_write   : in std_logic;
    lut_storage_address : in std_logic_vector(cell_type_bits - 1 downto 0);
    lut_storage_data    : in std_logic_vector(2**if_else(matrix_depth = 1, 5, 7) - 1 downto 0);

    live_count_read  : in  std_logic;
    live_count_data  : out std_logic_vector(bits(matrix_depth*matrix_height*matrix_width) downto 0);
    live_count_count : out std_logic_vector(bits(live_count_buffer_size) - 1 downto 0);
    live_count_reset : in  std_logic;

    decode_operation  : in cellular_automata_operation_type;
    decode_step_count : in std_logic_vector(15 downto 0);

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end cellular_automata;

architecture rtl of cellular_automata is

  constant neighborhood_bits : positive := if_else(matrix_depth = 1, 5, 7);
  constant shift_register_bits : positive := 2**neighborhood_bits / lut_configuration_bits;

  type state_type is (
    IDLE,
    CONFIGURE_WARMUP_1, CONFIGURE_WARMUP_2, CONFIGURE_FIRST, CONFIGURE,
    READBACK,
    STEP
  );

  signal state : state_type := IDLE;

  signal lut_storage_data_slv       : std_logic_vector(matrix_width*(2**neighborhood_bits) - 1 downto 0);
  signal lut_storage_shift_register : std_logic_vector(matrix_width*(2**neighborhood_bits) - 1 downto 0);
  signal lut_storage_shift_amount   : unsigned(bits(shift_register_bits) - 1 downto 0);

  signal configuration_lut_slv    : std_logic_vector(matrix_width*lut_configuration_bits - 1 downto 0);
  signal configuration_state_slv  : std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
  signal configuration_enable_slv : std_logic_vector(matrix_depth*matrix_height - 1 downto 0);

  signal bram_states_selected : std_logic_vector(bits(matrix_depth*matrix_height) - 1 downto 0);

  signal states_slv : std_logic_vector(matrix_depth*matrix_height*matrix_width - 1 downto 0);

  signal update_matrix : std_logic := '0';

  signal steps_remaining : std_logic_vector(15 downto 0);

  -- Live counter signals
  signal live_counter_run             : std_logic := '0';
  signal live_counter_to_buffer_count : std_logic_vector(bits(matrix_depth*matrix_height*matrix_width) downto 0);
  signal live_counter_to_buffer_write : std_logic := '0';

  -- Internally used out ports
  signal address_z : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal address_y : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal done_i : std_logic := '1';

begin

  -- Generic checks
  assert (cell_state_bits = 1) report "Unsupported cell_state_bits. Supported values are [1]." severity FAILURE;

  process begin
    wait until rising_edge(clock);

    -- Defaults
    bram_states_write <= '0';
    update_matrix <= '0';

    case (state) is

      when IDLE =>
        if (run = '1') then
          done_i <= '0';

          case (decode_operation) is
            when CONFIGURE =>
              address_z <= (others => '0');
              address_y <= (others => '0');
              state <= CONFIGURE_WARMUP_1;
            when READBACK =>
              address_z <= (others => '0');
              address_y <= (others => '0');
              bram_states_selected <= (others => '0');
              bram_states_write <= '1';
              state <= READBACK;
            when STEP =>
              --update_matrix <= '1';
              if (unsigned(decode_step_count) = 0) then
                done_i <= '1';
              else
                steps_remaining <= decode_step_count;
                state <= STEP;
              end if;
            when others =>
              done_i <= '1';
          end case;
        end if;

      when CONFIGURE_WARMUP_1 =>
        -- Types and states are output from cell buffer
        state <= CONFIGURE_WARMUP_2;

      when CONFIGURE_WARMUP_2 =>
        -- LUTs for given types are output from LUT storage
        state <= CONFIGURE_FIRST;

      when CONFIGURE_FIRST =>
        -- Next cell buffer address
        address_y <= std_logic_vector(unsigned(address_y) + 1);
        if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
          address_y <= (others => '0');
          address_z <= std_logic_vector(unsigned(address_z) + 1);
        end if;
        -- Copy LUTs to shift register and begin configuration of first row
        lut_storage_shift_register <= lut_storage_data_slv;
        lut_storage_shift_amount <= (others => '0');
        configuration_state_slv <= bram_states_in;
        configuration_enable_slv <= (configuration_enable_slv'left downto 1 => '0') & '1';
        state <= CONFIGURE;

      when CONFIGURE =>
        -- Shift LUT register to get next configuration values
        lut_storage_shift_register <= std_logic_vector(shift_left(unsigned(lut_storage_shift_register), 1));
        lut_storage_shift_amount <= lut_storage_shift_amount + 1;
        -- If these are the last configuration bits, proceed to next row
        if (lut_storage_shift_amount = shift_register_bits - 1) then
          -- Next cell bram address
          address_y <= std_logic_vector(unsigned(address_y) + 1);
          if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
            address_y <= (others => '0');
            address_z <= std_logic_vector(unsigned(address_z) + 1);
          end if;
          -- Copy LUTs to shift register and begin configuration of next row
          lut_storage_shift_register <= lut_storage_data_slv;
          lut_storage_shift_amount <= (others => '0');
          configuration_state_slv <= bram_states_in;
          configuration_enable_slv <= std_logic_vector(shift_left(unsigned(configuration_enable_slv), 1));
          -- Check if done
          if ((unsigned(address_z) = 0 or matrix_depth = 1) and (unsigned(address_y) = 0 or matrix_height = 1)) then
            state <= IDLE;
            done_i <= '1';
          end if;
        end if;

      when READBACK =>
        -- Next cell bram address
        address_y <= std_logic_vector(unsigned(address_y) + 1);
        if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
          address_y <= (others => '0');
          address_z <= std_logic_vector(unsigned(address_z) + 1);
          if (unsigned(address_z) = matrix_depth-1 or matrix_depth = 1) then
            state <= IDLE;
            done_i <= '1';
          end if;
        end if;
        -- Write row
        bram_states_selected <= std_logic_vector(unsigned(bram_states_selected) + 1);
        if (unsigned(bram_states_selected) = matrix_depth * matrix_height - 1) then
          bram_states_selected <= (others => '0');
        end if;
        bram_states_write <= '1';

      when STEP =>
        update_matrix <= '1';
        steps_remaining <= std_logic_vector(unsigned(steps_remaining) - 1);
        if (unsigned(steps_remaining) = 1) then
          done_i <= '1';
          state <= IDLE;
        end if;

    end case;
  end process;

  lut_storage : entity work.bram_1toN
  generic map (
    address_bits => cell_type_bits,
    data_bits    => 2**neighborhood_bits,
    read_ports   => matrix_width
  )
  port map (
    write_enabled => lut_storage_write,
    write_address => lut_storage_address,
    write_data    => lut_storage_data,

    read_address_slv => bram_types_in,
    read_data_slv    => lut_storage_data_slv,

    clock => clock
  );

  matrix : entity work.sblock_matrix
  generic map (
    matrix_width           => matrix_width,
    matrix_height          => matrix_height,
    matrix_depth           => matrix_depth,
    matrix_wrap            => matrix_wrap,
    lut_configuration_bits => lut_configuration_bits
  )
  port map (
    configuration_lut_slv    => configuration_lut_slv,
    configuration_state_slv  => configuration_state_slv,
    configuration_enable_slv => configuration_enable_slv,

    states_slv => states_slv,

    update => update_matrix,

    clock => clock
  );

  -- Maps signals from LUT shift register to cell configuration ports
  -- Sblock shift registers shift towards left, high values are therefore inserted first
  configuration_select : for i in 0 to matrix_width*lut_configuration_bits - 1 generate
    configuration_lut_slv(i) <= lut_storage_shift_register((i+1)*shift_register_bits - 1);
  end generate;

  -- Selects one row of states
  readback_selector : entity work.selector
  generic map (
    entry_bits   => matrix_width,
    entry_number => matrix_depth*matrix_height
  )
  port map (
    entries_in => states_slv,
    entry_out  => bram_states_out,
    selected   => bram_states_selected
  );

  -- Run livecounter after matrix is updated
  process begin
    wait until rising_edge(clock);
    live_counter_run <= update_matrix;
  end process;

  live_counter : entity work.live_counter
  generic map (
    cell_amount => matrix_depth*matrix_height*matrix_width
  )
  port map (
    run         => live_counter_run,
    cell_states => states_slv,
    live_count  => live_counter_to_buffer_count,
    write_count => live_counter_to_buffer_write,

    clock => clock
  );

  live_count_buffer : entity work.fifo
  generic map (
    address_bits => bits(live_count_buffer_size),
    data_bits    => bits(matrix_depth*matrix_height*matrix_width) + 1
  )
  port map (
    data_in    => live_counter_to_buffer_count,
    data_out   => live_count_data,
    data_count => live_count_count,
    data_read  => live_count_read,
    data_write => live_counter_to_buffer_write,
    reset      => live_count_reset,
    clock      => clock
  );

  -- Output tie-offs
  bram_types_write <= '0';
  bram_types_out   <= (others => '0');

  -- Internally used out ports
  bram_address_z <= address_z;
  bram_address_y <= address_y;
  done <= done_i;

end rtl;
