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

    fitness_count_per_run : out std_logic_vector(bits(fitness_buffer_size) - 1 downto 0);

    clock : in std_logic
  );
end entity;

architecture rtl of fitness_dft is

  --
  type state_type is (IDLE, RUN_DFT, COPY_RESULT);
  signal state : state_type := IDLE;

  -- DFT
  signal dft_result_slv : std_logic_vector((transform_size/2)*result_bits -1 downto 0);
  signal dft_run  : std_logic;
  signal dft_done : std_logic;

begin

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
