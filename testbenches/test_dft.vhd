
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity test_dft is
  generic (
    input_buffer_size : positive := 256;
    input_buffer_bits : positive := 10;
    result_bits       : positive := 18;
    dsp_amount        : positive := 32;
    transform_size    : positive := 128;
    twiddle_precision : positive := 6
  );
end entity;
 
architecture behavior of test_dft is 

  signal input_buffer_read  : std_logic := '0';
  signal input_buffer_write : std_logic := '0';
  signal input_buffer_data_in  : std_logic_vector(input_buffer_bits - 1 downto 0);
  signal input_buffer_data_out : std_logic_vector(input_buffer_bits - 1 downto 0);
  signal input_buffer_count : std_logic_vector(bits(input_buffer_size) - 1 downto 0);

  signal result_slv : std_logic_vector((transform_size/2)*result_bits -1 downto 0);

  signal run  : std_logic := '0';
  signal done : std_logic := '0';

  signal clock : std_logic;

  constant clock_period : time := 8 ns;

  -- Test data

  type input_type is array(0 to transform_size - 1) of integer;
  signal input_array : input_type := (1004,21,1003,21,1003,21,1002,22,1002,22,1001,23,1001,23,1000,24,1000,24,999,25,999,25,998,26,998,26,997,27,997,27,996,28,996,28,995,28,995,29,994,29,994,30,993,30,993,31,992,31,992,32,991,32,991,33,990,33,990,34,989,34,989,35,988,35,988,36,987,36,987,37,986,37,986,38,985,38,985,39,984,39,984,40,983,40,983,41,982,41,982,42,981,42,981,43,980,43,980,44,979,44,979,45,978,45,978,46,977,46,977,48,975,49,974,49,975,48,975,48,975,48,975,48,975,48,975,48,975,48);

  -- Due to rounding errors, this test requires manual inspection of (dft -> result)
  -- Expected results are calculated using numpy real fft

  type expected_type is array(0 to transform_size/2 - 1) of integer;
  signal expected : expected_type := (65511,23,17,13,14,17,16,16,19,17,16,16,18,18,18,19,20,18,18,21,23,22,21,21,22,21,22,26,28,26,23,27,35,36,30,26,27,33,33,33,34,34,33,35,39,44,47,46,45,46,47,52,63,72,77,77,80,87,102,132,179,244,352,671);

begin

  dft : entity work.dft
  generic map (
    input_buffer_size => input_buffer_size,
    input_buffer_bits => input_buffer_bits,
    result_bits       => result_bits,
    dsp_amount        => dsp_amount,
    transform_size    => transform_size,
    twiddle_precision => twiddle_precision
  )
  port map (
    input_buffer_read  => input_buffer_read,
    input_buffer_data  => input_buffer_data_out,
    input_buffer_count => input_buffer_count,

    result_slv => result_slv,

    run  => run,
    done => done,

    clock => clock
  );

  input_buffer : entity work.fifo
  generic map (
    address_bits => bits(input_buffer_size),
    data_bits    => input_buffer_bits
  )
  port map (
    data_in    => input_buffer_data_in,
    data_out   => input_buffer_data_out,
    data_count => input_buffer_count,
    data_read  => input_buffer_read,
    data_write => input_buffer_write,
    reset      => '0',
    clock      => clock
  );

  clock_process: process begin
    clock <= '0';
    wait for clock_period/2;
    clock <= '1';
    wait for clock_period/2;
  end process;

  -- Stimulus process
  stimulus: process begin

    -- Write test data
    input_buffer_write <= '1';
    for i in 0 to transform_size - 1 loop
      input_buffer_data_in <= std_logic_vector(to_unsigned(input_array(i), input_buffer_bits));
      wait for clock_period;
    end loop;
    input_buffer_write <= '0';

    -- Start DFT
    run <= '1';
    wait for clock_period;
    run <= '0';

    wait;

  end process;

end;