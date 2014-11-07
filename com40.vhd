-------------------------------------------------------------------------------
-- Title      : com40
-- Project    : 
-------------------------------------------------------------------------------
-- File       : com40.vhd
-- Author     : Asbjørn Djupdal  <djupdal@harryklein>
-- Company    : 
-- Last update: 2003/06/04
-- Platform   : BenERA, Virtex 1000E
-------------------------------------------------------------------------------
-- Description: Communicates with PCI FPGA, running at 40MHz
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2003/02/20  1.0      djupdal	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

entity com40 is
  
  port (
    -- send signals, see protocol description in report
    send         : in  std_logic;
    ack_send     : out std_logic;
    data_send    : in  std_logic_vector(63 downto 0);

    -- receive signals, see protocol description in report
    receive      : in  std_logic;
    ack_receive  : out std_logic;
    data_receive : out std_logic_vector(63 downto 0);

    -- signals for communicating with PCI-FPGA
    -- see BenERA users guide
    pciBusy   : in    std_logic;
    pciEmpty  : in    std_logic;
    pciRW     : out   std_logic;
    pciEnable : out   std_logic;
    pciData   : inout std_logic_vector(63 downto 0);

    rst   : in std_logic;
    clk40 : in std_logic);

end com40;

architecture com40Arch of com40 is

  type com_state_type is (idle, send_1, send_2, receive_1, receive_2);

  signal com_state : com_state_type;

  signal send_i     : std_logic;
  signal receive_i  : std_logic;
  signal send_ii    : std_logic;
  signal receive_ii : std_logic;

begin  -- com40Arch

  -- synchronize signals from fast clock domain with local clock
  process (rst, clk40)
  begin
    if rst = '0' then
      send_ii <= '0';
      receive_ii <= '0';
      send_i <= '0';
      receive_i <= '0';
    elsif rising_edge (clk40) then
      send_ii <= send;
      receive_ii <= receive;
      send_i <= send_ii;
      receive_i <= receive_ii;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- state machine, clocked part
  -----------------------------------------------------------------------------

  process (clk40, rst) 
  begin
    
    if rst = '0' then
      com_state <= idle;

    elsif rising_edge (clk40) then

      case com_state is

        -- wait for request
        when idle =>

          if send_i = '1' and pciBusy = '0' then
            com_state <= send_1;

          elsif receive_i = '1' and pciEmpty = '0' then
            com_state <= receive_1;

          else
            com_state <= idle;

          end if;

        -- send to PCI-FPGA
        when send_1 =>
          com_state <= send_2;

        -- acknowedge send
        when send_2 =>
          if send_i = '0' then
            com_state <= idle;
          else
            com_state <= send_2;
          end if;

        -- receive from PCI-FPGA
        when receive_1 =>
          com_state <= receive_2;
          data_receive <= pciData;

        -- acknowledge receive
        when receive_2 =>
          if receive_i = '0' then
            com_state <= idle;
          else
            com_state <= receive_2;
          end if;

        when others =>
          com_state <= idle;

      end case;
    end if;

  end process;

  -----------------------------------------------------------------------------
  -- state machine, comb. part
  -----------------------------------------------------------------------------

  process (rst, com_state, data_send)
  begin
    
    pciData <= (others => 'Z');
    pciEnable <= '1';
    pciRW <= '0';
    ack_send <= '0';
    ack_receive <= '0';

    case com_state is

      when idle =>
        null;

      when send_1 =>
        pciData <= data_send;
        pciEnable <= '0';
        pciRW <= '1'; -- WRITE

      when send_2 =>
        ack_send <= '1';

      when receive_1 =>
        pciEnable <= '0';
        pciRW <= '0'; -- READ

      when receive_2 =>
        ack_receive <= '1';

      when others =>
        null;

    end case;

  end process;

end com40Arch;
