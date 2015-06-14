--------------------------------------------------------------------------------
-- Title       : Sblock
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Asbjørn Djupdal  <djupdal@idi.ntnu.no>
--             : Ola Martin Tiseth Støvneng
--             : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : A sblock with a configurable neighborhood that includes itself.
--             : Note: 2**neighborhood_size / lut_configuration_bits should be
--             : 16 or more for optimal shift register usage.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2002  Djupdal   Created
--             : 2014  Støvneng  Inferred shift register
--             : 2015  Lundal    Refactored to allow any neighborhood size
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sblock is
  generic (
    neighborhood_size      : positive := 7; -- 5 for 2D grid, 7 for 3D grid
    lut_configuration_bits : positive := 8
  );
  port (
    state                : out std_logic;
    neighbor_states      : in  std_logic_vector(neighborhood_size - 1 downto 1);
    configuration_lut    : in  std_logic_vector(lut_configuration_bits - 1 downto 0);
    configuration_state  : in  std_logic;
    configuration_enable : in  std_logic;
    update               : in  std_logic;
    clock                : in  std_logic
  );
end sblock;

architecture rtl of sblock is

  signal neighborhood_states : std_logic_vector(neighborhood_size - 1 downto 0);
  signal lut_output          : std_logic;
  signal state_i             : std_logic := '0';

begin

  neighborhood_states <= neighbor_states & state_i;

  lut : entity work.lut_configurable
  generic map (
    address_bits            => neighborhood_size,
    configuration_data_bits => lut_configuration_bits
  )
  port map (
    configuration_data   => configuration_lut,
    configuration_enable => configuration_enable,
    address              => neighborhood_states,
    output               => lut_output,
    clock                => clock
  );

  process begin
    wait until rising_edge(clock);

    if (update = '1') then
      state_i <= lut_output;
    elsif (configuration_enable = '1') then
      state_i <= configuration_state;
    end if;

  end process;

  state <= state_i;

end rtl;
