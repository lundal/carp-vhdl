-------------------------------------------------------------------------------
-- Title      : Send Buffer Multiplexer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : send_buffer_mux.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-28
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Controls which component has access to the send buffer.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-28  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity send_buffer_mux is
  generic (
    send_buffer_address_bits : positive := 10
  );
  port (
    -- Cell Writer Reader
    cell_writer_reader_data  : in  std_logic_vector(31 downto 0);
    cell_writer_reader_count : out std_logic_vector(send_buffer_address_bits - 1 downto 0);
    cell_writer_reader_write : in  std_logic;

    -- Information Sender
    information_sender_data  : in  std_logic_vector(31 downto 0);
    information_sender_count : out std_logic_vector(send_buffer_address_bits - 1 downto 0);
    information_sender_write : in  std_logic;

    -- Buffer
    send_buffer_data  : out std_logic_vector(31 downto 0);
    send_buffer_count : in  std_logic_vector(send_buffer_address_bits - 1 downto 0);
    send_buffer_write : out std_logic;

    source_select : in send_buffer_mux_select_type;

    run : in std_logic;

    clock : in std_logic
  );
end send_buffer_mux;

architecture rtl of send_buffer_mux is

  signal source_select_i : send_buffer_mux_select_type := CELL_WRITER_READER;

begin

  process begin
    wait until rising_edge(clock) and run = '1';
    source_select_i <= source_select;
  end process;

  process (source_select_i, send_buffer_count,
           cell_writer_reader_data, cell_writer_reader_write,
           information_sender_data, information_sender_write) begin

    -- Defaults
    cell_writer_reader_count <= (others => '0');

    case source_select_i is

      when CELL_WRITER_READER =>
        send_buffer_data  <= cell_writer_reader_data;
        cell_writer_reader_count <= send_buffer_count;
        send_buffer_write <= cell_writer_reader_write;

      when INFORMATION_SENDER =>
        send_buffer_data  <= information_sender_data;
        information_sender_count <= send_buffer_count;
        send_buffer_write <= information_sender_write;

    end case;
  end process;

end rtl;
