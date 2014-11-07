-------------------------------------------------------------------------------
-- Title      : Sblock Matrix -- BRAM
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sbm_bram.vhd
-- Author     : Asbjørn Djupdal  <djupdal@harryklein>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/01/07
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: BRAM for sblock matrix data
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/01/07  2.0      stoevneng Parameterized number of BRAM modules
-- 2013/12/10  1.1      stoevneng Updated to use inferred BRAM
-- 2003/02/13  1.0      djupdal   Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

library unisim;

entity sbm_bram is
  
  port (
    -- read databuses 
    type_data_read  : out bram_type_bus_t;
    state_data_read : out bram_state_bus_t;
    
    -- write databuses
    type_data_write  : in bram_type_bus_t;
    state_data_write : in bram_state_bus_t;
    
    -- adress buses
    addr : in bram_addr_t;

    -- enable signals
    enable_read        : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
    enable_type_write  : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);
    enable_state_write : in std_logic_vector(SBM_BRAM_MODULES * 2 - 1 downto 0);

    stall : in std_logic;

    clk : in std_logic;
    rst : in std_logic);

end sbm_bram;

architecture sbm_bram_arch of sbm_bram is

  signal zero : std_logic_vector(15 downto 0);
  signal one  : std_logic;

  signal rst_i : std_logic;

  signal addr_i : bram_addr_t;
  signal enable : std_logic;

begin  -- sbm_bram_arch

  zero <= (others => '0');
  one <= '1';

  rst_i <= not rst;
  addr_i <= addr;
  enable <= not stall;

  bram_redundancy_generator: for i in 0 to SBM_BRAM_MODULES - 1 generate
    type_brX : bram_inferrer
      generic map (
        addr_bits => ADDR_BUS_SIZE,
        data_bits => TYPE_BUS_SIZE
      )
      port map (
        clk_a => clk,
        clk_b => clk,

        addr_a     => addr_i(i*2),
        data_i_a   => type_data_write(i*2),
        data_o_a   => type_data_read(i*2),
        we_a       => enable_type_write(i*2),
        en_a       => enable,
        rst_a      => rst_i,

        addr_b     => addr_i(i*2+1),
        data_i_b   => type_data_write(i*2+1),
        data_o_b   => type_data_read(i*2+1),
        we_b       => enable_type_write(i*2+1),
        en_b       => enable,
        rst_b      => rst_i);    

    state_brX : bram_inferrer
      generic map (
        addr_bits => ADDR_BUS_SIZE,
        data_bits => STATE_BUS_SIZE
      )
      port map (
        clk_a => clk,
        clk_b => clk,

        addr_a     => addr_i(i*2),
        data_i_a   => state_data_write(i*2),
        data_o_a   => state_data_read(i*2),
        we_a       => enable_state_write(i*2),
        en_a       => enable,
        rst_a      => rst_i,

        addr_b     => addr_i(i*2+1),
        data_i_b   => state_data_write(i*2+1),
        data_o_b   => state_data_read(i*2+1),
        we_b       => enable_state_write(i*2+1),
        en_b       => enable,
        rst_b      => rst_i);
    end generate bram_redundancy_generator;
end sbm_bram_arch;
