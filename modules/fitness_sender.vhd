-------------------------------------------------------------------------------
-- Title      : Fitness Sender
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : fitness_sender.vhd
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
use work.types.all;

entity fitness_sender is
  generic (
    send_buffer_size    : positive := 256;
    fitness_buffer_size : positive := 256
  );
  port (
    send_buffer_write : out std_logic;
    send_buffer_data  : out std_logic_vector(32 - 1 downto 0);
    send_buffer_count : in  std_logic_vector(bits(send_buffer_size) - 1 downto 0);

    fitness_buffer_read  : out std_logic;
    fitness_buffer_data  : in  std_logic_vector(32 - 1 downto 0);
    fitness_buffer_count : in  std_logic_vector(bits(fitness_buffer_size) - 1 downto 0);

    fitness_words_per_run : in std_logic_vector(8 - 1 downto 0);

    decode_operation : in fitness_sender_operation_type;

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end entity;

architecture rtl of fitness_sender is

  type state_type is (IDLE, WAIT_FOR_FITNESS, SEND_FITNESS);
  signal state : state_type := IDLE;

  signal words_to_send : unsigned(bits(fitness_buffer_size) - 1 downto 0);

  -- Buffer checks
  signal fitness_buffer_has_data : boolean;
  signal send_buffer_has_space   : boolean;

  -- Internally used out ports
  signal done_i : std_logic := '1';

begin

  -- Buffer checks
  fitness_buffer_has_data <= unsigned(fitness_buffer_count) >= unsigned(fitness_words_per_run);
  send_buffer_has_space   <= unsigned(send_buffer_count) < (send_buffer_size - 1 - unsigned(fitness_words_per_run));

  process begin
    wait until rising_edge(clock);
    case (state) is
      when IDLE =>
        if (run = '1' and decode_operation = SEND) then
          state <= WAIT_FOR_FITNESS;
          done_i <= '0';
        end if;

      when WAIT_FOR_FITNESS =>
        if (fitness_buffer_has_data and send_buffer_has_space) then
          state <= SEND_FITNESS;
        end if;
        words_to_send <= unsigned(fitness_words_per_run);

      when SEND_FITNESS =>
        if (words_to_send = 1) then
          state <= IDLE;
          done_i <= '1';
        end if;
        words_to_send <= words_to_send - 1;

    end case;
  end process;

  -- Transfer from fitness to send buffer
  process (state) begin
    if (state = SEND_FITNESS) then
      fitness_buffer_read <= '1';
      send_buffer_write   <= '1';
    else
      fitness_buffer_read <= '0';
      send_buffer_write   <= '0';
    end if;
  end process;

  -- Forward data
  send_buffer_data <= fitness_buffer_data;

  -- Internally used out ports
  done <= done_i;

end architecture;
