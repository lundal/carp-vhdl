-------------------------------------------------------------------------------
-- Title      : word select
-- Project    : 
-------------------------------------------------------------------------------
-- File       : word_select.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
-- Company    : 
-- Last update: 2005/05/10
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Special purpose shiftregister
--              Used e.g as select signal for sblock_matrix output_select
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2003/01/30  1.0      djupdal	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

entity word_select is
  
  generic (
    NUMBER_OF_WORDS : integer);         -- width of shiftregister

  port (
    reset_select : in std_logic;        -- set register to 1
    select_next  : in std_logic;        -- shift left

    -- contents of shiftregister
    selected_word : out std_logic_vector(NUMBER_OF_WORDS - 1 downto 0);

    rst : in std_logic;
    clk : in std_logic);

end word_select;

architecture word_selectArch of word_select is

  signal shiftRegister : std_logic_vector(NUMBER_OF_WORDS - 1 downto 0);
  signal zero          : std_logic_vector(NUMBER_OF_WORDS - 1 downto 0);

begin
  
  zero <= (others => '0');

  process (rst, clk, zero)
  begin  -- process

    if rst = '0' then
      shiftRegister <= zero(NUMBER_OF_WORDS - 1 downto 0);

    elsif rising_edge (clk) then

      if reset_select = '1' then
        shiftRegister(0) <= '1';
        shiftRegister(NUMBER_OF_WORDS - 1 downto 1) <=
          zero(NUMBER_OF_WORDS - 2 downto 0);

      elsif select_next = '1' then
        shiftRegister(0) <= '0';
        shiftRegister(NUMBER_OF_WORDS - 1 downto 1) <=
          shiftRegister(NUMBER_OF_WORDS - 2 downto 0);
      end if;
    end if;
  end process;

  selected_word <= shiftRegister;

end word_selectArch;
