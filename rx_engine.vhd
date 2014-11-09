-------------------------------------------------------------------------------
-- Title      : Reception Engine
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rx_engine.vhd
-- Author     : Per Thomas Lundal
-- Company    : NTNU
-- Last update: 2014/11/07
-- Platform   : Spartan-6 LX45T
-------------------------------------------------------------------------------
-- Description: Handles reception of PCIe packets
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/07  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rx_engine is
  generic (
    reverse_payload_endian : boolean
  );
  port (
    -- General
    clock      : in  std_logic;
    reset      : in  std_logic;
    link_up    : in  std_logic;
    device_id  : in  std_logic_vector(15 downto 0);
    -- Rx
    rx_ready   : out std_logic;
    rx_valid   : in  std_logic;
    rx_last    : in  std_logic;
    rx_data    : in  std_logic_vector(31 downto 0);
    rx_user    : in  std_logic_vector(21 downto 0);
    -- Request
    rq_ready   : in  std_logic;
    rq_valid   : out std_logic;
    rq_address : out std_logic_vector(31 downto 0);
    rq_length  : out std_logic_vector(9 downto 0);
    rq_id      : out std_logic_vector(15 downto 0);
    rq_tag     : out std_logic_vector(7 downto 0);
    rq_bar_hit : out std_logic_vector(5 downto 0);
    -- Buffer
    buffer_data  : out std_logic_vector(31 downto 0);
    buffer_count : in  std_logic_vector(31 downto 0); -- TODO: set rx_ready = 0 if writing data and buffer is full?
    buffer_write : out std_logic
  );
end rx_engine;

architecture rtl of rx_engine is

  constant TYPE_READ_32        : std_logic_vector(7 downto 0) := "00000000";
  constant TYPE_READ_64        : std_logic_vector(7 downto 0) := "00100000";
  constant TYPE_WRITE_32       : std_logic_vector(7 downto 0) := "01000000";
  constant TYPE_WRITE_64       : std_logic_vector(7 downto 0) := "01100000";

  type state_type is (
    IDLE,
    READ_DW1, READ_DW2, READ_WAIT,
    WRITE_DW1, WRITE_DW2, WRITE_DATA,
    DISCARD
  );

  signal state                 : state_type := IDLE;

  -- DW 0
  signal tlp_type              : std_logic_vector(7 downto 0);
  signal tlp_traffic_class     : std_logic_vector(2 downto 0);
  signal tlp_digest            : std_logic;
  signal tlp_poisoned          : std_logic;
  signal tlp_attributes        : std_logic_vector(1 downto 0);
  signal tlp_length            : std_logic_vector(9 downto 0);

  -- DW 1
  signal tlp_requester_id      : std_logic_vector(15 downto 0);
  signal tlp_tag               : std_logic_vector(7 downto 0);
  signal tlp_last_byte_enable  : std_logic_vector(3 downto 0);
  signal tlp_first_byte_enable : std_logic_vector(3 downto 0);

  -- DW 2+3
  signal tlp_address           : std_logic_vector(31 downto 0);

  -- Other
  signal tlp_bar_hit           : std_logic_vector(5 downto 0);
  signal tlp_remaining         : std_logic_vector(9 downto 0);

  -- Reverse Endian
  function reverse_endian(input : std_logic_vector) return std_logic_vector is
    variable output    : std_logic_vector(input'range);
    constant num_bytes : natural := input'length / 8;
  begin
    for i in 0 to num_bytes-1 loop
      for j in 7 downto 0 loop
        output(8*i + j) := input(8*(num_bytes-1-i) + j);
      end loop;
    end loop;
    return output;
  end function reverse_endian;

begin

  -- Request signals
  rq_address <= tlp_address;
  rq_length  <= tlp_length;
  rq_id      <= tlp_requester_id;
  rq_tag     <= tlp_tag;
  rq_bar_hit <= tlp_bar_hit;

  -- State dependant variables
  rx_ready <= '0' when state = READ_WAIT else '1';
  rq_valid <= '1' when state = READ_WAIT else '0';

  process begin
    wait until rising_edge(clock);
    --
    case (state) is
      when IDLE =>
        if (rx_valid = '1') then
          tlp_type          <= rx_data(31 downto 24);
          tlp_traffic_class <= rx_data(22 downto 20);
          tlp_digest        <= rx_data(15);
          tlp_poisoned      <= rx_data(14);
          tlp_attributes    <= rx_data(13 downto 12);
          tlp_length        <= rx_data(9 downto 0);
          tlp_remaining     <= rx_data(9 downto 0);
          --
          tlp_bar_hit       <= rx_user(7 downto 2);
          --
          case (rx_data(31 downto 24)) is
            when TYPE_READ_32 =>
              state <= READ_DW1;
            when TYPE_WRITE_32 =>
              state <= WRITE_DW1;
            when others =>
              state <= DISCARD;
          end case;
        end if;
        -- Buffer signal
        buffer_write <= '0';
        --
      when READ_DW1 =>
        if (rx_valid = '1') then
          tlp_requester_id      <= rx_data(31 downto 16);
          tlp_tag               <= rx_data(15 downto 8);
          tlp_last_byte_enable  <= rx_data(7 downto 4);
          tlp_first_byte_enable <= rx_data(3 downto 0);
          --
          state <= READ_DW2;
        end if;
        --
      when READ_DW2 =>
        if (rx_valid = '1') then
          tlp_address <= rx_data(31 downto 0);
          --
          state <= READ_WAIT;
        end if;
        --
      when READ_WAIT =>
        if (rq_ready = '1') then
          state <= IDLE;
        end if;
        --
      when WRITE_DW1 =>
        if (rx_valid = '1') then
          tlp_requester_id      <= rx_data(31 downto 16);
          tlp_tag               <= rx_data(15 downto 8);
          tlp_last_byte_enable  <= rx_data(7 downto 4);
          tlp_first_byte_enable <= rx_data(3 downto 0);
          --
          state <= WRITE_DW2;
        end if;
        --
      when WRITE_DW2 =>
        if (rx_valid = '1') then
          tlp_address <= rx_data(31 downto 0);
          --
          state <= WRITE_DATA;
        end if;
        --
      when WRITE_DATA =>
        if (rx_valid = '1') then
          if (reverse_payload_endian) then
            buffer_data <= reverse_endian(rx_data);
          else
            buffer_data  <= rx_data;
          end if;
          --
          tlp_remaining <= std_logic_vector(unsigned(tlp_remaining) - 1);
          if (tlp_remaining = "0000000001") then
            state   <= IDLE;
          end if;
        end if;
        -- Buffer signal
        if (rx_valid = '1') then
          buffer_write <= '1';
        else
          buffer_write <= '0';
        end if;
        --
      when DISCARD =>
        if (rx_valid = '1') then
          --
          if (rx_last = '1') then
            state <= IDLE;
          end if;
        end if;
        --
    end case;
  end process;

end rtl;
