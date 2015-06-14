--------------------------------------------------------------------------------
-- Title       : Combiner
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Combines two signals by shifting and masking.
--             : Can be used to insert an entry into a word.
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2014  Lundal    Created
--             : 2015  Lundal    Refactored
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity combiner is
  generic (
    data_width     : positive := 32;
    data_new_width : positive := 16;
    offset_width   : positive := 4;
    offset_unit    : positive := 1;
    offset_to_left : boolean := true
  );
  port (
    data_original : in  std_logic_vector(data_width - 1 downto 0);
    data_new      : in  std_logic_vector(data_new_width - 1 downto 0);
    data_combined : out std_logic_vector(data_width - 1 downto 0);
    offset        : in  std_logic_vector(offset_width - 1 downto 0)
  );
end combiner;

architecture rtl of combiner is

  signal mask        : std_logic_vector(data_width - 1 downto 0);
  signal mask_offset : std_logic_vector(data_width - 1 downto 0);

  signal data_padded : std_logic_vector(data_width - 1 downto 0);
  signal data_offset : std_logic_vector(data_width - 1 downto 0);

  signal shift_left : std_logic;

begin

  -- Create mask and pad input based on direction
  process (data_new)
  begin
    if (offset_to_left) then
      -- Padd on the left
      mask        <= (data_width - 1 downto data_new_width => '0')
                   & (data_new_width - 1 downto 0 => '1');
      data_padded <= (data_width - 1 downto data_new_width => '0')
                   & data_new;
      shift_left  <= '1';
    else
      -- Padd on the right
      mask        <= (data_new_width - 1 downto 0 => '1')
                   & (data_width - 1 downto data_new_width => '0');
      data_padded <= data_new
                   & (data_width - 1 downto data_new_width => '0');
      shift_left  <= '0';
    end if;
  end process;

  mask_shifter: entity work.shifter_dynamic
  generic map (
    data_width         => data_width,
    shift_amount_width => offset_width,
    shift_unit         => offset_unit
  )
  port map (
    data_in      => mask,
    data_out     => mask_offset,
    left         => shift_left,
    arithmetic   => '0',
    shift_amount => offset
  );

  data_shifter: entity work.shifter_dynamic
  generic map (
    data_width         => data_width,
    shift_amount_width => offset_width,
    shift_unit         => offset_unit
  )
  port map (
    data_in      => data_padded,
    data_out     => data_offset,
    left         => shift_left,
    arithmetic   => '0',
    shift_amount => offset
  );

  -- The inverse mask is used to remove any previous data
  data_combined <= (data_original and (not mask_offset)) or data_offset;

end rtl;
