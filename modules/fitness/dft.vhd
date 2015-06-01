-------------------------------------------------------------------------------
-- Title      : Discrete Fourier Transform
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : dft.vhd
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
--            : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-21
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Discrete Fourier Transform of data found in separate FIFO.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2015-02-21  2.0      lundal   Rewrote
-- 2014-04-08  1.0      stovneng Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity dft is
  generic (
    input_buffer_size : positive := 256;
    input_buffer_bits : positive := 10;
    result_bits       : positive := 18;
    dsp_amount        : positive := 32;
    transform_size    : positive := 128;
    twiddle_precision : positive := 6
  );
  port (
    input_buffer_read  : out std_logic;
    input_buffer_data  : in  std_logic_vector(input_buffer_bits - 1 downto 0);
    input_buffer_count : in  std_logic_vector(bits(input_buffer_size) - 1 downto 0);

    result_slv : out std_logic_vector((transform_size/2)*result_bits -1 downto 0);

    run  : in std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end dft;

architecture rtl of dft is

  -- State machine
  type state_type is (
    IDLE, WAIT_FOR_INPUT, CALCULATE,
    WAIT_FOR_SUM, SUM_READY,
    WAIT_FOR_COMBINED, COMBINED_READY
  );
  signal state : state_type;

  -- Counters
  constant runs_required : natural := divide_ceil(transform_size/2, dsp_amount/2);

  signal run_index     : unsigned(bits(runs_required) - 1 downto 0) := (others => '0');
  signal input_index    : unsigned(bits(transform_size) - 1 downto 0) := (others => '0');
  signal twiddles_index : unsigned(bits(runs_required*transform_size) - 1 downto 0) := (others => '0');

  -- Repeat buffer (Required when more than one run phase)
  type repeat_buffer_mode_type is (
    FLUSH, FILL, REPEAT, NOP
  );
  signal repeat_buffer_mode : repeat_buffer_mode_type := FLUSH;

  signal repeat_buffer_data_in  : std_logic_vector(input_buffer_bits - 1 downto 0);
  signal repeat_buffer_data_out : std_logic_vector(input_buffer_bits - 1 downto 0);
  signal repeat_buffer_read     : std_logic;
  signal repeat_buffer_write    : std_logic;
  signal repeat_buffer_reset    : std_logic;

  -- Twiddles
  constant twiddle_bits : positive := twiddle_precision + 2; -- One bit before point and one for sign

  type twiddles_type is array(0 to dsp_amount/2 - 1) of signed(twiddle_bits - 1 downto 0);

  signal twiddles_real : twiddles_type := (others => (others => '0'));
  signal twiddles_imag : twiddles_type := (others => (others => '0'));

  -- DSP
  type dsp_mode_type is (
    FLUSH, MULTIPLY_ACCUMULATE, COMBINE
  );
  signal dsp_mode : dsp_mode_type := FLUSH;

  type dsp_input_type  is array(0 to dsp_amount - 1) of std_logic_vector(18-1 downto 0);
  type dsp_result_type is array(0 to dsp_amount - 1) of std_logic_vector(48-1 downto 0);

  signal dsp_A : dsp_input_type;
  signal dsp_B : dsp_input_type;
  signal dsp_D : dsp_input_type;
  signal dsp_P : dsp_result_type;

  type dsp_configuration_type is array(0 to dsp_amount - 1) of boolean;

  signal dsp_d_sub_b    : dsp_configuration_type;
  signal dsp_a_mult_b   : dsp_configuration_type;
  signal dsp_accumulate : dsp_configuration_type;

  -- Others
  signal input : std_logic_vector(input_buffer_bits - 1 downto 0);

  type result_type is array(0 to runs_required*dsp_amount/2 - 1) of std_logic_vector(result_bits - 1 downto 0);

  signal result : result_type;

  -- Internally used out ports
  signal done_i : std_logic := '1';

begin

  -- Generic checks
  assert (input_buffer_size > transform_size) report "Unsupported input_buffer_size. Supported values are [(transform_size+1)-N]." severity FAILURE;
  assert (result_bits <= 18) report "Unsupported result_bits. Supported values are [1-18]." severity FAILURE;
  assert (dsp_amount mod 2 = 0) report "Unsupported dsp_amount. Supported values are [2N]." severity FAILURE;
  assert (transform_size mod 2 = 0) report "Unsupported transform_size. Supported values are [2N]." severity FAILURE;

  input_repeat_buffer : entity work.fifo
  generic map (
    address_bits => bits(transform_size + 1), -- +1 to prevent read/write collisions
    data_bits    => input_buffer_bits
  )
  port map (
    data_in    => repeat_buffer_data_in,
    data_out   => repeat_buffer_data_out,
    data_count => open,
    data_read  => repeat_buffer_read,
    data_write => repeat_buffer_write,
    reset      => repeat_buffer_reset,
    clock      => clock
  );

  twiddles : for i in 0 to dsp_amount/2 - 1 generate
    twiddles : entity work.twiddles
    generic map (
      result_index_first  => runs_required*i,
      result_index_amount => runs_required,
      transform_size      => transform_size,
      twiddle_bits        => twiddle_bits,
      twiddle_precision   => twiddle_precision
    )
    port map (
      index => twiddles_index,

      twiddle_real => twiddles_real(i),
      twiddle_imag => twiddles_imag(i),

      clock => clock
    );
  end generate;

  dsps: for i in 0 to dsp_amount - 1 generate
    dsp : entity work.dsp_wrapper
    generic map (
      dsp48a1_implementation => true
    )
    port map (
      A => dsp_A(i),
      B => dsp_B(i),
      D => dsp_D(i),
      P => dsp_P(i),

      d_sub_b    => dsp_d_sub_b(i),
      a_mult_b   => dsp_a_mult_b(i),
      accumulate => dsp_accumulate(i),

      clock => clock
    );
  end generate;

  -- State machine
  process begin
    wait until rising_edge(clock);
    case (state) is

      when IDLE =>
        if (run = '1') then
          -- Reset twiddle indexes
          input_index    <= (others => '0');
          twiddles_index <= (others => '0');
          -- Next state
          state <= WAIT_FOR_INPUT;
          done_i <= '0';
        end if;

      when WAIT_FOR_INPUT =>
        if (unsigned(input_buffer_count) >= transform_size) then
          -- Reset run index
          run_index <= (others => '0');
          -- Increment twiddle indexes
          -- Twiddle output updates next cycle
          input_index    <= input_index + 1;
          twiddles_index <= twiddles_index + 1;
          -- Next state
          state <= CALCULATE;
          repeat_buffer_mode <= FILL;
          dsp_mode <= MULTIPLY_ACCUMULATE;
        end if;

      when CALCULATE =>
        if (input_index = 0) then
          -- Next state when last twiddle
          state <= WAIT_FOR_SUM;
          repeat_buffer_mode <= NOP;
          dsp_mode <= FLUSH;
        else
          -- Increment indexes
          input_index    <= input_index + 1;
          twiddles_index <= twiddles_index + 1;
          -- Wrap input index
          if (input_index = transform_size - 1) then
            input_index <= (others => '0');
          end if;
          -- Wrap twiddles index
          if (twiddles_index = runs_required*transform_size - 1) then
            twiddles_index <= (others => '0');
          end if;
        end if;

      when WAIT_FOR_SUM =>
        state <= SUM_READY;
        repeat_buffer_mode <= NOP;
        dsp_mode <= COMBINE;

      when SUM_READY =>
        state <= WAIT_FOR_COMBINED;
        repeat_buffer_mode <= FLUSH;
        dsp_mode <= FLUSH;

      when WAIT_FOR_COMBINED =>
          state <= COMBINED_READY;

      when COMBINED_READY =>
        if (run_index = runs_required - 1) then
          state <= IDLE;
          done_i <= '1';
        else
          -- Increment indexes
          run_index <= run_index + 1;
          input_index <= input_index + 1;
          twiddles_index <= twiddles_index + 1;
          -- Next state
          state <= CALCULATE;
          repeat_buffer_mode <= REPEAT;
          dsp_mode <= MULTIPLY_ACCUMULATE;
        end if;
        -- Write combined results
        for r in 0 to runs_required - 1 loop
          if (r = run_index) then
            for i in 0 to dsp_amount/2 - 1 loop
              result(runs_required * i + r) <= dsp_P(2*i)(result_bits - 1 downto 0);
            end loop;
          end if;
        end loop;

    end case;
  end process;

  -- Repeat buffer modes
  process (repeat_buffer_mode, input_buffer_data, repeat_buffer_data_out) begin
    -- Defaults
    repeat_buffer_data_in <= (others => '0');
    repeat_buffer_reset <= '0';
    repeat_buffer_write <= '0';
    repeat_buffer_read  <= '0';
    input_buffer_read   <= '0';
    input <= (others => '0');

    case (repeat_buffer_mode) is

      when FLUSH =>
        repeat_buffer_reset <= '1';

      when FILL =>
        repeat_buffer_data_in <= input_buffer_data;
        repeat_buffer_write <= '1';
        input_buffer_read   <= '1';
        input <= input_buffer_data;

      when REPEAT =>
        repeat_buffer_data_in <= repeat_buffer_data_out;
        repeat_buffer_write <= '1';
        repeat_buffer_read  <= '1';
        input <= repeat_buffer_data_out;

      when NOP =>
        null;

    end case;
  end process;

  -- DSP modes
  process (dsp_mode, twiddles_real, twiddles_imag, input, dsp_P) begin
    -- Defaults
    for i in 0 to dsp_amount - 1 loop
      dsp_A(i) <= (others => '0');
      dsp_B(i) <= (others => '0');
      dsp_D(i) <= (others => '0');
      dsp_d_sub_b    <= (others => false);
      dsp_a_mult_b   <= (others => false);
      dsp_accumulate <= (others => false);
    end loop;

    case (dsp_mode) is

      when FLUSH =>
        null;

      when MULTIPLY_ACCUMULATE =>
        -- P = P + A*B
        dsp_a_mult_b   <= (others => true);
        dsp_accumulate <= (others => true);

        for i in 0 to dsp_amount/2 - 1 loop
          -- Twiddles (sign extended)
          dsp_A(2*i+0) <= std_logic_vector(resize(signed(twiddles_real(i)), 18));
          dsp_A(2*i+1) <= std_logic_vector(resize(signed(twiddles_imag(i)), 18));

          -- Input (zero extended)
          dsp_B(2*i+0) <= std_logic_vector(resize(unsigned(input), 18));
          dsp_B(2*i+1) <= std_logic_vector(resize(unsigned(input), 18));
        end loop;

      when COMBINE =>
        -- Calculate Abs(Round(Real)) + Abs(Round(Imag))
        -- Note: This uses only half of the DSPs
        for i in 0 to dsp_amount/2 - 1 loop
          -- Round and crop real and imaginary parts
          dsp_D(2*i) <= std_logic_vector(resize(shift_right(signed(dsp_P(2*i+0)), twiddle_precision), 18)); -- Real part
          dsp_B(2*i) <= std_logic_vector(resize(shift_right(signed(dsp_P(2*i+1)), twiddle_precision), 18)); -- Imag part

          -- If real and imaginary parts have different signs, negate imaginary
          if (dsp_P(2*i+0)(48-1) /= dsp_P(2*i+1)(48-1)) then
            dsp_d_sub_b(2*i) <= true;
          end if;

          -- If real is negative (and also imaginary after negation), multiply by -1
          if (dsp_P(2*i)(48-1) = '1') then
            dsp_A(2*i) <= std_logic_vector(to_signed(-1, 18));
          else
            dsp_A(2*i) <= std_logic_vector(to_signed(1, 18));
          end if;
        end loop;

    end case;
  end process;

  -- Array to SLV
  process (result) begin
    for i in 0 to transform_size/2 - 1 loop
      result_slv((i+1)*result_bits - 1 downto i*result_bits) <= result(i);
    end loop;
  end process;

  -- Internally used out ports
  done <= done_i;

end architecture;
