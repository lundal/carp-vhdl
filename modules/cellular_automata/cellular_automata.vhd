-------------------------------------------------------------------------------
-- Title      : Cellular Automata
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : cellular_automata.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update_matrix: 2015-01-30
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: TODO
--            : Configures one row at a time.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-30  1.0      lundal    Created
-------------------------------------------------------------------------------

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
    lut_configuration_bits : positive := 8
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

    lut_storage_write   : in std_logic;
    lut_storage_address : in std_logic_vector(cell_type_bits - 1 downto 0);
    lut_storage_data    : in std_logic_vector(2**if_else(matrix_depth = 1, 5, 7) - 1 downto 0);

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

  signal buffer_states_selected : std_logic_vector(bits(matrix_depth*matrix_height) - 1 downto 0);

  signal states_slv : std_logic_vector(matrix_depth*matrix_height*matrix_width - 1 downto 0);

  signal update_matrix : std_logic := '0';

  signal steps_remaining : std_logic_vector(15 downto 0);

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
    buffer_states_write <= '0';
    buffer_types_write <= '0';
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
              buffer_states_selected <= (others => '0');
              buffer_states_write <= '1';
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
          address_z <= std_logic_vector(unsigned(address_z) + 1);
        end if;
        -- Copy LUTs to shift register and begin configuration of first row
        lut_storage_shift_register <= lut_storage_data_slv;
        lut_storage_shift_amount <= (others => '0');
        configuration_state_slv <= buffer_states_in;
        configuration_enable_slv <= (configuration_enable_slv'left downto 1 => '0') & '1';
        state <= CONFIGURE;

      when CONFIGURE =>
        -- Shift LUT register to get next configuration values
        lut_storage_shift_register <= std_logic_vector(shift_right(unsigned(lut_storage_shift_register), 1));
        lut_storage_shift_amount <= lut_storage_shift_amount + 1;
        -- If these are the last configuration bits, proceed to next row
        if (lut_storage_shift_amount = shift_register_bits - 1) then
          -- Next cell buffer address
          address_y <= std_logic_vector(unsigned(address_y) + 1);
          if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
            address_z <= std_logic_vector(unsigned(address_z) + 1);
          end if;
          -- Copy LUTs to shift register and begin configuration of next row
          lut_storage_shift_register <= lut_storage_data_slv;
          lut_storage_shift_amount <= (others => '0');
          configuration_state_slv <= buffer_states_in;
          configuration_enable_slv <= std_logic_vector(shift_left(unsigned(configuration_enable_slv), 1));
          -- Check if done
          if ((unsigned(address_z) = 0 or matrix_depth = 1) and (unsigned(address_y) = 0 or matrix_height = 1)) then
            state <= IDLE;
            done_i <= '1';
          end if;
        end if;

      when READBACK =>
        -- Next cell buffer address
        address_y <= std_logic_vector(unsigned(address_y) + 1);
        if (unsigned(address_y) = matrix_height-1 or matrix_height = 1) then
          address_z <= std_logic_vector(unsigned(address_z) + 1);
          if (unsigned(address_z) = matrix_depth-1 or matrix_depth = 1) then
            state <= IDLE;
            done_i <= '1';
          end if;
        end if;
        -- Write row
        buffer_states_selected <= std_logic_vector(unsigned(buffer_states_selected) + 1);
        buffer_states_write <= '1';

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

    read_address_slv => buffer_types_in,
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
  configuration_select : for i in 0 to matrix_width*lut_configuration_bits - 1 generate
    configuration_lut_slv(i) <= lut_storage_shift_register(i*shift_register_bits);
  end generate;

  -- Selects one row of states
  readback_selector : entity work.selector
  generic map (
    entry_bits   => matrix_width,
    entry_number => matrix_depth*matrix_height
  )
  port map (
    entries_in => states_slv,
    entry_out  => buffer_states_out,
    selected   => buffer_states_selected
  );

  -- Internally used out ports
  buffer_address_z <= address_z;
  buffer_address_y <= address_y;
  done <= done_i;

end rtl;
