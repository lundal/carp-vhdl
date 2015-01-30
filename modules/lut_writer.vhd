-------------------------------------------------------------------------------
-- Title      : LUT Writer
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : lut_writer.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-30
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Writes LUT entries to Cellular Automata LUT storage
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-30  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types.all;

entity lut_writer is
  generic (
    cell_type_bits : positive := 8;
    neighborhood_bits : positive := 7
  );
  port (
    lut_storage_write   : out std_logic;
    lut_storage_address : out std_logic_vector(cell_type_bits - 1 downto 0);
    lut_storage_data    : out std_logic_vector(2**neighborhood_bits - 1 downto 0);

    decode_operation : in lut_writer_operation_type;
    decode_address   : in std_logic_vector(cell_type_bits - 1 downto 0);
    decode_data      : in std_logic_vector(2**neighborhood_bits - 1 downto 0);

    run : in std_logic;

    clock : in std_logic
  );
end lut_writer;

architecture rtl of lut_writer is

begin

  process begin
    wait until rising_edge(clock);

    -- Defaults
    lut_storage_write <= '0';

    if (run = '1' and decode_operation = STORE) then
      lut_storage_write   <= '1';
      lut_storage_address <= decode_address;
      lut_storage_data    <= decode_data;
    end if;

  end process;

end rtl;
