-------------------------------------------------------------------------------
-- Title      : Fitness DFT
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : fitness_dft.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-23
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: TODO
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2015-02-23  1.0      lundal   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity fitness_dft is
  generic (
    -- General fitness interface
    live_count_buffer_size : positive := 256;
    live_count_buffer_bits : positive := 10;
    fitness_buffer_size    : positive := 256;
    -- Spesific features
    result_bits       : positive := 18;
    dsp_amount        : positive := 32;
    transform_size    : positive := 128;
    twiddle_precision : positive := 6
  );
  port (
    live_count_buffer_read  : out std_logic;
    live_count_buffer_data  : in  std_logic_vector(live_count_buffer_bits - 1 downto 0);
    live_count_buffer_count : in  std_logic_vector(bits(live_count_buffer_size) - 1 downto 0);

    fitness_buffer_write : out std_logic;
    fitness_buffer_data  : out std_logic_vector(32 - 1 downto 0);
    fitness_buffer_count : in  std_logic_vector(bits(fitness_buffer_size) - 1 downto 0);

    identifier    : out std_logic_vector(8 - 1 downto 0);
    words_per_run : out std_logic_vector(8 - 1 downto 0);
    parameters    : out std_logic_vector(16 - 1 downto 0);

    clock : in std_logic
  );
end entity;

architecture rtl of fitness_dft is

  constant results_per_word     : positive := 32/result_bits;
  constant result_words_per_run : positive := divide_ceil(transform_size/2, results_per_word);

  -- DFT
  signal dft_result_slv : std_logic_vector((transform_size/2)*result_bits -1 downto 0);
  signal dft_run  : std_logic;
  signal dft_done : std_logic := '1';

  -- Result
  type result_type is array(0 to transform_size/2 - 1) of std_logic_vector(result_bits - 1 downto 0);
  signal result : result_type;

  -- Transfer
  type transfer_state_type is (IDLE, TRANSFER);
  signal transfer_state : transfer_state_type := IDLE;
  signal transfer_run  : std_logic;
  signal transfer_done : std_logic := '1';
  signal transfer_counter : unsigned(result_words_per_run - 1 downto 0) := (others => '0');
  signal transfer_skip : boolean := true;

  -- Buffer check
  signal buffer_has_space : boolean;

begin

  -- Generic checks
  assert (result_bits < 2**6) report "Unsupported result_bits. Supported values are [1-63]." severity FAILURE;
  assert (transform_size < 2**10) report "Unsupported transform_size. Supported values are [1-1023]." severity FAILURE;

  -- Information
  identifier              <= X"01";
  words_per_run           <= std_logic_vector(to_unsigned(result_words_per_run, 8));
  parameters( 5 downto 0) <= std_logic_vector(to_unsigned(result_bits, 6));
  parameters(15 downto 6) <= std_logic_vector(to_unsigned(transform_size, 10));

  -- Buffer must have at least as many available words as the number of cycles
  -- between the condition is checked and the data is written. 2 should be enough.
  buffer_has_space <= fitness_buffer_count(fitness_buffer_count'high downto 1) /= (fitness_buffer_count'high downto 1 => '1');

  process (dft_done, transfer_done) begin

    if (dft_done = '1' and transfer_done = '1') then
      dft_run <= '1';
      transfer_run <= '1';
    else
      dft_run <= '0';
      transfer_run <= '0';
    end if;

  end process;

  process begin
    wait until rising_edge(clock);

    -- Defaults
    fitness_buffer_write <= '0';

    case (transfer_state) is

      when IDLE =>
        if (transfer_run = '1') then
          -- Copy result
          for i in result'range loop
            result(i) <= dft_result_slv((i+1)*result_bits - 1 downto i*result_bits);
          end loop;
          transfer_counter <= (others => '0');
          transfer_state <= TRANSFER;
          transfer_done <= '0';
        end if;
        -- Skip the first transfer since there is no valid data yet
        if (transfer_skip) then
          transfer_state <= IDLE;
          transfer_done <= '1';
          transfer_skip <= false;
        end if;

      when TRANSFER =>
        if (buffer_has_space) then
          fitness_buffer_write <= '1';
          fitness_buffer_data <= (others => '0');
          -- For each word
          for i in 0 to result_words_per_run - 1 loop
            -- If current word
            if (i = transfer_counter) then
              -- Transfer results
              for k in 0 to results_per_word - 1 loop
                fitness_buffer_data((k+1)*result_bits - 1 downto k*result_bits) <= result(i*results_per_word + k);
              end loop;
            end if;
          end loop;
          -- Increment counter (next word)
          transfer_counter <= transfer_counter + 1;
          -- Check end condition
          if (transfer_counter = result_words_per_run - 1) then
            transfer_state <= IDLE;
            transfer_done <= '1';
          end if;
        end if;

    end case;
  end process;

  dft : entity work.dft
  generic map (
    input_buffer_size => live_count_buffer_size,
    input_buffer_bits => live_count_buffer_bits,
    result_bits       => result_bits,
    dsp_amount        => dsp_amount,
    transform_size    => transform_size,
    twiddle_precision => twiddle_precision
  )
  port map (
    input_buffer_read  => live_count_buffer_read,
    input_buffer_data  => live_count_buffer_data,
    input_buffer_count => live_count_buffer_count,

    result_slv => dft_result_slv,

    run  => dft_run,
    done => dft_done,

    clock => clock
  );

end architecture;
