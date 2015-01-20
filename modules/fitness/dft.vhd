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
  type carray is array(0 to 7) of integer;
  constant STARTS	: carray := (
	  0*PERRUN,
	  1*PERRUN,
	  2*PERRUN,
	  3*PERRUN,
	  4*PERRUN,
	  5*PERRUN,
	  6*PERRUN,
	  7*PERRUN
  );

  constant zero : std_logic_vector(63 downto 0) := (others => '0');
  constant one : std_logic_vector(6 downto 0) := (others => '1');


  type dft_state_type is (idle, prepare_pipe, run, stop_acc, reset_count,
                          output_wait1, output_wait2, set_output);
  signal dft_state : dft_state_type;

  
  signal cnt : unsigned(6 downto 0);
  signal cnt2 : integer := 0;
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
        RSTTYPE => "SYNC")    -- Specify reset type, "SYNC" or "ASYNC"
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
      cnt <= (others => '0');
      cnt2 <= 0;
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
          cnt2 <= 0;
        when prepare_pipe =>
          dft_state <= run;
          twiddle_index <= twiddle_index + 1;
          cnt <= cnt + 1;
          feed_dsp <= "01";

        when run =>
          twiddle_index <= twiddle_index + 1;
          if cnt = unsigned(one(cnt'length - 1 downto 0)) then
            dft_state <= stop_acc;
          else
            dft_state <= run;
          end if;
          cnt <= cnt + 1;
          feed_dsp <= "01";

        when stop_acc =>
          dft_state <= reset_count;
          feed_dsp <= "00";

        when reset_count =>
          dft_state <= output_wait1;
          cnt <= (others => '0');
          feed_dsp <= "10";


        when output_wait1 =>
          dft_state <= output_wait2;

        when output_wait2 =>
          dft_state <= set_output;
          cnt2 <= cnt2 + 1;

        when set_output =>
          for i in 0 to PERRUN - 1 loop
            output(i+STARTS(cnt2-1)) <= P(i*2)(17 downto 0);
          end loop;
          feed_dsp <= "00";
          
          -- Check if finished
          if cnt2 = PERDSP then
            dft_state <= idle;
          else
            dft_state <= run;
          end if;
      end case;
    end if;
  end process;

  process(feed_dsp, data_in, twiddle_out, P)
  begin
    for i in 0 to DFT_DSPS-1 loop
      OPMODE(i) <= (others => '0');
      A(i) <= (others => '0');
      B(i) <= (others => '0');
      D(i) <= (others => '0');
    end loop;
    if feed_dsp = "01" then
      for i in 0 to PERRUN-1 loop
        B(i*2)(DFT_INW-1 downto 0) <= data_in;
        B(i*2+1)(DFT_INW-1 downto 0) <= data_in;
        OPMODE(i*2) <= "00001001";
        OPMODE(i*2+1) <= "00001001";
        if(twiddle_out(i)(TWLEN-1)='1') then
          A(i*2) <= "1111111111" & twiddle_out(i)(TWLEN-1 downto TWLEN/2);
        else
          A(i*2) <= "0000000000" & twiddle_out(i)(TWLEN-1 downto TWLEN/2);
        end if;
        if(twiddle_out(i)(TWLEN/2-1)='1') then
          A(i*2+1) <= "1111111111" & twiddle_out(i)(TWLEN/2-1 downto 0);
        else
          A(i*2+1) <= "0000000000" & twiddle_out(i)(TWLEN/2-1 downto 0);
        end if;
      end loop;
    elsif feed_dsp = "10" then
      for i in 0 to PERRUN-1 loop
        D(i*2) <= P(i*2)(VALSIZE-1+TW_PRES downto TW_PRES);
        B(i*2) <= P(i*2+1)(VALSIZE-1+TW_PRES downto TW_PRES);
        if (P(i*2+1)(VALSIZE-1+TW_PRES) = '1' and P(i*2)(VALSIZE-1+TW_PRES*2) = '1') then
          OPMODE(i*2) <= "00010001";
          A(i*2) <= "111111111111111111";
        elsif (P(i*2+1)(VALSIZE-1+TW_PRES) = '1' and P(i*2)(VALSIZE-1+TW_PRES) = '0') then
          OPMODE(i*2) <= "01010001";
          A(i*2) <= "000000000000000001";
        elsif (P(i*2+1)(VALSIZE-1+TW_PRES) = '0' and P(i*2)(VALSIZE-1+TW_PRES) = '1') then
          OPMODE(i*2) <= "01010001";
          A(i*2) <= "111111111111111111";
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

  process (dft_state, first_addr_i,cnt)
  begin
    data_addr <= std_logic_vector(first_addr_i + cnt);
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