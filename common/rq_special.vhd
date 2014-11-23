-------------------------------------------------------------------------------
-- Title      : Special Request Handler
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rq_special.vhd
-- Author     : Per Thomas Lundal
-- Company    : NTNU
-- Last update: 2014/11/23
-- Platform   : Spartan-6 LX45T
-------------------------------------------------------------------------------
-- Description: Handles special request packets
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/11/23  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rq_special is
  generic (
    tx_buffer_address_bits : integer;
    rx_buffer_address_bits : integer
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

  type state_type is (
    IDLE
  );

  signal state : state_type := IDLE;

begin

  rq_special <= '0';
  rq_special_data <= (others => '0');

end rtl;
