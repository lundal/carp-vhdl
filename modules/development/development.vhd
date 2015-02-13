-------------------------------------------------------------------------------
-- Title      : Development
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : development.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-03
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: TODO
--            : Note: Cell Fetcher runs during test_last, but data is not used.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-03  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity development is
  generic (
    matrix_width             : positive := 8;
    matrix_height            : positive := 8;
    matrix_depth             : positive := 8;
    matrix_wrap              : boolean  := true;
    cell_type_bits           : positive := 8;
    cell_state_bits          : positive := 1;
    rule_vector_amount       : positive := 64;
    rule_amount              : positive := 256;
    rules_tested_in_parallel : positive := 8
  );
  port (
    -- Buffer - Port A
    buffer_a_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    buffer_a_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    buffer_a_types_write  : out std_logic;
    buffer_a_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_a_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_a_states_write : out std_logic;
    buffer_a_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    buffer_a_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    -- Buffer - Port B
    buffer_b_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    buffer_b_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    buffer_b_types_write  : out std_logic;
    buffer_b_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_b_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    buffer_b_states_write : out std_logic;
    buffer_b_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    buffer_b_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    rule_storage_write   : in std_logic;
    rule_storage_address : in std_logic_vector(bits(rule_amount) - 1 downto 0);
    rule_storage_data    : in std_logic_vector((cell_type_bits + 1 + cell_state_bits + 1) * if_else(matrix_depth = 1, 6, 8) - 1 downto 0);

    rule_vector_reader_data  : out std_logic_vector(rule_amount - 1 downto 0);
    rule_vector_reader_count : out std_logic_vector(bits(rule_vector_amount) - 1 downto 0);
    rule_vector_reader_read  : in  std_logic;

    rule_numbers_reader_address_z : in  std_logic_vector(bits(matrix_depth) - 1 downto 0);
    rule_numbers_reader_address_y : in  std_logic_vector(bits(matrix_height) - 1 downto 0);
    rule_numbers_reader_data      : out std_logic_vector(matrix_width * bits(rule_amount) - 1 downto 0);

    decode_operation : in development_operation_type;

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end development;

architecture rtl of development is

  constant neighborhood_size : positive := if_else(matrix_depth = 1, 5, 7);

  type state_type is (
    IDLE, FETCH_FIRST, MAIN_LOOP, TEST_LAST,
    WAIT_1, WAIT_2
  );

  signal state : state_type := IDLE;

  -- TODO
  signal rules_active : std_logic_vector(bits(rule_amount) - 1 downto 0) := (others => '1');

  -- Cell fetcher
  signal cell_fetcher_types_slv  : std_logic_vector(matrix_width * cell_type_bits * if_else(matrix_depth = 1, 5, 7) - 1 downto 0);
  signal cell_fetcher_states_slv : std_logic_vector(matrix_width * cell_state_bits * if_else(matrix_depth = 1, 5, 7) - 1 downto 0);
  signal cell_fetcher_address_z  : std_logic_vector(bits(matrix_depth) - 1 downto 0) := (others => '0');
  signal cell_fetcher_address_y  : std_logic_vector(bits(matrix_height) - 1 downto 0) := (others => '0');
  signal cell_fetcher_run  : std_logic;
  signal cell_fetcher_done : std_logic;

  -- Rule fetcher
  signal rule_fetcher_to_storage_address_slv : std_logic_vector(rules_tested_in_parallel * rule_storage_address'length - 1 downto 0);
  signal rule_fetcher_from_storage_data_slv  : std_logic_vector(rules_tested_in_parallel * rule_storage_data'length - 1 downto 0);
  signal rule_fetcher_to_tester_rules_slv    : std_logic_vector(rules_tested_in_parallel * rule_storage_data'length - 1 downto 0);
  signal rule_fetcher_rules_number           : std_logic_vector(bits(rule_amount) - 1 downto 0);
  signal rule_fetcher_run  : std_logic;
  signal rule_fetcher_done : std_logic;

  -- Rule Tester
  signal rule_testers_types_slv   : std_logic_vector(matrix_width * cell_type_bits * if_else(matrix_depth = 1, 5, 7) - 1 downto 0);
  signal rule_testers_states_slv  : std_logic_vector(matrix_width * cell_state_bits * if_else(matrix_depth = 1, 5, 7) - 1 downto 0);
  signal rule_testers_hits_slv    : std_logic_vector(matrix_width * rules_tested_in_parallel - 1 downto 0);
  signal rule_testers_rules_first : std_logic;

  -- Write signals
  signal write_address_z : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal write_address_y : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal write_enable    : std_logic := '0';

  -- Signals delayed once
  signal write_address_z_delayed_1 : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal write_address_y_delayed_1 : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal write_enable_delayed_1    : std_logic := '0';

  -- Signals delayed twice
  signal write_address_z_delayed_2 : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal write_address_y_delayed_2 : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal write_enable_delayed_2    : std_logic := '0';

  -- Signals delayed thrice
  signal write_address_z_delayed_3 : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal write_address_y_delayed_3 : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal write_enable_delayed_3    : std_logic := '0';

  -- Rule vector
  signal rule_vector_to_fifo : std_logic_vector(rule_amount - 1 downto 0);
  signal rule_vector_write   : std_logic := '0';

  -- Rule numbers
  signal rule_numbers_to_bram : std_logic_vector(matrix_width * bits(rule_amount) - 1 downto 0);
  signal rule_numbers_address : std_logic_vector(bits(matrix_depth) + bits(matrix_height) - 1 downto 0);
  signal rule_numbers_write   : std_logic := '0';

  -- Internally used out-signals
  signal done_i : std_logic := '1';

begin

  -- Generic checks
  assert (matrix_height > 1) report "Unsupported matrix_height. Supported values are [2-N]." severity FAILURE;

  -- State machine
  process begin
    wait until rising_edge(clock);

    -- Defaults
    rule_vector_write <= '0';

    case (state) is

      when IDLE =>
        if (decode_operation = DEVELOP and run = '1') then
          -- Next fetch address
          cell_fetcher_address_y <= std_logic_vector(unsigned(cell_fetcher_address_y) + 1);
          if (unsigned(cell_fetcher_address_y) = matrix_height-1 or matrix_height = 1) then
            cell_fetcher_address_y <= (others => '0');
            cell_fetcher_address_z <= std_logic_vector(unsigned(cell_fetcher_address_z) + 1);
          end if;
          -- Next stage
          state <= FETCH_FIRST;
          done_i <= '0';
        end if;

      when FETCH_FIRST =>
        if (cell_fetcher_done = '1') then
          -- Next fetch address
          cell_fetcher_address_y <= std_logic_vector(unsigned(cell_fetcher_address_y) + 1);
          if (unsigned(cell_fetcher_address_y) = matrix_height-1 or matrix_height = 1) then
            cell_fetcher_address_y <= (others => '0');
            cell_fetcher_address_z <= std_logic_vector(unsigned(cell_fetcher_address_z) + 1);
            if (unsigned(cell_fetcher_address_z) = matrix_depth-1 or matrix_depth = 1) then
              cell_fetcher_address_z <= (others => '0');
            end if;
          end if;
          -- Pass types and states to testers
          rule_testers_types_slv  <= cell_fetcher_types_slv;
          rule_testers_states_slv <= cell_fetcher_states_slv;
          -- Setup write signals
          write_address_z <= (others => '0');
          write_address_y <= (others => '0');
          write_enable <= '1';
          -- Next stage
          state <= MAIN_LOOP;
        end if;

      when MAIN_LOOP =>
        if (cell_fetcher_done = '1' and rule_fetcher_done = '1') then
          -- Next fetch address
          cell_fetcher_address_y <= std_logic_vector(unsigned(cell_fetcher_address_y) + 1);
          if (unsigned(cell_fetcher_address_y) = matrix_height-1 or matrix_height = 1) then
            cell_fetcher_address_y <= (others => '0');
            cell_fetcher_address_z <= std_logic_vector(unsigned(cell_fetcher_address_z) + 1);
            if (unsigned(cell_fetcher_address_z) = matrix_depth-1 or matrix_depth = 1) then
              cell_fetcher_address_z <= (others => '0');
            end if;
          end if;
          -- Pass types and states to testers
          rule_testers_types_slv  <= cell_fetcher_types_slv;
          rule_testers_states_slv <= cell_fetcher_states_slv;
          -- Next write address
          write_address_y <= std_logic_vector(unsigned(write_address_y) + 1);
          if (unsigned(write_address_y) = matrix_height-1 or matrix_height = 1) then
            write_address_y <= (others => '0');
            write_address_z <= std_logic_vector(unsigned(write_address_z) + 1);
          end if;
          -- Final stage when address of next cells to be fetched is zero
          if ( (unsigned(cell_fetcher_address_z) = 0 or matrix_depth = 1) and
               (unsigned(cell_fetcher_address_y) = 0 or matrix_height = 1) ) then
            state <= TEST_LAST;
          end if;
        end if;

      when TEST_LAST =>
        if (cell_fetcher_done = '1' and rule_fetcher_done = '1') then
          -- Reset fetch address
          cell_fetcher_address_y <= (others => '0');
          cell_fetcher_address_z <= (others => '0');
          -- Reset write signals
          write_enable <= '0';
          -- Wait (rule_testers.cycles + hits_to_xxx.cycles - 1) cycles.
          -- This is needed to assure everything is done when returning to idle.
          state <= WAIT_1;
        end if;

      when WAIT_1 =>
        state <= WAIT_2;

      when WAIT_2 =>
        -- Write rulevector
        rule_vector_write <= '1';
        -- Return to idle
        state <= IDLE;
        done_i <= '1';

    end case;
  end process;

  -- Run signals are asynchronous for optimal timing (see diagrams)
  process (run, state, cell_fetcher_done, rule_fetcher_done) begin
    case (state) is
      when IDLE =>
        cell_fetcher_run <= run;
        rule_fetcher_run <= '0';
      when FETCH_FIRST =>
        cell_fetcher_run <= cell_fetcher_done and rule_fetcher_done;
        rule_fetcher_run <= cell_fetcher_done and rule_fetcher_done;
      when MAIN_LOOP =>
        cell_fetcher_run <= cell_fetcher_done and rule_fetcher_done;
        rule_fetcher_run <= cell_fetcher_done and rule_fetcher_done;
      when others =>
        cell_fetcher_run <= '0';
        rule_fetcher_run <= '0';
    end case;
  end process;

  -- Propagate delayed signals
  process begin
    wait until rising_edge(clock);
    -- One cycle
    write_address_z_delayed_1 <= write_address_z;
    write_address_y_delayed_1 <= write_address_y;
    write_enable_delayed_1    <= write_enable;
    -- Two cycles
    write_address_z_delayed_2 <= write_address_z_delayed_1;
    write_address_y_delayed_2 <= write_address_y_delayed_1;
    write_enable_delayed_2    <= write_enable_delayed_1;
    -- Three cycles
    write_address_z_delayed_3 <= write_address_z_delayed_2;
    write_address_y_delayed_3 <= write_address_y_delayed_2;
    write_enable_delayed_3    <= write_enable_delayed_2;
  end process;

  cell_fetcher : entity work.cell_fetcher
  generic map (
    matrix_width     => matrix_width,
    matrix_height    => matrix_height,
    matrix_depth     => matrix_depth,
    matrix_wrap      => matrix_wrap,
    cell_type_bits   => cell_type_bits,
    cell_state_bits  => cell_state_bits
  )
  port map (
    buffer_address_z    => buffer_a_address_z,
    buffer_address_y    => buffer_a_address_y,
    buffer_types_write  => buffer_a_types_write,
    buffer_types_in     => buffer_a_types_in,
    buffer_types_out    => buffer_a_types_out,
    buffer_states_write => buffer_a_states_write,
    buffer_states_in    => buffer_a_states_in,
    buffer_states_out   => buffer_a_states_out,

    row_neighborhood_types_slv  => cell_fetcher_types_slv,
    row_neighborhood_states_slv => cell_fetcher_states_slv,

    address_z => cell_fetcher_address_z,
    address_y => cell_fetcher_address_y,

    run  => cell_fetcher_run,
    done => cell_fetcher_done,

    clock => clock
  );

  rule_storage : entity work.bram_1toN
  generic map (
    address_bits => rule_storage_address'length,
    data_bits    => rule_storage_data'length,
    read_ports   => rules_tested_in_parallel
  )
  port map (
    write_enabled => rule_storage_write,
    write_address => rule_storage_address,
    write_data    => rule_storage_data,

    read_address_slv => rule_fetcher_to_storage_address_slv,
    read_data_slv    => rule_fetcher_from_storage_data_slv,

    clock => clock
  );

  rule_fetcher : entity work.rule_fetcher
  generic map (
    rule_amount              => rule_amount,
    rule_size                => rule_storage_data'length,
    rules_tested_in_parallel => rules_tested_in_parallel
  )
  port map (
    rule_storage_address_slv => rule_fetcher_to_storage_address_slv,
    rule_storage_data_slv    => rule_fetcher_from_storage_data_slv,

    rules_active => rules_active,
    rules_slv    => rule_fetcher_to_tester_rules_slv,
    rules_number => rule_fetcher_rules_number,

    run  => rule_fetcher_run,
    done => rule_fetcher_done,

    clock => clock
  );

  rule_testers_multi : entity work.rule_testers_multi
  generic map (
    cell_type_bits           => cell_type_bits,
    cell_state_bits          => cell_state_bits,
    neighborhood_size        => neighborhood_size,
    rules_tested_in_parallel => rules_tested_in_parallel,
    cells_tested_in_parallel => matrix_width
  )
  port map (
    neighborhoods_types_slv  => rule_testers_types_slv,
    neighborhoods_states_slv => rule_testers_states_slv,

    rules_slv   => rule_fetcher_to_tester_rules_slv,
    rules_first => rule_testers_rules_first,

    hits_slv => rule_testers_hits_slv,

    results_type  => buffer_b_types_out,
    results_state => buffer_b_states_out,

    clock => clock
  );

  hits_to_vector : entity work.hits_to_vector
  generic map (
    rule_amount              => rule_amount,
    rules_tested_in_parallel => rules_tested_in_parallel,
    cells_tested_in_parallel => matrix_width
  )
  port map (
    hits_slv    => rule_testers_hits_slv,
    rule_number => rule_fetcher_rules_number,
    rule_vector => rule_vector_to_fifo,
    clock       => clock
  );

  hits_to_numbers : entity work.hits_to_numbers
  generic map (
    rule_amount              => rule_amount,
    rules_tested_in_parallel => rules_tested_in_parallel,
    cells_tested_in_parallel => matrix_width
  )
  port map (
    hits_slv         => rule_testers_hits_slv,
    rule_number      => rule_fetcher_rules_number,
    rule_numbers_slv => rule_numbers_to_bram,
    clock            => clock
  );

  rule_vector_fifo : entity work.fifo
  generic map (
    address_bits => bits(rule_vector_amount),
    data_bits    => rule_amount
  )
  port map (
    data_in    => rule_vector_to_fifo,
    data_out   => rule_vector_reader_data,
    data_count => rule_vector_reader_count,
    data_read  => rule_vector_reader_read,
    data_write => rule_vector_write,
    clock      => clock,
    reset      => '0' -- TODO
  );

  rule_numbers_bram : entity work.bram_tdp
  generic map (
    address_bits => bits(matrix_depth) + bits(matrix_height),
    data_bits    => matrix_width * bits(rule_amount),
    write_first  => true
  )
  port map (
    -- Port A
    a_write    => rule_numbers_write,
    a_address  => rule_numbers_address,
    a_data_in  => rule_numbers_to_bram,
    a_data_out => open,
    -- Port B
    b_write    => '0',
    b_address  => rule_numbers_reader_address_z & rule_numbers_reader_address_y,
    b_data_in  => (others => '0'),
    b_data_out => rule_numbers_reader_data,

    clock => clock
  );

  -- Notify rule tester when first rule is sent
  rule_testers_rules_first <= '1' when unsigned(rule_fetcher_rules_number) = 0 else '0';

  -- Buffer write signals
  -- Note: Delayed as many cycles as the testers take (two)
  buffer_b_address_z    <= write_address_z_delayed_2;
  buffer_b_address_y    <= write_address_y_delayed_2;
  buffer_b_types_write  <= write_enable_delayed_2;
  buffer_b_states_write <= write_enable_delayed_2;

  -- Rule numbers write signals
  rule_numbers_address <= write_address_z_delayed_3 & write_address_y_delayed_3;
  rule_numbers_write   <= write_enable_delayed_3;

  -- Internally used out ports
  done <= done_i;

end rtl;
