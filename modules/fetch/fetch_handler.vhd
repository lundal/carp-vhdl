-------------------------------------------------------------------------------
-- Title      : Fetch Handler
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : fetch.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2014-11-22
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Selects between instructions from communication or bram.
--            : Also handles instruction storage and control flow.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014-11-22  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fetch_handler is
  generic (
    program_counter_bits : positive := 8;
    instruction_bits     : positive := 256
  );
  port (
    communication_instruction : in  std_logic_vector(instruction_bits - 1 downto 0);
    communication_run         : out std_logic;
    communication_done        : in  std_logic;
  
    bram_write           : out std_logic;
    bram_address         : out std_logic_vector(program_counter_bits - 1 downto 0);
    bram_instruction_in  : in  std_logic_vector(instruction_bits - 1 downto 0);
    bram_instruction_out : out std_logic_vector(instruction_bits - 1 downto 0);

    instruction : out std_logic_vector(instruction_bits - 1 downto 0);

    run  : in  std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end fetch_handler;

architecture rtl of fetch_handler is

  constant INSTRUCTION_STORE             : std_logic_vector(4 downto 0) := "11010";
  constant INSTRUCTION_END               : std_logic_vector(4 downto 0) := "11011";
  constant INSTRUCTION_JUMP              : std_logic_vector(4 downto 0) := "11100";
  constant INSTRUCTION_BREAK             : std_logic_vector(4 downto 0) := "11101";
  --constant INSTRUCTION_JUMP_EQUAL        : std_logic_vector(4 downto 0) := "00000";
  constant INSTRUCTION_COUNTER_INCREMENT : std_logic_vector(4 downto 0) := "11110";
  constant INSTRUCTION_COUNTER_RESET     : std_logic_vector(4 downto 0) := "11111";

  type state_type is (
    FETCH_COMMUNICATION, FETCH_BRAM, STORE_BRAM
  );
  signal state : state_type := FETCH_COMMUNICATION;

  signal running : std_logic;

  signal communication_instruction_opcode  : std_logic_vector(4 downto 0);
  signal communication_instruction_address : std_logic_vector(program_counter_bits - 1 downto 0);

  signal bram_instruction_opcode  : std_logic_vector(4 downto 0);
  signal bram_instruction_address : std_logic_vector(program_counter_bits - 1 downto 0);

  signal bram_address_plus_one : std_logic_vector(program_counter_bits - 1 downto 0);

  -- Required for BRAM read timing
  type bram_address_passthrough_type is (
    NONE, COMMUNICATION_INSTRUCT, BRAM_INSTRUCT, BRAM_PLUS_ONE
  );
  signal bram_address_passthrough : bram_address_passthrough_type := NONE;

  -- Internally used out ports
  signal bram_write_i   : std_logic := '0';
  signal bram_address_i : std_logic_vector(program_counter_bits - 1 downto 0) := (others => '0');
  signal instruction_i  : std_logic_vector(instruction_bits - 1 downto 0) := (others => '0');
  signal done_i         : std_logic := '1';

begin

  running <= run or not done_i;

  communication_run <= done_i;

  communication_instruction_opcode  <= communication_instruction(4 downto 0);
  communication_instruction_address <= communication_instruction(program_counter_bits - 1 + 16 downto 16);

  bram_instruction_opcode  <= bram_instruction_in(4 downto 0);
  bram_instruction_address <= bram_instruction_in(program_counter_bits - 1 + 16 downto 16);

  bram_address_plus_one <= std_logic_vector(unsigned(bram_address_i) + 1);

  process begin
    wait until rising_edge(clock);

    -- Defaults
    bram_write_i <= '0';

    -- Reset done signal when starting by default
    if (run = '1') then
      done_i <= '0';
    end if;

    case state is

      when FETCH_COMMUNICATION =>
        if (communication_done = '1' and running = '1') then
          case communication_instruction_opcode is
            when INSTRUCTION_STORE =>
              state <= STORE_BRAM;
              bram_address_i <= std_logic_vector(unsigned(communication_instruction_address) - 1); -- STORE_BRAM begins at next address
            when INSTRUCTION_JUMP =>
              state <= FETCH_BRAM;
              bram_address_i <= communication_instruction_address;
--            when INSTRUCTION_JUMP_EQUAL =>
--              if (false) then -- TODO
--                state <= FETCH_BRAM;
--                bram_address_i <= communication_instruction_address;
--              end if;
--            when INSTRUCTION_COUNTER_INCREMENT =>
--              null; -- TODO
--            when INSTRUCTION_COUNTER_RESET =>
--              null; -- TODO
            when others =>
              instruction_i <= communication_instruction;
              done_i <= '1';
          end case;
        end if;

      when FETCH_BRAM =>
        if (running = '1') then -- TODO: bram_done?
          case bram_instruction_opcode is
            when INSTRUCTION_BREAK =>
              state <= FETCH_COMMUNICATION;
            when INSTRUCTION_JUMP =>
              bram_address_i <= bram_instruction_address;
--            when INSTRUCTION_JUMP_EQUAL =>
--              if (false) then -- TODO
--                bram_address_i <= bram_instruction_address;
--              end if;
--            when INSTRUCTION_COUNTER_INCREMENT =>
--              null; -- TODO
--            when INSTRUCTION_COUNTER_RESET =>
--              null; -- TODO
            when others =>
              bram_address_i <= bram_address_plus_one;
              instruction_i <= bram_instruction_in;
              done_i <= '1';
          end case;
        end if;

      when STORE_BRAM =>
        if (communication_done = '1' and running = '1') then
          case bram_instruction_opcode is
            when INSTRUCTION_END =>
              state <= FETCH_COMMUNICATION;
            when others =>
              bram_write_i <= '1';
              bram_address_i <= bram_address_plus_one;
              bram_instruction_out <= communication_instruction;
          end case;
        end if;

    end case;
  end process;

  -- When preparing to fetch from BRAM, send address one cycle earlier.
  -- This is needed since the BRAM takes an extra cycle to update its outputs.
  process (state, running, communication_done, communication_instruction_opcode, bram_instruction_opcode) begin
    bram_address_passthrough <= NONE;

    case state is

      when FETCH_COMMUNICATION =>
        if (communication_done = '1' and running = '1') then
          case communication_instruction_opcode is
            when INSTRUCTION_JUMP =>
              bram_address_passthrough <= COMMUNICATION_INSTRUCT;
            when others =>
              null;
          end case;
        end if;

      when FETCH_BRAM =>
        if (running = '1') then -- TODO: bram_done?
          case bram_instruction_opcode is
            when INSTRUCTION_JUMP =>
              bram_address_passthrough <= BRAM_INSTRUCT;
            when others =>
              bram_address_passthrough <= BRAM_PLUS_ONE;
          end case;
        end if;

      when others =>
        null;

    end case;
  end process;

  -- Internally used out ports
  bram_write <= bram_write_i;
  bram_address <= communication_instruction_address when bram_address_passthrough = COMMUNICATION_INSTRUCT else
                  bram_instruction_address when bram_address_passthrough = BRAM_INSTRUCT else
                  bram_address_plus_one when bram_address_passthrough = BRAM_PLUS_ONE else
                  bram_address_i;
  instruction <= instruction_i;
  done <= done_i;

end rtl;
