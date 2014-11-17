-------------------------------------------------------------------------------
-- Title      : Memory for data generated at run-steps
-- Project    : 
-------------------------------------------------------------------------------
-- File       : runstep_mem.vhd
-- Author     : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/04/04
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Memory for data generated at run-step
--              Registers on both in and output
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/04/04  2.0      stoevneng Updated for more read.
-- 2005/02/28  1.0      aamodt	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

use work.sblock_package.all;

entity run_step_mem is
  port (
    address1     : in  std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    address2     : in  std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    data_read1   : out std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    data_read2   : out std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    data_write   : in  std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    write_enable : in  std_logic;
    read_enable  : in  std_logic;       -- not used

    stall : in std_logic;
    
    rst : in std_logic;
    clk : in std_logic);
end run_step_mem;

architecture run_step_mem_arch of run_step_mem is

  constant one : std_logic := '1';
  constant zero : std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0) := (others => '0');
  signal rst_i : std_logic;
  signal enable : std_logic;
----------------------------------------------------------------------------
begin



  rst_i <= not rst;
  enable <= '1';--not stall;

  runstep_mem : bram_inferrer
    generic map (
      addr_bits => RUN_STEP_ADDR_BUS_SIZE,
      data_bits => RUN_STEP_DATA_BUS_SIZE
    )
    port map (
      clk_a => clk,
      clk_b => clk,

      addr_a     => address1,
      data_i_a   => data_write,
      data_o_a   => data_read1,
      we_a       => write_enable,
      en_a       => enable,
      rst_a      => rst_i,
    
      addr_b     => address2,
      data_i_b   => zero,
      data_o_b   => data_read2,
      we_b       => zero(0),
      en_b       => enable,
      rst_b      => rst_i);

end run_step_mem_arch;
