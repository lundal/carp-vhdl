-------------------------------------------------------------------------------
-- Title      : Fitness function
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fitness_funk.vhd
-- Author     : Kjetil Aamodt
-- Company    : 
-- Last update: 2005/05/23
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Fitness function which find a sequence of rising values
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2003/03/30  1.0      aamodt	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.sblock_package.all;

entity fitness_funk is

  port (
    ld_finished      : in std_logic;
    fitness_finished : out std_logic;
    active           : in std_logic;
    
    data       : in std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    result     : out std_logic_vector(FITNESS_RESULT_SIZE - 1 downto 0);

    -- hazard
    stall        :  in std_logic;

    -- other
    rst : in std_logic;
    clk : in std_logic);

end fitness_funk;

architecture fitness_funk_arch of fitness_funk is
  signal start_value : std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
  signal temp_value  : std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
 
  signal next_value : std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
  --finding loops on max 255 steps
  signal loop_counter, longest_loop : unsigned(7 downto 0);

begin

  -----------------------------------------------------------------------------
  -- pipeline stage
  -----------------------------------------------------------------------------
  process(clk, rst)
  begin
    if rst = '0' then
      result <= (others => '0');
    elsif rising_edge(clk) then
      if stall = '0' then
        if active = '0' then
          loop_counter <= (others => '0');
          longest_loop <= (others => '0');
          next_value <= (others => '0');
          start_value <= (others => '0');
          temp_value <= (others => '0');
        else  
          next_value <= std_logic_vector(unsigned(data) + 1);

          if data = next_value then
            -- inc counter
            loop_counter <= loop_counter + 1;
          else -- next value not (last value + 1)
            if loop_counter > longest_loop then
              start_value <= temp_value;             
              longest_loop <= loop_counter;
            end if;
            temp_value <= data;
            loop_counter <= to_unsigned(1, 8);
          end if;
        end if;

        -- fitness_finished has to be delayed same number of clk ticks
        -- as result (if pipelined)
        fitness_finished <= ld_finished;

        result(FITNESS_RESULT_SIZE - 1 downto RUN_STEP_DATA_BUS_SIZE + 8) <= (others => '0');
        result(RUN_STEP_DATA_BUS_SIZE - 1 + 8 downto 8) <= start_value;
        result(7 downto 0) <= std_logic_vector(longest_loop);
      end if;
    end if;
  end process;


end fitness_funk_arch;

