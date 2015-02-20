
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_dsp is
end entity;

architecture behavior of test_dsp is 

  -- UUT
  signal A : std_logic_vector(17 downto 0);
  signal B : std_logic_vector(17 downto 0);
  signal D : std_logic_vector(17 downto 0);
  signal P : std_logic_vector(47 downto 0);

  signal d_sub_b    : boolean;
  signal a_mult_b   : boolean;
  signal accumulate : boolean;

  signal clock : std_logic;

  constant clock_period : time := 8 ns;

begin

  dsp : entity work.dsp_wrapper
  generic map (
    dsp48a1_implementation => true
  )
  port map (
    A => A,
    B => B,
    D => D,
    P => P,

    d_sub_b    => d_sub_b,
    a_mult_b   => a_mult_b,
    accumulate => accumulate,

    clock => clock
  );

  clock_process: process begin
    clock <= '1';
    wait for clock_period/2;
    clock <= '0';
    wait for clock_period/2;
  end process;

  -- Stimulus process
  stimulus: process begin

    -- Delay signals a bit to prevent clocked processes
    -- from using inputs from the new clock cycle.
    wait for clock_period/2;

    -- Test 1
    A <= std_logic_vector(to_signed(48, A'length));
    B <= std_logic_vector(to_signed(11, B'length));
    D <= std_logic_vector(to_signed(56, D'length));
    d_sub_b    <= false;
    a_mult_b   <= false;
    accumulate <= false;
    -- Res: P = (A*(D+B)) = 3216 (0xC90)

    wait for clock_period;

    -- Test 2
    A <= std_logic_vector(to_signed(48, A'length));
    B <= std_logic_vector(to_signed(11, B'length));
    D <= std_logic_vector(to_signed(56, D'length));
    d_sub_b    <= true;
    a_mult_b   <= false;
    accumulate <= false;
    -- Res: P = (A*(D-B)) = 2160 (0x870)

    wait for clock_period;

    -- Test 3
    A <= std_logic_vector(to_signed(48, A'length));
    B <= std_logic_vector(to_signed(11, B'length));
    D <= std_logic_vector(to_signed(56, D'length));
    d_sub_b    <= false;
    a_mult_b   <= true;
    accumulate <= false;
    -- Res: P = (A*B) = 528 (0x210)

    wait for clock_period;

    -- Test 4
    A <= std_logic_vector(to_signed(48, A'length));
    B <= std_logic_vector(to_signed(11, B'length));
    D <= std_logic_vector(to_signed(56, D'length));
    d_sub_b    <= false;
    a_mult_b   <= true;
    accumulate <= true;
    -- Res: P = P + (A*B) = 1056 (0x420)

    wait;

  end process;
end;
