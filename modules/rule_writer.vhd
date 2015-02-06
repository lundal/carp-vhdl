-------------------------------------------------------------------------------
-- Title      : Rule Writer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : rule_writer.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-02-06
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Writes development rules to rule storage
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-02-06  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity rule_writer is
  generic (
    cell_state_bits   : positive := 1;
    cell_type_bits    : positive := 8;
    neighborhood_size : positive := 7;
    rule_amount       : positive := 256
  );
  port (
    rule_storage_write   : out std_logic;
    rule_storage_address : out std_logic_vector(bits(rule_amount) - 1 downto 0);
    rule_storage_data    : out std_logic_vector((cell_type_bits + 1 + cell_state_bits + 1) * (neighborhood_size + 1) - 1 downto 0);

    decode_operation : in rule_writer_operation_type;
    decode_address   : in std_logic_vector(bits(rule_amount) - 1 downto 0);
    decode_data      : in std_logic_vector((cell_type_bits + 1 + cell_state_bits + 1) * (neighborhood_size + 1) - 1 downto 0);

    run : in std_logic;

    clock : in std_logic
  );
end rule_writer;

architecture rtl of rule_writer is

begin

  process begin
    wait until rising_edge(clock);

    -- Defaults
    rule_storage_write <= '0';

    if (run = '1' and decode_operation = STORE) then
      rule_storage_write   <= '1';
      rule_storage_address <= decode_address;
      rule_storage_data    <= decode_data;
    end if;

  end process;

end rtl;
