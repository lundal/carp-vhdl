-------------------------------------------------------------------------------
-- Title      : Fetch Handler
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : fetch.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-22
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Selects between instructions from communication or bram.
--            : Also handles instruction storage and control flow.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-22  1.0      lundal    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.instructions.all;
use work.functions.all;

entity fetch_handler is
  generic (
    jump_counters        : positive := 4;
    jump_counter_bits    : positive := 16;
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

  type state_type is (
    FETCH_COMMUNICATION, FETCH_BRAM, STORE_BRAM
  );
  signal state : state_type := FETCH_COMMUNICATION;

  signal running : std_logic;

  signal nop_issued :std_logic;

  signal communication_instruction_opcode  : std_logic_vector(4 downto 0);
  signal communication_instruction_address : std_logic_vector(program_counter_bits - 1 downto 0);
  signal communication_instruction_jump_counter : std_logic_vector(bits(jump_counters) - 1 downto 0);
  signal communication_instruction_jump_compare : std_logic_vector(jump_counter_bits - 1 downto 0);

  signal bram_instruction_opcode  : std_logic_vector(4 downto 0);
  signal bram_instruction_address : std_logic_vector(program_counter_bits - 1 downto 0);
  signal bram_instruction_jump_counter : std_logic_vector(bits(jump_counters) - 1 downto 0);
  signal bram_instruction_jump_compare : std_logic_vector(jump_counter_bits - 1 downto 0);

  signal bram_address_plus_one : std_logic_vector(program_counter_bits - 1 downto 0);

  -- Required for BRAM read timing
  type bram_address_passthrough_type is (
    NONE, COMMUNICATION_INSTRUCT, BRAM_INSTRUCT, BRAM_PLUS_ONE
  );
  signal bram_address_passthrough : bram_address_passthrough_type := NONE;

  -- Jump counters
  type jump_counter_values_type is array (0 to jump_counters - 1) of unsigned(jump_counter_bits - 1 downto 0);
  signal jump_counter_values              : jump_counter_values_type;
  signal jump_counter_match_communication : std_logic_vector(jump_counters - 1 downto 0);
  signal jump_counter_match_bram          : std_logic_vector(jump_counters - 1 downto 0);

  -- Internally used out ports
  signal bram_write_i   : std_logic := '0';
  signal bram_address_i : std_logic_vector(program_counter_bits - 1 downto 0) := (others => '0');
  signal instruction_i  : std_logic_vector(instruction_bits - 1 downto 0) := (others => '0');
  signal done_i         : std_logic := '1';

begin

  -- Generic checks
  assert (program_counter_bits <= 16) report "Unsupported program_counter_bits. Supported values are [1-16]."    severity FAILURE;
  assert (jump_counters <= 256)       report "Unsupported jump_counters. Supported values are [1-256]."    severity FAILURE;
  assert (jump_counter_bits <= 32)    report "Unsupported jump_counter_bits. Supported values are [1-32]." severity FAILURE;

  running <= run or not done_i or nop_issued;

  communication_run <= '1' when running = '1' and state /= FETCH_BRAM else '0';

  communication_instruction_opcode  <= communication_instruction(4 downto 0);
  communication_instruction_address <= communication_instruction(program_counter_bits - 1 + 16 downto 16);
  communication_instruction_jump_counter <= communication_instruction(bits(jump_counters) - 1 + 8 downto 8);
  communication_instruction_jump_compare <= communication_instruction(jump_counter_bits - 1 + 32 downto 32);

  bram_instruction_opcode  <= bram_instruction_in(4 downto 0);
  bram_instruction_address <= bram_instruction_in(program_counter_bits - 1 + 16 downto 16);
  bram_instruction_jump_counter <= bram_instruction_in(bits(jump_counters) - 1 + 8 downto 8);
  bram_instruction_jump_compare <= bram_instruction_in(jump_counter_bits - 1 + 32 downto 32);

  bram_address_plus_one <= std_logic_vector(unsigned(bram_address_i) + 1);

  process begin
    wait until rising_edge(clock);

    -- Defaults
    bram_write_i <= '0';
    nop_issued <= '0';

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
            when INSTRUCTION_JUMP_EQUAL =>
              for i in 0 to jump_counters - 1 loop
                if (unsigned(communication_instruction_jump_counter) = i) then
                  if (jump_counter_match_communication(i) = '1') then
                    state <= FETCH_BRAM;
                    bram_address_i <= communication_instruction_address;
                  end if;
                end if;
              end loop;
            when INSTRUCTION_COUNTER_INCREMENT =>
              for i in 0 to jump_counters - 1 loop
                if (unsigned(communication_instruction_jump_counter) = i) then
                  jump_counter_values(i) <= jump_counter_values(i) + 1;
                end if;
              end loop;
            when INSTRUCTION_COUNTER_RESET =>
              for i in 0 to jump_counters - 1 loop
                if (unsigned(communication_instruction_jump_counter) = i) then
                  jump_counter_values(i) <= (others => '0');
                end if;
              end loop;
            when others =>
              instruction_i <= communication_instruction;
              done_i <= '1';
          end case;
        end if;
        -- Produce NOPs when waiting to allow instructions in the pipeline to complete
        if (communication_done = '0' and running = '1') then
          instruction_i <= (others => '0');
          done_i <= '1';
          nop_issued <= '1'; -- Prevents a NOP if instruction is fetched in time
        end if;

      when FETCH_BRAM =>
        if (running = '1') then -- TODO: bram_done?
          case bram_instruction_opcode is
            when INSTRUCTION_BREAK =>
              state <= FETCH_COMMUNICATION;
            when INSTRUCTION_JUMP =>
              bram_address_i <= bram_instruction_address;
            when INSTRUCTION_JUMP_EQUAL =>
              for i in 0 to jump_counters - 1 loop
                if (unsigned(bram_instruction_jump_counter) = i) then
                  if (jump_counter_match_bram(i) = '1') then
                    bram_address_i <= bram_instruction_address;
                  end if;
                end if;
              end loop;
            when INSTRUCTION_COUNTER_INCREMENT =>
              for i in 0 to jump_counters - 1 loop
                if (unsigned(bram_instruction_jump_counter) = i) then
                  jump_counter_values(i) <= jump_counter_values(i) + 1;
                end if;
              end loop;
            when INSTRUCTION_COUNTER_RESET =>
              for i in 0 to jump_counters - 1 loop
                if (unsigned(bram_instruction_jump_counter) = i) then
                  jump_counter_values(i) <= (others => '0');
                end if;
              end loop;
            when others =>
              bram_address_i <= bram_address_plus_one;
              instruction_i <= bram_instruction_in;
              done_i <= '1';
              -- Safety: Break after last memory address
              if (signed(bram_address_plus_one) = -1) then
                state <= FETCH_COMMUNICATION;
              end if;
          end case;
        end if;

      when STORE_BRAM =>
        if (communication_done = '1' and running = '1') then
          case communication_instruction_opcode is
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

  counter_compare : for i in 0 to jump_counters - 1 generate
    jump_counter_match_communication(i)
      <= to_std_logic(jump_counter_values(i) = unsigned(communication_instruction_jump_compare));
    jump_counter_match_bram(i)
      <= to_std_logic(jump_counter_values(i) = unsigned(bram_instruction_jump_compare));
  end generate;

  -- Internally used out ports
  bram_write <= bram_write_i;
  bram_address <= communication_instruction_address when bram_address_passthrough = COMMUNICATION_INSTRUCT else
                  bram_instruction_address when bram_address_passthrough = BRAM_INSTRUCT else
                  bram_address_plus_one when bram_address_passthrough = BRAM_PLUS_ONE else
                  bram_address_i;
  instruction <= instruction_i;
  done <= done_i;

end rtl;
