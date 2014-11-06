library ieee;
use ieee.std_logic_1164.all;

entity endian_reverser is
  port (
    original : in  std_logic_vector(31 downto 0);
    reversed : out std_logic_vector(31 downto 0)
  );
end endian_reverser;

architecture rtl of endian_reverser is
begin

  reversed( 7 downto  0) <= original(31 downto 24);
  reversed(15 downto  8) <= original(23 downto 16);
  reversed(23 downto 16) <= original(15 downto  8);
  reversed(31 downto 24) <= original( 7 downto  0);

end rtl;
