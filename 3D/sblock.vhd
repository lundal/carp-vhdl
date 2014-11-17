-------------------------------------------------------------------------------
-- Title      : sblock
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sblock.vhd
-- Author     : Asbjørn Djupdal  <djupdal@idi.ntnu.no>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/03/03
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: A single sblock
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/03/03  2.5      stoevneng Updated for 3D
-- 2014/02/02  2.0      stoevneng Inferred SRL
-- 2003/01/17  1.1      djupdal
-- 2002/10/05  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;
use IEEE.numeric_std.all;

library unisim;

entity sblock is

  port (
    east  : in std_logic;
    south : in std_logic;
    north : in std_logic;
    west  : in std_logic;
    up    : in std_logic;
    down  : in std_logic;

    conf_data         : in std_logic_vector(SRLS_PER_LUT-1 downto 0);
    conf_data_ff      : in std_logic;

    config_lut_enable : in std_logic;
    config_ff_enable  : in std_logic;

    output : out std_logic;

    run    : in std_logic;
    clk    : in std_logic);

end sblock;

-------------------------------------------------------------------------------

architecture sblock_arch of sblock is

  signal lut_lo : std_logic_vector(SRL_LENGTH-1 downto 0);
  signal lut_hi : std_logic_vector(SRL_LENGTH-1 downto 0);

  signal out_v  : std_logic_vector(SRLS_PER_LUT-1 downto 0);

  signal ff : std_logic;
  signal a : std_logic_vector(SRL_IN_SIZE - 1 downto 0);
  signal srl_select : std_logic_vector(NEIGH_SIZE - SRL_IN_SIZE - 1 downto 0);
  signal sblock_in : std_logic_vector(6 downto 0);

begin
  sblock_in <= ff & up & down & north & east & south & west;
  a <= sblock_in(SRL_IN_SIZE - 1 downto 0);
  srl_select <= sblock_in(6 downto SRL_IN_SIZE);

  srls: for i in 0 to SRLS_PER_LUT-1 generate
    lut_srl_i: srl_inferer
      generic map (
        size => SRL_LENGTH,
        a_size => SRL_IN_SIZE)
      port map (
        d   => conf_data(i),
        ce  => config_lut_enable,
        a   => a,
        q   => out_v(i),
        clk => clk);
  end generate srls;


  -- update ff

  process (clk)
  begin

    if rising_edge (clk) then

      if run = '1' or config_ff_enable = '1' then
        if config_ff_enable = '1' then
          ff <= conf_data_ff;
        else
          ff <= out_v(to_integer(unsigned(srl_select)));
        end if;
      end if;

    end if;

  end process;

  output <= ff;

end sblock_arch;
