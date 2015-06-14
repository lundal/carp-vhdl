--------------------------------------------------------------------------------
-- Title       : Fetch Communication
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Fetches instructions from Receive Buffer
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fetch_communication is
  generic (
    buffer_address_bits : positive := 8;
    instruction_bits    : positive := 256
  );
  port (
    buffer_data  : in  std_logic_vector(31 downto 0);
    buffer_count : in  std_logic_vector(buffer_address_bits - 1 downto 0);
    buffer_read  : out std_logic;

    instruction : out std_logic_vector(instruction_bits - 1 downto 0);

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end fetch_communication;

architecture rtl of fetch_communication is

  type state_type is (
    FETCH_FIRST,
    FETCH_1, FETCH_2, FETCH_3, FETCH_4, FETCH_5, FETCH_6, FETCH_7
  );

  signal state : state_type := FETCH_FIRST;

  signal running : std_logic;

  signal buffer_has_data : boolean;

  signal instruction_length : unsigned(2 downto 0);

  -- Internally used out ports
  signal instruction_i : std_logic_vector(instruction_bits - 1 downto 0) := (others => '0');
  signal done_i        : std_logic := '1';

begin

  -- Generic checks
  assert (instruction_bits = 256) report "Unsupported instruction_bits. Supported values are [256]." severity FAILURE;

  running <= run or not done_i;

  buffer_has_data <= unsigned(buffer_count) /= 0;
  buffer_read     <= '1' when buffer_has_data and running = '1' else '0';

  process begin
    wait until rising_edge(clock);

    -- Reset done signal when starting by default
    if (run = '1') then
      done_i <= '0';
    end if;

    case state is

      when FETCH_FIRST =>
        if (buffer_has_data and running = '1') then
          instruction_i <= (others => '0'); -- Clear any old data
          instruction_i(31 downto 0) <= buffer_data;
          instruction_length <= unsigned(buffer_data(7 downto 5));
          if (unsigned(buffer_data(7 downto 5)) = 0) then
            state <= FETCH_FIRST;
            done_i <= '1';
          else
            state <= FETCH_1;
          end if;
        end if;

      when FETCH_1 =>
        if (buffer_has_data) then
          instruction_i(63 downto 32) <= buffer_data;
          if (instruction_length = 1) then
            state <= FETCH_FIRST;
            done_i <= '1';
          else
            state <= FETCH_2;
          end if;
        end if;

      when FETCH_2 =>
        if (buffer_has_data) then
          instruction_i(95 downto 64) <= buffer_data;
          if (instruction_length = 2) then
            state <= FETCH_FIRST;
            done_i <= '1';
          else
            state <= FETCH_3;
          end if;
        end if;

      when FETCH_3 =>
        if (buffer_has_data) then
          instruction_i(127 downto 96) <= buffer_data;
          if (instruction_length = 3) then
            state <= FETCH_FIRST;
            done_i <= '1';
          else
            state <= FETCH_4;
          end if;
        end if;

      when FETCH_4 =>
        if (buffer_has_data) then
          instruction_i(159 downto 128) <= buffer_data;
          if (instruction_length = 4) then
            state <= FETCH_FIRST;
            done_i <= '1';
          else
            state <= FETCH_5;
          end if;
        end if;

      when FETCH_5 =>
        if (buffer_has_data) then
          instruction_i(191 downto 160) <= buffer_data;
          if (instruction_length = 5) then
            state <= FETCH_FIRST;
            done_i <= '1';
          else
            state <= FETCH_6;
          end if;
        end if;

      when FETCH_6 =>
        if (buffer_has_data) then
          instruction_i(223 downto 192) <= buffer_data;
          if (instruction_length = 6) then
            state <= FETCH_FIRST;
            done_i <= '1';
          else
            state <= FETCH_7;
          end if;
        end if;

      when FETCH_7 =>
        if (buffer_has_data) then
          instruction_i(255 downto 224) <= buffer_data;
          state <= FETCH_FIRST;
          done_i <= '1';
        end if;

    end case;
  end process;

  -- Internally used out ports
  instruction <= instruction_i;
  done <= done_i;

end rtl;
