-------------------------------------------------------------------------------
-- Title      : DSP Wrapper
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : dsp_wrapper.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: This module wraps a dsp slice, exposing wanted functionality.
--            : The logical part implements the exact same functionality as
--            : the dsp_only part, but is less resource efficient.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2015-02-20  1.0      lundal Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity dsp_wrapper is
  generic (
    dsp48a1_implementation : boolean := true
  );
  port (
    A : in  std_logic_vector(17 downto 0);
    B : in  std_logic_vector(17 downto 0);
    D : in  std_logic_vector(17 downto 0);
    P : out std_logic_vector(47 downto 0);

    d_sub_b    : in boolean;
    a_mult_b   : in boolean;
    accumulate : in boolean;

    clock : in std_logic
  );
end entity;

architecture rtl of dsp_wrapper is

  -- Input registers
  signal A_reg : signed(17 downto 0) := (others => '0');
  signal B_reg : signed(17 downto 0) := (others => '0');
  signal D_reg : signed(17 downto 0) := (others => '0');

  -- Operation registers
  signal d_sub_b_reg    : boolean := false;
  signal a_mult_b_reg   : boolean := false;
  signal accumulate_reg : boolean := false;

  -- Calculation
  signal M : signed (35 downto 0) := (others => '0');

  -- Output register
  signal P_reg : signed(47 downto 0) := (others => '0');

  signal OPMODE : std_logic_vector(7 downto 0);

begin

  logical : if (not dsp48a1_implementation) generate
    -- Input registers
    process begin
      wait until rising_edge(clock);
      A_reg <= signed(A);
      B_reg <= signed(B);
      D_reg <= signed(D);
    end process;

    -- Operation registers
    process begin
      wait until rising_edge(clock);
      d_sub_b_reg    <= d_sub_b;
      a_mult_b_reg   <= a_mult_b;
      accumulate_reg <= accumulate;
    end process;

    -- Calculate
    process (A_reg, B_reg, D_reg, a_mult_b_reg, d_sub_b_reg) begin
      if (a_mult_b_reg) then
        M <= A_reg * B_reg;
      else
        if (d_sub_b_reg) then
          M <= A_reg * (D_reg - B_reg);
        else
          M <= A_reg * (D_reg + B_reg);
        end if;
      end if;
    end process;

    -- Accumulate
    process begin
      wait until rising_edge(clock);
      if (accumulate_reg) then
        P_reg <= P_reg + resize(M, 48);
      else
        P_reg <= resize(M, 48);
      end if;
    end process;

    -- Output
    P <= std_logic_vector(P_reg);
  end generate;

  dsp_only : if (dsp48a1_implementation) generate
    -- Set operation mode
    OPMODE(7) <= '0';
    OPMODE(6) <= '1' when d_sub_b else '0';
    OPMODE(5) <= '0';
    OPMODE(4) <= '0' when a_mult_b else '1';
    OPMODE(3 downto 2) <= "10" when accumulate else "00";
    OPMODE(1 downto 0) <= "01";

    -- See UG389 for details
    dsp : DSP48A1
    generic map (
      A0REG       => 1,         -- first stage A input pipeline register (0/1)
      A1REG       => 0,         -- Second stage A input pipeline register (0/1)
      B0REG       => 1,         -- first stage B input pipeline register (0/1)
      B1REG       => 0,         -- Second stage B input pipeline register (0/1)
      CARRYINREG  => 0,         -- CARRYIN input pipeline register (0/1)
      CARRYINSEL  => "OPMODE5", -- Specify carry-in source, "CARRYIN" or "OPMODE5" 
      CARRYOUTREG => 0,         -- CARRYOUT output pipeline register (0/1)
      CREG        => 0,         -- C input pipeline register (0/1)
      DREG        => 1,         -- D pre-adder input pipeline register (0/1)
      MREG        => 0,         -- M pipeline register (0/1)
      OPMODEREG   => 1,         -- Enable=1/disable=0 OPMODE input pipeline registers
      PREG        => 1,         -- P output pipeline register (0/1)
      RSTTYPE     => "SYNC"     -- Specify reset type, "SYNC" or "ASYNC"
    )
    port map (
      -- Cascade Ports: 18-bit (each) output Ports to cascade from one DSP48 to another
      BCOUT => open, -- 18-bit output B port cascade output
      PCOUT => open, -- 48-bit output P cascade output (if used, connect to PCIN of another DSP48A1)

      -- Data Ports: 1-bit (each) output Data input and output ports
      CARRYOUT  => open, -- 1-bit output carry output (if used, connect to CARRYIN pin of another DSP48A1)
      CARRYOUTF => open, -- 1-bit output fabric carry output
      M         => open, -- 36-bit output fabric multiplier data output
      P         => P,    -- 48-bit output data output

      -- Cascade Ports: 48-bit (each) input Ports to cascade from one DSP48 to another
      PCIN => open,  -- 48-bit input P cascade input (if used, connect to PCOUT of another DSP48A1)

      -- Control Input Ports: 1-bit (each) input Clocking and operation mode
      CLK    => clock,  -- 1-bit input clock input
      OPMODE => OPMODE, -- 8-bit input operation mode input

      -- Data Ports: 18-bit (each) input Data input and output ports
      A       => A,               -- 18-bit input A data input
      B       => B,               -- 18-bit input B data input (connected to fabric or BCOUT of adjacent DSP48A1)
      C       => (others => '0'), -- 48-bit input C data input
      CARRYIN => '0',             -- 1-bit input carry input signal (if used, connect to CARRYOUT pin of another DSP48A1)
      D       => D,               -- 18-bit input B pre-adder data input

      -- Reset/Clock Enable Input Ports: 1-bit (each) input Reset and enable input ports
      CEA        => '1', -- 1-bit input active high clock enable input for A registers
      CEB        => '1', -- 1-bit input active high clock enable input for B registers
      CEC        => '0', -- 1-bit input active high clock enable input for C registers
      CECARRYIN  => '0', -- 1-bit input active high clock enable input for CARRYIN registers
      CED        => '1', -- 1-bit input active high clock enable input for D registers
      CEM        => '0', -- 1-bit input active high clock enable input for multiplier registers
      CEOPMODE   => '1', -- 1-bit input active high clock enable input for OPMODE registers
      CEP        => '1', -- 1-bit input active high clock enable input for P registers
      RSTA       => '0', -- 1-bit input reset input for A pipeline registers
      RSTB       => '0', -- 1-bit input reset input for B pipeline registers
      RSTC       => '0', -- 1-bit input reset input for C pipeline registers
      RSTCARRYIN => '0', -- 1-bit input reset input for CARRYIN pipeline registers
      RSTD       => '0', -- 1-bit input reset input for D pipeline registers
      RSTM       => '0', -- 1-bit input reset input for M pipeline registers
      RSTOPMODE  => '0', -- 1-bit input reset input for OPMODE pipeline registers
      RSTP       => '0'  -- 1-bit input reset input for P pipeline registers
    );
  end generate;

end rtl;
