-------------------------------------------------------------------------------
-- Title      : COM40 Compatibility Layer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : com40_compatiblility_layer.vhd
-- Author     : Per Thomas Lundal
-- Company    : NTNU
-- Last update: 2014/11/09
-- Platform   : Spartan-6 LX45T
-------------------------------------------------------------------------------
-- Description: Allows usage of the PCIe communication module without rewriting
--              the Fetch and Load-Send-Store units
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/09  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity com40_compatibility_layer is
  generic (
    tx_buffer_address_bits : integer := 10; -- PCIe packet length field is 10 bits
    rx_buffer_address_bits : integer := 10;
    reverse_payload_endian : boolean := true -- Required for x86 systems
  );
  port (
    -- COM40
    send         : in  std_logic;
    ack_send     : out std_logic;
    data_send    : in  std_logic_vector(63 downto 0);
    
    receive      : in  std_logic;
    ack_receive  : out std_logic;
    data_receive : out std_logic_vector(63 downto 0);

    -- PCIe
    tx_buffer_data  : out std_logic_vector(31 downto 0);
    tx_buffer_count : in  std_logic_vector(tx_buffer_address_bits - 1 downto 0);
    tx_buffer_write : out std_logic;

    rx_buffer_data  : in  std_logic_vector(31 downto 0);
    rx_buffer_count : in  std_logic_vector(rx_buffer_address_bits - 1 downto 0);
    rx_buffer_read  : out std_logic;

    -- System
    clock : in  std_logic;
    reset : in  std_logic
  );
end com40_compatibility_layer;

architecture rtl of com40_compatibility_layer is

  type tx_state_type is (IDLE, WRITE_DW1, WRITE_DW2, WRITE_WAIT);
  type rx_state_type is (IDLE, READ_DW1, READ_DW2, READ_WAIT);

  signal tx_state : tx_state_type := IDLE;
  signal rx_state : rx_state_type := IDLE;
  
  signal tx_has_space : boolean;
  signal rx_has_data  : boolean;

begin

  tx_has_space <= unsigned(tx_buffer_count) <= 500;
  rx_has_data  <= unsigned(rx_buffer_count) >= 2;

  process begin
    wait until rising_edge(clock);
    --
    case (tx_state) is
      when IDLE =>
        ack_send <= '0';
        --
        tx_buffer_write <= '0';
        --
        if (send = '1' and tx_has_space) then
          tx_state <= WRITE_DW1;
        end if;
      when WRITE_DW1 =>
        if (reverse_payload_endian) then
          tx_buffer_data <= data_send(31 downto 0);
        else
          tx_buffer_data <= data_send(63 downto 32);
        end if;
        tx_buffer_write <= '1';
        --
        tx_state <= WRITE_DW2;
      when WRITE_DW2 =>
        ack_send <= '1';
        --
        if (reverse_payload_endian) then
          tx_buffer_data <= data_send(63 downto 32);
        else
          tx_buffer_data <= data_send(31 downto 0);
        end if;
        tx_buffer_write <= '1';
        --
        tx_state <= WRITE_WAIT;
      when WRITE_WAIT =>
        tx_buffer_write <= '0';
        --
        if (send = '0') then
          tx_state <= IDLE;
        end if;
    end case;
  end process;

  process begin
    wait until rising_edge(clock);
    --
    case (rx_state) is
      when IDLE =>
        ack_receive <= '0';
        --
        rx_buffer_read <= '0';
        --
        if (receive = '1' and rx_has_data) then
          rx_state <= READ_DW1;
          rx_buffer_read <= '1'; -- Set earlier than write signal due to timing
        end if;
      when READ_DW1 =>
        if (reverse_payload_endian) then
          data_receive(31 downto 0) <= rx_buffer_data;
        else
          data_receive(63 downto 32) <= rx_buffer_data;
        end if;
        rx_buffer_read <= '1';
        --
        rx_state <= READ_DW2;
      when READ_DW2 =>
        ack_receive <= '1';
        --
        if (reverse_payload_endian) then
          data_receive(63 downto 32) <= rx_buffer_data;
        else
          data_receive(31 downto 0) <= rx_buffer_data;
        end if;
        rx_buffer_read <= '0';
        --
        rx_state <= READ_WAIT;
      when READ_WAIT =>
        rx_buffer_read <= '0';
        --
        if (receive = '0') then
          rx_state <= IDLE;
        end if;
    end case;
  end process;

end rtl;
