-------------------------------------------------------------------------------
-- Title      : Framework for implementation of fitness function
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fitness.vhd
-- Author     : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/04/09
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Framwork for implementation of fitness function
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/04/09  2.0      stoevneng Added DFT to input
-- 2003/03/30  1.0      aamodt    Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.sblock_package.all;

entity fitness_pipe is

  port (
    dec_start_fitness: in std_logic;

    fitness_data     : out std_logic_vector(31 downto 0);
    read_enable      :  in std_logic;
    
    data_in  :  in std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    data_addr: out std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    dft_output : in dft_res_t;

    --number of run-step data to evaluate
    run_step_to_evaluate: in std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    
    -- hazard
    stall        :  in std_logic;
    fitness_idle : out std_logic;

    -- other
    rst : in std_logic;
    clk : in std_logic);

end fitness_pipe;

architecture fitness_pipe_arch of fitness_pipe is
  type fitness_state_type is (idle, fitness, wait_to_finish, write_result);
  signal fitness_state : fitness_state_type;

  -- signales for BRAM address counter
  signal counter_reset    : std_logic;
  signal counter_count    : std_logic;
  signal counter_count_to : unsigned (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal counter_finished : std_logic;
  signal mem_address      : std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);

  signal read_mem: std_logic;

  -- setup
  signal setup_finished: std_logic;
  signal setup_active: std_logic;
  -- load1
  signal load1_finished: std_logic;
  signal load1_active: std_logic;
  -- load2
  signal load2_finished: std_logic;
  signal load2_active: std_logic;
  
  -- fitness
  signal fitness_finished : std_logic;
  signal fitness_result   : std_logic_vector(FITNESS_RESULT_SIZE - 1 downto 0);

  signal result: std_logic_vector(FITNESS_RESULT_SIZE - 1 downto 0);
  
  signal data_in_i: std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);

begin
  -- address counter
  -- tell how many addresses which should be evaluated
  counter_count_to <= unsigned(run_step_to_evaluate);

  sum_counter: counter
    generic map (
      SIZE => RUN_STEP_ADDR_BUS_SIZE)
    port map (
      reset    => counter_reset,
      count    => counter_count,
      count_to => counter_count_to,
      zero     => open,
      finished => counter_finished,
      value    => mem_address,
      clk      => clk);
  
  process(clk, rst)
  begin
    if rst = '0' then
      fitness_state <= idle;
      setup_finished <= '0';
      result <= (others => '0');
      setup_active <= '0';  
      fitness_data <= (others => '0');
    elsif rising_edge(clk) then
      if stall = '0' then
        case fitness_state is
          when idle =>
            
            if dec_start_fitness = '1' then
              fitness_state <= fitness;
            end if;

            -- readback of data only possible in idle
            -- data is shifted out
            if read_enable = '1' then
              fitness_data <= result(FITNESS_RESULT_SIZE - 1 downto FITNESS_RESULT_SIZE - 32);
              result(FITNESS_RESULT_SIZE - 1 downto 32)
                <= result(FITNESS_RESULT_SIZE - 33 downto 0);
              result(31 downto 0) <= (others => '0');
            end if;
            
          when fitness =>
            setup_finished <= counter_finished;

            if counter_finished = '0' then
              fitness_state <= fitness;
              setup_active <= '1';
            else
              fitness_state <= wait_to_finish;
              setup_active <= '0';
            end if;
            
          when wait_to_finish =>
            if fitness_finished = '1' then
              fitness_state <= idle;
              -- store last value of fitness result
              result <= fitness_result;
            end if;

          when others =>
            fitness_state <= idle;

        end case;
      end if;
    end if;
  end process;

-------------------------------------------------------------------------------
-- comb. part of FSM

  process (fitness_state)
  begin
    fitness_idle <= '0';

    counter_reset <= '0';
    counter_count <= '0';

    read_mem <= '0';

    case fitness_state is
      when idle =>
        counter_reset <= '1';
        fitness_idle <= '1';

      when fitness =>
        counter_count <= '1';
        read_mem <= '1';
        
      when wait_to_finish =>
        null;

      when others => null;
    end case;
  end process;

  process(read_mem, mem_address)
  begin  -- process
    if read_mem = '1' then
      data_addr <= mem_address;
    else
      data_addr <= (others => 'Z');
    end if;
  end process;
  
  -----------------------------------------------------------------------------
  -- Load1
  -----------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge (clk) then
      if stall = '0' then
        load1_finished <= setup_finished;
        load1_active <= setup_active;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Load2
  -----------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge (clk) then
      if stall = '0' then
        load2_finished <= load1_finished;
        load2_active <= load1_active;
        data_in_i <= dft_output(to_integer(unsigned(mem_address)) mod 64)(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Fitness
  -----------------------------------------------------------------------------
  fitness_funk_unit: fitness_funk
    port map (
      ld_finished     => load2_finished,
      fitness_finished=> fitness_finished,
      active          => load2_active,
      data            => data_in_i,
      result          => fitness_result,
      stall           => stall,
      clk             => clk,
      rst             => rst);

end fitness_pipe_arch;
