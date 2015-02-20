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
  signal OPMODE    : a8 := (others => (others => '0'));
  signal A        : a18 := (others => (others => '0'));
  signal B        : a18 := (others => (others => '0'));
  signal D        : a18 := (others => (others => '0'));
  signal do_acc   : std_logic := '0';
  signal dont_acc : std_logic;

begin

  dont_acc <= not do_acc;

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
    dsp_i: DSP48A1
      generic map (
        A0REG => 1,           -- first stage A input pipeline register (0/1)
        A1REG => 0,           -- Second stage A input pipeline register (0/1)
        B0REG => 1,           -- first stage B input pipeline register (0/1)
        B1REG => 0,           -- Second stage B input pipeline register (0/1)
        CARRYINREG => 0,      -- CARRYIN input pipeline register (0/1)
        CARRYINSEL => "OPMODE5", -- Specify carry-in source, "CARRYIN" or "OPMODE5" 
        CARRYOUTREG => 0,     -- CARRYOUT output pipeline register (0/1)
        CREG => 0,            -- C input pipeline register (0/1)
        DREG => 1,            -- D pre-adder input pipeline register (0/1)
        MREG => 0,            -- M pipeline register (0/1)
        OPMODEREG => 1,       -- Enable=1/disable=0 OPMODE input pipeline registers
        PREG => 1,            -- P output pipeline register (0/1)
        RSTTYPE => "SYNC"     -- Specify reset type, "SYNC" or "ASYNC"
      )
      port map (
        -- Cascade Ports: 18-bit (each) output Ports to cascade from one DSP48 to another
        BCOUT => open,        -- 18-bit output B port cascade output
        PCOUT => open,        -- 48-bit output P cascade output (if used, connect to PCIN of another DSP48A1)
        -- Data Ports: 1-bit (each) output Data input and output ports
        CARRYOUT => open,     -- 1-bit output carry output (if used, connect to CARRYIN pin of another
                              -- DSP48A1)
        CARRYOUTF => open,    -- 1-bit output fabric carry output
        M => open,            -- 36-bit output fabric multiplier data output
        P => P(i),            -- 48-bit output data output
        -- Cascade Ports: 48-bit (each) input Ports to cascade from one DSP48 to another
        PCIN => open,         -- 48-bit input P cascade input (if used, connect to PCOUT of another DSP48A1)
        -- Control Input Ports: 1-bit (each) input Clocking and operation mode
        CLK => clock,           -- 1-bit input clock input
        OPMODE => OPMODE(i),  -- 8-bit input operation mode input
        -- Data Ports: 18-bit (each) input Data input and output ports
        A => A(i),            -- 18-bit input A data input
        B => B(i),            -- 18-bit input B data input (connected to fabric or BCOUT of adjacent DSP48A1)
        C => (others => '0'),                   -- 48-bit input C data input
        CARRYIN => '0',       -- 1-bit input carry input signal (if used, connect to CARRYOUT pin of another
                                  -- DSP48A1)

        D => D(i),                   -- 18-bit input B pre-adder data input
        -- Reset/Clock Enable Input Ports: 1-bit (each) input Reset and enable input ports
        CEA => '1',               -- 1-bit input active high clock enable input for A registers
        CEB => '1',               -- 1-bit input active high clock enable input for B registers
        CEC => '0',               -- 1-bit input active high clock enable input for C registers
        CECARRYIN => '0',   -- 1-bit input active high clock enable input for CARRYIN registers
        CED => '1',               -- 1-bit input active high clock enable input for D registers
        CEM => '0',               -- 1-bit input active high clock enable input for multiplier registers
        CEOPMODE => '1',     -- 1-bit input active high clock enable input for OPMODE registers
        CEP => do_acc,               -- 1-bit input active high clock enable input for P registers
        RSTA => '0',             -- 1-bit input reset input for A pipeline registers
        RSTB => '0',             -- 1-bit input reset input for B pipeline registers
        RSTC => '0',             -- 1-bit input reset input for C pipeline registers
        RSTCARRYIN => '0', -- 1-bit input reset input for CARRYIN pipeline registers
        RSTD => '0',             -- 1-bit input reset input for D pipeline registers
        RSTM => '0',             -- 1-bit input reset input for M pipeline registers
        RSTOPMODE => '0',   -- 1-bit input reset input for OPMODE pipeline registers
        RSTP => dont_acc              -- 1-bit input reset input for P pipeline registers
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

  process(feed_dsp, counter_runs, data_in, twiddle_out, P)
  begin
    for i in 0 to DFT_DSPS-1 loop
      OPMODE(i) <= (others => '0');
      A(i) <= (others => '0');
      B(i) <= (others => '0');
      D(i) <= (others => '0');
    end loop;
    if feed_dsp = "01" then
      -- Multiply input with twiddles
      for i in 0 to PERRUN-1 loop

        -- Multiply mode: P = A*B
        OPMODE(i*2) <= "00001001";
        OPMODE(i*2+1) <= "00001001";

        -- Twiddles (sign extended)
        A(i*2) <= std_logic_vector(resize(signed(twiddle_out((counter_runs-1)*PERRUN+i)(TWLEN-1 downto TWLEN/2)), A(i*2)'length)); -- Real part
        A(i*2+1) <= std_logic_vector(resize(signed(twiddle_out((counter_runs-1)*PERRUN+i)(TWLEN/2-1 downto 0)), A(i*2+1)'length)); -- Imaginary part

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
        if (P(i*2+1)(VALSIZE-1+TWIDDLE_PRECISION) = '1' and P(i*2)(VALSIZE-1+TWIDDLE_PRECISION*2) = '1') then
          OPMODE(i*2) <= "00010001";
          A(i*2) <= "111111111111111111";

        -- If imaginary part is negative
        -- P = (D-B)*1
        elsif (P(i*2+1)(VALSIZE-1+TWIDDLE_PRECISION) = '1' and P(i*2)(VALSIZE-1+TWIDDLE_PRECISION) = '0') then
          OPMODE(i*2) <= "01010001";
          A(i*2) <= "000000000000000001";

        -- If real part is negative
        -- P = (D-B)*(-1)
        elsif (P(i*2+1)(VALSIZE-1+TWIDDLE_PRECISION) = '0' and P(i*2)(VALSIZE-1+TWIDDLE_PRECISION) = '1') then
          OPMODE(i*2) <= "01010001";
          A(i*2) <= "111111111111111111";

        -- If no parts are negative
        -- P = (D+B)*1
        else
          OPMODE(i*2) <= "00010001";
          A(i*2) <= "000000000000000001";

        end if;
      end loop;
    else
      for i in 0 to DFT_DSPS-1 loop
        OPMODE(i) <= (others => '0');
        A(i) <= (others => '0');
        B(i) <= (others => '0');
        D(i) <= (others => '0');
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
        do_acc <= '0';
        dft_idle <= '1';

      when prepare_pipe =>
        null;

      when run =>
        do_acc <= '1';

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
