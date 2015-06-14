--------------------------------------------------------------------------------
-- Title       : Request Handler
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Handles special request packets
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2014  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rq_special is
  generic (
    tx_buffer_address_bits : positive;
    rx_buffer_address_bits : positive
  );
  port (
    -- General
    clock      : in  std_logic;
    reset      : in  std_logic;
    link_up    : in  std_logic;
    device_id  : in  std_logic_vector(15 downto 0);
    -- Request
    rq_ready   : in  std_logic;
    rq_valid   : in  std_logic;
    rq_address : in  std_logic_vector(31 downto 0);
    rq_bar_hit : in  std_logic_vector(5 downto 0);
    -- Special
    rq_special      : out std_logic;
    rq_special_data : out std_logic_vector(31 downto 0);
    -- Buffers
    tx_buffer_count : in  std_logic_vector(tx_buffer_address_bits - 1 downto 0);
    rx_buffer_count : in  std_logic_vector(rx_buffer_address_bits - 1 downto 0)
  );
end rq_special;

architecture rtl of rq_special is

  -- Usage of 10 least significant bits assume BAR size is set to 1024 bytes or more
  -- Note: The two last bits of an address are always zero (DW aligned).
  constant RQ_TX_BUFFER_COUNT : std_logic_vector(9 downto 2) := x"00";
  constant RQ_TX_BUFFER_SPACE : std_logic_vector(9 downto 2) := x"01";
  constant RQ_RX_BUFFER_COUNT : std_logic_vector(9 downto 2) := x"02";
  constant RQ_RX_BUFFER_SPACE : std_logic_vector(9 downto 2) := x"03";

begin

  rq_special <= not rq_bar_hit(0);

  process (rq_address, tx_buffer_count, rx_buffer_count, rq_bar_hit) begin
    -- Default
    rq_special_data <= (others => '0');

    -- BAR 1
    if (rq_bar_hit(1) = '1') then
      case (rq_address(9 downto 2)) is

        when RQ_TX_BUFFER_COUNT =>
          rq_special_data <= std_logic_vector(resize(unsigned(tx_buffer_count), 32));

        when RQ_TX_BUFFER_SPACE =>
          rq_special_data <= std_logic_vector(resize(2**tx_buffer_address_bits - unsigned(tx_buffer_count) - 1, 32));

        when RQ_RX_BUFFER_COUNT =>
          rq_special_data <= std_logic_vector(resize(unsigned(rx_buffer_count), 32));

        when RQ_RX_BUFFER_SPACE =>
          rq_special_data <= std_logic_vector(resize(2**rx_buffer_address_bits - unsigned(rx_buffer_count) - 1, 32));

        when others =>
          rq_special_data <= (others => '0');

      end case;
    end if;
  end process;

end rtl;
