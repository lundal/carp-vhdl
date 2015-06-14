--------------------------------------------------------------------------------
-- Title       : Resetter
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Sends reset signals to all buffers
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types.all;

entity resetter is
  port (
    buffer_reset : out std_logic;

    operation : in resetter_operation_type;

    run : in std_logic;

    clock : in std_logic
  );
end entity;

architecture rtl of resetter is

begin

  process begin
    wait until rising_edge(clock);

    -- Defaults
    buffer_reset <= '0';

    if (run = '1' and operation = RESET_BUFFERS) then
      buffer_reset <= '1';
    end if;

  end process;

end rtl;
