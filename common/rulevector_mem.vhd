-------------------------------------------------------------------------------
-- Title      : Memory for activated rules, compressed to 255 bits vector pr.
--              dev-step
-- Project    : 
-------------------------------------------------------------------------------
-- File       : rulevector_mem.vhd
-- Author     : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2013/12/10
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2013/12/10  2.0      stoevneng Updated to use inferred BRAM
-- 2005/04/01  1.0      aamodt    Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.sblock_package.all;

library unisim;

entity rulevector_mem is
  port (
    data_read    : out std_logic_vector (RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
    data_write   :  in std_logic_vector (RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
    write_enable :  in std_logic;
    reset_counter:  in std_logic;
    read_next    :  in std_logic;
    
    stall        :  in std_logic;
    
    rst : in std_logic;
    clk : in std_logic);
end rulevector_mem;

architecture rulevector_mem_arch of rulevector_mem is

  signal zero  : std_logic_vector(255 downto 0);
  signal one   : std_logic;

  signal enable : std_logic;
  signal rst_i : std_logic;

  signal address_i   : std_logic_vector (RULEVECTOR_ADDR_BUS_SIZE - 1 downto 0);
  signal data_read_i : std_logic_vector (RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);
  signal data_write_i: std_logic_vector (RULEVECTOR_DATA_BUS_SIZE - 1 downto 0);

  --address counter for rulevector memory
  signal count_addr : std_logic;
  signal addr_value : std_logic_vector(RULEVECTOR_ADDR_BUS_SIZE - 1 downto 0);
  signal addr_reset : std_logic;
  signal count_to   : unsigned(RULEVECTOR_ADDR_BUS_SIZE - 1 downto 0);
  
begin
  one <= '1';
  zero <= (others => '0');

  rst_i <= not rst;

  enable <= not stall;
  
  -----------------------------------------------------------------------------
  count_to <= to_unsigned(2**RULEVECTOR_ADDR_BUS_SIZE - 1, RULEVECTOR_ADDR_BUS_SIZE);

  rulevector_addr_counter: counter
    generic map (
      SIZE     => RULEVECTOR_ADDR_BUS_SIZE)
    port map (
      reset    => addr_reset,
      count    => count_addr,
      count_to => count_to,
      zero     => open,
      finished => open,
      value    => addr_value,
      clk      => clk);
 ------------------------------------------------------------------------------
  
  sum_mem : bram_inferrer
    generic map (
      addr_bits => 8,
      data_bits => 256
    )
    port map (
      clk_a => clk,
      clk_b => clk,

      addr_a     => address_i,
      data_i_a   => zero(255 downto 0),
      data_o_a   => data_read_i(255 downto 0),
      we_a       => zero(0),
      en_a       => enable,
      rst_a      => rst_i,

      addr_b     => address_i,
      data_i_b   => data_write_i(255 downto 0),
      data_o_b   => open,
      we_b       => write_enable,
      en_b       => one,
      rst_b      => rst_i);

  address_i <= addr_value;
  count_addr <= (write_enable or read_next) and not stall;

  process(clk, rst)
    begin

      if rst = '0' then
        data_read <= (others => '0');
        data_write_i <= (others => '0');
        addr_reset <= '1';
      elsif rising_edge(clk) then
        if stall = '0' then
          addr_reset <= reset_counter;
          data_read <= data_read_i;
          data_write_i <= data_write;
        end if;
     
      end if;
    end process;
end rulevector_mem_arch;
