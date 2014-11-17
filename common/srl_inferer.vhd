-------------------------------------------------------------------------------
-- Title      : srl_inferrer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : srl_inferrer.vhd
-- Author     : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/02/02
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: An SRL. Used for implementing configurable LUTs.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/02/02  1.0      stoevneng Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;

entity srl_inferer is
generic (
  size : integer;
  a_size : integer
  );
port (
  d   : in  std_logic;
  ce  : in  std_logic;
  a   : in  std_logic_vector(a_size - 1 downto 0);
  q   : out std_logic;
  clk : in  std_logic);
end srl_inferer;

architecture Behavioural of srl_inferer is

signal q_int: std_logic_vector(size - 1 downto 0);

begin

process(clk)
begin
  if (rising_edge(clk)) then
    if (ce = '1') then
      q_int <= q_int(size - 2 downto 0) & D;
    end if;
  end if;
end process;
q <= q_int(to_integer(unsigned(a)));

end Behavioural;
