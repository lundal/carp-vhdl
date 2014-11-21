-------------------------------------------------------------------------------
-- Title      : LUT Conversion Table
-- Project    : 
-------------------------------------------------------------------------------
-- File       : lutconv.vhd
-- Author     : Asbjørn Djupdal  <djupdal@harryklein>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/01/07
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: A table used to find LUT contents for a specific sblock type
--              Many port; processes LUTCONVS_PER_CYCLE requests each cycle
--              Writing is dual port.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/01/07  3.0      stoevneng Parameterized efficiency
-- 2013/12/10  2.0      stoevneng Updated to use inferred BRAM
-- 2003/02/24  1.0      djupdal   Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

library unisim;

entity lutconv is
  
  port (
    -- sblock types to find LUT contents for
    index : in lutconv_type_bus_t;

    -- LUT contents
    lut_read : out lutconv_lut_bus_t;

    -- LUT value to write to conv table
    lut_write : in std_logic_vector(LUT_SIZE - 1 downto 0);
    -- write enable
    write_en  : in std_logic;

    rst : in std_logic;
    clk : in std_logic);

end lutconv;

architecture lutconv_arch of lutconv is

  signal rst_i : std_logic;

  signal one : std_logic;
  signal zero : std_logic_vector(31 downto 0);

begin

  one <= '1';
  zero <= (others => '0');

  rst_i <= not rst;
  
lutconvBrams: for i in 0 to LUTCONVS_PER_CYCLE / 2 - 1 generate
  lutconvram : bram_inferrer
    generic map (
      addr_bits => TYPE_SIZE,
      data_bits => LUT_SIZE
    )
    port map (
      clk_a => clk,
      clk_b => clk,

      addr_a     => index(i*2),
      data_i_a   => lut_write,
      data_o_a   => lut_read(i*2),
      we_a       => write_en,
      en_a       => one,
      rst_a      => rst_i,
    
      addr_b     => index(i*2+1),
      data_i_b   => zero,
      data_o_b   => lut_read(i*2+1),
      we_b       => zero(0),
      en_b       => one,
      rst_b      => rst_i);
end generate;
end lutconv_arch;
