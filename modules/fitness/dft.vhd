-------------------------------------------------------------------------------
-- Title      : Discrete Fourier Transform
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : dft.vhd
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
-- Company    : NTNU
-- Last update: 2014-04-08
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Discrete Fourier Transform of data found in separate BRAM.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2014-04-08  1.0      stovneng Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.constants.all;

entity dft is
  port (
    start_dft  : in  std_logic;
    data_in    : in  std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    data_addr  : out std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    first_addr : in  std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    set_first_addr : in std_logic;
    dft_idle       : out std_logic;
    output     : out dft_res_t;
    reset : in std_logic;
    clock : in std_logic
  );
end dft;

architecture dft_arch of dft is

  -- constants
  constant PERRUN : integer := DFT_DSPS/2;

  constant zero : std_logic_vector(63 downto 0) := (others => '0');
  constant one : std_logic_vector(6 downto 0) := (others => '1');

  type dft_state_type is (idle, prepare_pipe, run, stop_acc, reset_count,
                          output_wait1, output_wait2, set_output);
  signal dft_state : dft_state_type;

  signal counter_input : unsigned(6 downto 0);
  signal counter_runs : integer := 0;
  signal first_addr_i : unsigned(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);

  signal twiddle_index : unsigned(13 - DFT_LG_DSPS downto 0) := (others => '0');
  type twiddle_out_t is array(PERRUN - 1 downto 0)
    of std_logic_vector(TWIDDLE_SIZE - 1 downto 0);
  signal twiddle_out : twiddle_out_t := (others => (others => '0'));
  signal feed_dsp : std_logic_vector(1 downto 0);

  -- DSP SIGNALS
  type a18 is array(0 to DFT_DSPS-1) of std_logic_vector (18-1 downto 0);
  type a8 is array(0 to DFT_DSPS-1) of std_logic_vector (8-1 downto 0);
  type a48 is array(0 to DFT_DSPS-1) of std_logic_vector (48-1 downto 0);
  signal P        : a48;
  signal A        : a18 := (others => (others => '0'));
  signal B        : a18 := (others => (others => '0'));
  signal D        : a18 := (others => (others => '0'));

  signal d_sub_b    : boolean := false;
  signal a_mult_b   : boolean := false;
  signal accumulate : boolean := false;

begin

  twiddlemem: for i in 0 to PERRUN - 1 generate
    twmem_i : entity work.twiddle_memory
      generic map (
        index => i
      )
      port map (
        clock    => clock,
        address  => to_integer(twiddle_index),
        data_out => twiddle_out(i)
      );
  end generate;

  dsps: for i in 0 to DFT_DSPS - 1 generate
    dsp : entity work.dsp_wrapper
    generic map (
      dsp48a1_implementation => true
    )
    port map (
      A => A(i),
      B => B(i),
      D => D(i),
      P => P(i),

      d_sub_b    => d_sub_b,
      a_mult_b   => a_mult_b,
      accumulate => accumulate,

      clock => clock
    );
  end generate;

  -----------------------------------------------------------------------------
  -- clocked part of FSM

  process(clock,reset) is
  begin
    if (reset='0') then
      dft_state <= idle;
      counter_input <= (others => '0');
      counter_runs <= 0;
      twiddle_index <= (others => '0');
      feed_dsp <= "00";
    elsif(rising_edge(clock)) then
      case dft_state is
        when idle =>
          twiddle_index <= (others => '0');
          if start_dft = '1' then
            dft_state <= prepare_pipe;
          else
            dft_state <= idle;
          end if;
          feed_dsp <= "00";
          counter_runs <= 0;

        when prepare_pipe =>
          dft_state <= run;
          twiddle_index <= twiddle_index + 1;
          counter_input <= counter_input + 1;
          feed_dsp <= "01";

        when run =>
          twiddle_index <= twiddle_index + 1;
          if counter_input = unsigned(one(counter_input'length - 1 downto 0)) then
            dft_state <= stop_acc;
          else
            dft_state <= run;
          end if;
          counter_input <= counter_input + 1;
          feed_dsp <= "01";

        when stop_acc =>
          dft_state <= reset_count;
          feed_dsp <= "00";

        when reset_count =>
          dft_state <= output_wait1;
          counter_input <= (others => '0');
          feed_dsp <= "10";

        when output_wait1 =>
          dft_state <= output_wait2;

        when output_wait2 =>
          dft_state <= set_output;
          counter_runs <= counter_runs + 1;

        when set_output =>
          for i in 0 to PERRUN - 1 loop
            output((counter_runs-1)*PERRUN+i) <= P(i*2)(17 downto 0);
          end loop;
          feed_dsp <= "00";

          -- Check if finished
          if counter_runs = RUNS_PER_DSP then
            dft_state <= idle;
          else
            dft_state <= run;
          end if;
      end case;
    end if;
  end process;

  process(feed_dsp, data_in, twiddle_out, P)
  begin
    -- Defaults
    for i in 0 to DFT_DSPS-1 loop
      A(i) <= (others => '0');
      B(i) <= (others => '0');
      D(i) <= (others => '0');
      d_sub_b  <= false;
      a_mult_b <= false;
    end loop;

    if feed_dsp = "01" then
      -- Multiply input with twiddles
      for i in 0 to PERRUN-1 loop

        -- Multiply mode: P = A*B
        d_sub_b  <= false;
        a_mult_b <= true;

        -- Twiddles (sign extended)
        A(i*2) <= std_logic_vector(resize(signed(twiddle_out(i)(TWLEN-1 downto TWLEN/2)), A(i*2)'length)); -- Real part
        A(i*2+1) <= std_logic_vector(resize(signed(twiddle_out(i)(TWLEN/2-1 downto 0)), A(i*2+1)'length)); -- Imaginary part

        -- Input (zero extended)
        B(i*2) <= std_logic_vector(resize(unsigned(data_in), B(i*2)'length));
        B(i*2+1) <= std_logic_vector(resize(unsigned(data_in), B(i*2+1)'length));

      end loop;
    elsif feed_dsp = "10" then
      for i in 0 to PERRUN-1 loop

        -- Combine real and imaginary parts
        D(i*2) <= P(i*2)(VALSIZE-1+TWIDDLE_PRECISION downto TWIDDLE_PRECISION); -- Real part
        B(i*2) <= P(i*2+1)(VALSIZE-1+TWIDDLE_PRECISION downto TWIDDLE_PRECISION); -- Imaginary part

        -- If both parts are negative
        -- P = (D+B)*(-1)
        if (P(i*2+1)(VALSIZE-1+TWIDDLE_PRECISION) = '1' and P(i*2)(VALSIZE-1+TWIDDLE_PRECISION) = '1') then
          d_sub_b  <= false;
          a_mult_b <= false;
          A(i*2) <= "111111111111111111";

        -- If imaginary part is negative
        -- P = (D-B)*1
        elsif (P(i*2+1)(VALSIZE-1+TWIDDLE_PRECISION) = '1' and P(i*2)(VALSIZE-1+TWIDDLE_PRECISION) = '0') then
          d_sub_b  <= true;
          a_mult_b <= false;
          A(i*2) <= "000000000000000001";

        -- If real part is negative
        -- P = (D-B)*(-1)
        elsif (P(i*2+1)(VALSIZE-1+TWIDDLE_PRECISION) = '0' and P(i*2)(VALSIZE-1+TWIDDLE_PRECISION) = '1') then
          d_sub_b  <= true;
          a_mult_b <= false;
          A(i*2) <= "111111111111111111";

        -- If no parts are negative
        -- P = (D+B)*1
        else
          d_sub_b  <= false;
          a_mult_b <= false;
          A(i*2) <= "000000000000000001";

        end if;
      end loop;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- comb. part of FSM

  process (dft_state, first_addr_i,counter_input)
  begin
    data_addr <= std_logic_vector(first_addr_i + counter_input);
    dft_idle <= '0';
    case dft_state is
      when idle =>
        accumulate <= false;
        dft_idle <= '1';

      when prepare_pipe =>
        null;

      when run =>
        accumulate <= true;

      when stop_acc =>
        null;

      when reset_count =>
        null;

      when output_wait1 =>
        null;

      when output_wait2 =>
        null;

      when set_output =>
        null;

    end case;
  end process;

  ----------------------------------------------------------------------------
  -- Logic to set first address to read from.

  process (reset, clock)
  begin
    if reset = '0' then
      first_addr_i <= (others => '0');
    elsif rising_edge(clock) then
      if set_first_addr = '1' then
        first_addr_i <= unsigned(first_addr);
      end if;
    end if;
  end process;

end dft_arch;
