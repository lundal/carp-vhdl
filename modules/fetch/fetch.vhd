-------------------------------------------------------------------------------
-- Title      : Fetch
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : fetch.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-22
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Fetches instructions
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-22  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fetch is
  generic (
    buffer_address_bits  : positive := 8;
    program_counter_bits : positive := 8;
    instruction_bits     : positive := 256
  );
  port (
    buffer_data  : in  std_logic_vector(31 downto 0);
    buffer_count : in  std_logic_vector(buffer_address_bits - 1 downto 0);
    buffer_read  : out std_logic;

    instruction : out std_logic_vector(instruction_bits - 1 downto 0);

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end fetch;

architecture rtl of fetch is

  signal communication_instruction : std_logic_vector(instruction_bits - 1 downto 0);
  signal communication_run         : std_logic;
  signal communication_done        : std_logic;
  
  signal bram_write                    : std_logic;
  signal bram_address                  : std_logic_vector(program_counter_bits - 1 downto 0);
  signal bram_instruction_from_handler : std_logic_vector(instruction_bits - 1 downto 0);
  signal bram_instruction_to_handler   : std_logic_vector(instruction_bits - 1 downto 0);

begin

  fetch_communication : entity work.fetch_communication
  generic map (
    buffer_address_bits => buffer_address_bits,
    instruction_bits    => instruction_bits
  )
  port map (
    buffer_data  => buffer_data,
    buffer_count => buffer_count,
    buffer_read  => buffer_read,

    instruction => communication_instruction,

    run  => communication_run,
    done => communication_done,

    clock => clock
  );
  
  instruction_bram : entity work.bram_tdp
  generic map (
    address_bits => program_counter_bits,
    data_bits    => instruction_bits,
    write_first  => true
  )
  port map (
    -- Port A
    a_write    => bram_write,
    a_address  => bram_address,
    a_data_in  => bram_instruction_from_handler,
    a_data_out => bram_instruction_to_handler,

    -- Port B
    b_write    => '0',
    b_address  => (others => '0'),
    b_data_in  => (others => '0'),
    b_data_out => open,

    clock => clock
	);

  fetch_handler : entity work.fetch_handler
  generic map (
    program_counter_bits => program_counter_bits,
    instruction_bits     => instruction_bits
  )
  port map (
    communication_instruction => communication_instruction,
    communication_run         => communication_run,
    communication_done        => communication_done,
  
    bram_write           => bram_write,
    bram_address         => bram_address,
    bram_instruction_in  => bram_instruction_to_handler,
    bram_instruction_out => bram_instruction_from_handler,

    instruction => instruction,

    run  => run,
    done => done,

    clock => clock
  );

end rtl;
