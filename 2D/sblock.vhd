-------------------------------------------------------------------------------
-- Title      : sblock
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sblock.vhd
-- Author     : Asbjørn Djupdal  <djupdal@idi.ntnu.no>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/02/02
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: A single sblock
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/02/02  2.0      stoevneng Inferred SRL
-- 2003/01/17  1.1      djupdal
-- 2002/10/05  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

library unisim;

entity sblock is

  port (
    east  : in std_logic;
    south : in std_logic;
    north : in std_logic;
    west  : in std_logic;

    conf_data_l       : in std_logic;   -- LUT low word
    conf_data_h       : in std_logic;   -- LUT high word
    conf_data_ff      : in std_logic;

    config_lut_enable : in std_logic;
    config_ff_enable  : in std_logic;

    output : out std_logic;

    run    : in std_logic;
    clk    : in std_logic);

end sblock;

-------------------------------------------------------------------------------

architecture sblock_arch of sblock is

  signal lut_lo : std_logic_vector(15 downto 0);
  signal lut_hi : std_logic_vector(15 downto 0);

  signal out_lo : std_logic;
  signal out_hi : std_logic;

  signal ff : std_logic;
  signal a : std_logic_vector(3 downto 0);

begin

  a <= north & east & south & west;
  lut_lo_srl: srl_inferer
    generic map (
      size => 16,
      a_size => 4)
    port map (
      d   => conf_data_l,
      ce  => config_lut_enable,
      a   => a,
      q   => out_lo,
      clk => clk);

  lut_hi_srl: srl_inferer
    generic map (
      size => 16,
      a_size => 4)
    port map (
      d   => conf_data_h,
      ce  => config_lut_enable,
      a   => a,
      q   => out_hi,
      clk => clk);

  -- update ff

  process (clk)
  begin

    if rising_edge (clk) then

      if run = '1' or config_ff_enable = '1' then
        if config_ff_enable = '1' then
          ff <= conf_data_ff;
        else
          if ff = '0' then
            ff <= out_lo;
          else
            ff <= out_hi;
          end if;
        end if;
      end if;

    end if;

  end process;

  output <= ff;

end sblock_arch;
