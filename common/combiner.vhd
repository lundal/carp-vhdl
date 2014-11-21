library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity combiner is
  generic (
    data_long_width  : natural := 32;
    data_short_width : natural := 16;
    offset_width     : natural := 4;
    offset_unit      : natural := 1;
    offset_from_left : boolean := true
  );
  port (
    data_long_in  : in  std_logic_vector(data_long_width - 1 downto 0);
    data_short_in : in  std_logic_vector(data_short_width - 1 downto 0);
    data_out      : out std_logic_vector(data_long_width - 1 downto 0);
    offset        : in  std_logic_vector(offset_width - 1 downto 0)
  );
end combiner;

architecture rtl of combiner is

  signal mask        : std_logic_vector(data_long_width - 1 downto 0);
  signal mask_offset : std_logic_vector(data_long_width - 1 downto 0);

  signal data_padded : std_logic_vector(data_long_width - 1 downto 0);
  signal data_offset  : std_logic_vector(data_long_width - 1 downto 0);

  signal shift_left : std_logic;

begin

  -- Create mask and pad input based on direction
  process (data_short_in)
  begin
    if (offset_from_left) then
      -- Padd on the right
      mask        <= (data_short_width - 1 downto 0 => '1')
                   & (data_long_width - 1 downto data_short_width => '0');
      data_padded <= data_short_in
                   & (data_long_width - 1 downto data_short_width => '0');
      shift_left  <= '0';
    else
      -- Padd on the left
      mask        <= (data_long_width - 1 downto data_short_width => '0')
                   & (data_short_width - 1 downto 0 => '1');
      data_padded <= (data_long_width - 1 downto data_short_width => '0')
                   & data_short_in;
      shift_left  <= '1';
    end if;
  end process;

  mask_shifter: entity work.shifter_dynamic
  generic map (
    data_width         => data_long_width,
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
    data_width         => data_long_width,
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
  data_out <= (data_long_in and (not mask_offset)) or data_offset;

end rtl;
