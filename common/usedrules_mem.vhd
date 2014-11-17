-------------------------------------------------------------------------------
-- Title      : Memory for used rules for one dev-step
-- Project    : 
-------------------------------------------------------------------------------
-- File       : usedrules_mem.vhd
-- Author     : Kjetil Aamodt
-- Company    : 
-- Last update: 2005/05/25
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2005/04/02  1.0      aamodt	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

use work.sblock_package.all;

library unisim;

entity usedrules_mem is

  port (
    address_read  : in  std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);--512 addresses
    address_write : in  std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);--512 addresses
    data_read     : out std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
    data_write    : in  std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
    write_enable  : in  std_logic;

    stall: in std_logic;
    
    rst : in std_logic;
    clk : in std_logic);

end usedrules_mem;

architecture usedrules_mem_arch of usedrules_mem is
  type ram_type is array (2 ** USEDRULES_ADDR_BUS_SIZE - 1 downto 0)
    of std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  signal RAM : ram_type := (others => (others => '0'));

  signal read_a : std_logic_vector(USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  
  signal enable : std_logic;
  signal rst_i  : std_logic;

  signal write_enable_i : std_logic;

  signal address_write_i : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);
  signal address_read_i  : std_logic_vector (USEDRULES_ADDR_BUS_SIZE - 1 downto 0);

  signal data_write_i  : std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  signal data_read_i   : std_logic_vector (USEDRULES_DATA_BUS_SIZE - 1 downto 0);
  
begin
  rst_i <= not rst;
  enable <= not stall;
  
  process(clk, rst)
  begin 
    if rst = '0' then
      address_write_i <= (others => '0');
      address_read_i  <= (others => '0');
      data_read       <= (others => '0');
      write_enable_i  <= '0';
      
    elsif rising_edge(clk) then
      if stall = '0' then
        address_write_i <= address_write;
        write_enable_i  <= write_enable;
        data_write_i    <= data_write;
        
        address_read_i  <= address_read;
        data_read       <= RAM(conv_integer(read_a));
      end if;
    end if;

  end process;

  process (clk)
  begin
    if rising_edge (clk) then
      if stall = '0' then
        if (write_enable_i = '1') then
          RAM(conv_integer(address_write_i)) <= data_write_i;
        end if;
        read_a <= address_read_i;
      end if;
    end if;
  end process;

end usedrules_mem_arch;
