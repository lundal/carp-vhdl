library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter_dynamic is
  generic (
    data_width         : natural := 32;
    shift_amount_width : natural := 4
  );
  port (
    data_in      : in  std_logic_vector(data_width - 1 downto 0);
    data_out     : out std_logic_vector(data_width - 1 downto 0);
    left         : in  std_logic;
    arithmetic   : in  std_logic;
    shift_amount : in  std_logic_vector(shift_amount_width - 1 downto 0)
  );
end shifter_dynamic;

architecture rtl of shifter_dynamic is

  type result_a is array (shift_amount_width downto 0) of std_logic_vector(data_width - 1 downto 0);
  
  signal result : result_a := (others => (others => '0'));

begin

  result(0) <= data_in;

  gen_shifters: for i in 0 to shift_amount_width-1 generate
    shifter: entity work.shifter
    generic map (
      data_width   => data_width,
      shift_amount => 2 ** i
    )
    port map (
      data_in    => result(i),
      data_out   => result(i+1),
      left       => left,
      arithmetic => arithmetic,
      enable     => shift_amount(i)
    );
  end generate;

  data_out <= result(shift_amount_width);

end rtl;
