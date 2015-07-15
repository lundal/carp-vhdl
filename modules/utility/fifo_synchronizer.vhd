--------------------------------------------------------------------------------
-- Title       : FIFO Synchronizer
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Transfers data from one FIFO to another FIFO in a different
--             : clock domain (A -> B). It is handshake-based.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity fifo_synchronizer is
  generic (
    buffer_a_size : positive := 256;
    buffer_b_size : positive := 256;
    buffer_bits   : positive := 32
  );
  port (
    buffer_a_read  : out std_logic;
    buffer_a_data  : in  std_logic_vector(buffer_bits - 1 downto 0);
    buffer_a_count : in  std_logic_vector(bits(buffer_a_size) - 1 downto 0);

    buffer_b_write : out std_logic;
    buffer_b_data  : out std_logic_vector(buffer_bits - 1 downto 0);
    buffer_b_count : in  std_logic_vector(bits(buffer_b_size) - 1 downto 0);

    clock_a : in std_logic;
    clock_b : in std_logic
  );
end entity;

architecture rtl of fifo_synchronizer is

  type state_type is (
    IDLE, SYNC
  );

  signal state_a : state_type := IDLE;
  signal state_b : state_type := IDLE;

  signal buffer_a_has_data  : std_logic;
  signal buffer_b_has_space : std_logic;

  signal request_a : std_logic;
  signal request_t : std_logic;
  signal request_b : std_logic;

  signal ack_a : std_logic;
  signal ack_t : std_logic;
  signal ack_b : std_logic;

  signal data_a : std_logic_vector(buffer_bits - 1 downto 0);
  signal data_t : std_logic_vector(buffer_bits - 1 downto 0);
  signal data_b : std_logic_vector(buffer_bits - 1 downto 0);

begin

  -- Buffer checks
  buffer_a_has_data  <= '1' when buffer_a_count /= (buffer_a_count'range => '0') else '0';
  buffer_b_has_space <= '1' when buffer_b_count(buffer_b_count'high downto 1) /= (buffer_b_count'high downto 1 => '1') else '0';

  -- Clock domain A
  process begin
    wait until rising_edge(clock_a);

    -- Default
    buffer_a_read <= '0';

    case state_a is

      when IDLE =>
        if (buffer_a_has_data = '1' and ack_a = '0') then
          request_a <= '1';
          state_a   <= SYNC;
          -- Send data
          data_a        <= buffer_a_data;
          buffer_a_read <= '1';
        end if;

      when SYNC =>
        if (ack_a = '1') then
          request_a <= '0';
          state_a   <= IDLE;
        end if;

    end case;

    -- Synchronizers
    ack_t <= ack_b;
    ack_a <= ack_t;

  end process;

  -- Clock domain B
  process begin
    wait until rising_edge(clock_b);

    -- Default
    buffer_b_write <= '0';

    case state_b is

      when IDLE =>
        if (buffer_b_has_space = '1' and request_b = '1') then
          ack_b   <= '1';
          state_b <= SYNC;
        end if;

      when SYNC =>
        if (request_b = '0') then
          ack_b   <= '0';
          state_b <= IDLE;
          -- Receive data
          buffer_b_data  <= data_b;
          buffer_b_write <= '1';
        end if;

    end case;

    -- Synchronizers
    request_t <= request_a;
    request_b <= request_t;
    data_t <= data_a;
    data_b <= data_t;

  end process;

end architecture;
