-------------------------------------------------------------------------------
-- Title      : Instruction Memory
-- Project    : 
-------------------------------------------------------------------------------
-- File       : instrmem.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/01/08
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: A wrapper for the instruction memory BRAMs
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/01/08  2.1      stoevneng Updated to support N-bit instructions
-- 2013/12/10  2.0      stoevneng Updated to use inferred BRAM
-- 2003/04/03  1.0      djupdal   Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

library unisim;

entity instr_mem is

  port (
    addr : in  std_logic_vector(INSTR_ADDR_SIZE - 1 downto 0);

    data_read    : out std_logic_vector(INSTR_SIZE - 1 downto 0);
    data_write   : in  std_logic_vector(INSTR_SIZE - 1 downto 0);
    write_enable : in  std_logic;

    stall : in std_logic;

    rst : in std_logic;
    clk : in std_logic);

end instr_mem;

architecture instr_mem_arch of instr_mem is

  signal zero  : std_logic_vector(INSTR_SIZE - 1 downto 0);
  signal one   : std_logic;
  signal rst_i : std_logic;

  signal enable : std_logic;

begin

  one <= '1';
  zero <= (others => '0');
  rst_i <= not rst;
  enable <= not stall;

  instr_mem : bram_inferrer
    generic map (
      addr_bits => INSTR_ADDR_SIZE,
      data_bits => INSTR_SIZE
    )
    port map (
      clk_a => clk,
      clk_b => clk,

      addr_a     => addr,
      data_i_a   => zero,
      data_o_a   => data_read,
      we_a       => zero(0),
      en_a       => enable,
      rst_a      => rst_i,
    
      addr_b     => addr,
      data_i_b   => data_write,
      data_o_b   => open,
      we_b       => write_enable,
      en_b       => one,
      rst_b      => rst_i);
    
end instr_mem_arch;
  
