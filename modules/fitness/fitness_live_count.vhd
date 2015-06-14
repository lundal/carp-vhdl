--------------------------------------------------------------------------------
-- Title       : Live Count Fitness
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Uses live count values as directly as fitness. Moves values
--             : from Live Count Buffer to Fitness Buffer when possible.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity fitness_live_count is
  generic (
    -- General fitness interface
    live_count_buffer_size : positive := 256;
    live_count_buffer_bits : positive := 10;
    fitness_buffer_size    : positive := 256
  );
  port (
    live_count_buffer_read  : out std_logic;
    live_count_buffer_data  : in  std_logic_vector(live_count_buffer_bits - 1 downto 0);
    live_count_buffer_count : in  std_logic_vector(bits(live_count_buffer_size) - 1 downto 0);

    fitness_buffer_write : out std_logic;
    fitness_buffer_data  : out std_logic_vector(32 - 1 downto 0);
    fitness_buffer_count : in  std_logic_vector(bits(fitness_buffer_size) - 1 downto 0);

    identifier    : out std_logic_vector(8 - 1 downto 0);
    words_per_run : out std_logic_vector(8 - 1 downto 0);
    parameters    : out std_logic_vector(16 - 1 downto 0);

    clock : in std_logic
  );
end entity;

architecture rtl of fitness_live_count is

  signal live_count_buffer_has_data_one : boolean;
  signal fitness_buffer_has_space_one : boolean;

begin

  -- Generic checks
  assert (fitness_buffer_size >= live_count_buffer_size) report "Unsupported fitness_buffer_size. Supported values are [live_count_buffer_size-N]." severity FAILURE;

  -- Information
  identifier    <= X"02";
  words_per_run <= std_logic_vector(to_unsigned(1, 8));
  parameters    <= (others => '0');

  -- Buffer checks
  live_count_buffer_has_data_one <= live_count_buffer_count /= (live_count_buffer_count'range => '0');
  fitness_buffer_has_space_one <= fitness_buffer_count /= (fitness_buffer_count'range => '1');

  -- Transfer whenever possible
  process (live_count_buffer_has_data_one, fitness_buffer_has_space_one) begin
    if (live_count_buffer_has_data_one and fitness_buffer_has_space_one) then
      live_count_buffer_read <= '1';
      fitness_buffer_write   <= '1';
    else
      live_count_buffer_read <= '0';
      fitness_buffer_write   <= '0';
    end if;
  end process;

  -- Forward data
  fitness_buffer_data <= std_logic_vector(resize(unsigned(live_count_buffer_data), fitness_buffer_data'length));

end architecture;
