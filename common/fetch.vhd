-------------------------------------------------------------------------------
-- Title      : Fetch
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fetch.vhd
-- Author     : Asbjoern Djupdal  <asbjoern@djupdal.org>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/02/05
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Fetch1, Fetch2, PCIFetch and Store pipeline stages
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/02/05  2.0      stoevneng Support for 128 bit instructions
-- 2003/03/30  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;

entity fetch is

  port (
    ---------------------------------------------------------------------------
    -- decode

    -- instruction register
    fetch_instruction : out std_logic_vector(INSTR_SIZE - 1 downto 0);
    -- new instruction ready
    fetch_valid       : out std_logic;

    -- decode should clear program_store flag
    fetch_enter_normal_mode : out std_logic;
    -- decode should increment pc
    fetch_count_pc          : out std_logic;

    program_counter : in std_logic_vector(INSTR_ADDR_SIZE - 1 downto 0);
    -- do a fetch from program memory
    valid           : in std_logic;

    -- store instructions from PCI to program memory
    program_store : in std_logic;

    flush : in std_logic;

    ---------------------------------------------------------------------------
    -- hazard

    stall : in std_logic;

    ---------------------------------------------------------------------------
    -- com40

    receive      : out std_logic;
    ack_receive  : in  std_logic;
    data_receive : in  std_logic_vector(63 downto 0);

    ---------------------------------------------------------------------------
    -- other

    rst : in std_logic;
    clk : in std_logic);

end fetch;

architecture fetch_arch of fetch is

  signal zero : std_logic_vector(INSTR_SIZE - 1 downto 0);
  signal one : std_logic;

  -----------------------------------------------------------------------------
  -- PCI Fetch

  type receive_state_type is (idle, receiving_1, syncing, receiving_2, receiving_3);
  signal receive_ctrl_state : receive_state_type;

  signal ack_receive_ii : std_logic;
  signal ack_receive_i  : std_logic;
  signal data_2_received : std_logic;

  signal pci_instruction : std_logic_vector(INSTR_SIZE - 1 downto 0);
  signal pci_valid       : std_logic;
  signal store_valid     : std_logic;

  signal next_state        : receive_state_type;
  signal pci_valid_i       : std_logic;
  signal store_valid_i     : std_logic;
  signal pci_instruction_i : std_logic_vector(INSTR_SIZE - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Fetch 1

  signal mem_valid : std_logic;
  signal mem_instruction : std_logic_vector(INSTR_SIZE - 1 downto 0);

  -----------------------------------------------------------------------------
  -- Store

  signal data_write     : std_logic_vector(INSTR_SIZE - 1 downto 0);
  signal write_enable   : std_logic;

  -----------------------------------------------------------------------------
  -- Fetch 2

begin

  zero <= (others => '0');
  one <= '1';

  -----------------------------------------------------------------------------

  instr_mem_unit: instr_mem
    port map (
      addr         => program_counter,
      data_read    => mem_instruction,
      data_write   => data_write,
      write_enable => write_enable,
      stall        => stall,
      rst          => rst,
      clk          => clk);

  -----------------------------------------------------------------------------
  -- PCI Fetch
  -----------------------------------------------------------------------------

  -- synchronize PCI signals to local clock
  process (rst, clk)
  begin
    if rst = '0' then
      ack_receive_ii <= '0';
      ack_receive_i <= '0';
    elsif rising_edge (clk) then
      ack_receive_ii <= ack_receive;
      ack_receive_i <= ack_receive_ii;
    end if;
  end process;

  -----------------------------------------------------------------------------

  -- state machine
  process (pci_instruction, receive_ctrl_state, program_store, data_receive,
           ack_receive_i, valid, data_2_received, pci_instruction_i)
  begin
    next_state <= idle;
    pci_valid_i <= '0';
    store_valid_i <= '0';
    pci_instruction_i <= pci_instruction;

    receive <= '0';
--    data_2_received <= '0';

    case receive_ctrl_state is

      -- wait until COM40 is ready
      when idle =>
        data_2_received <= '0';
        if ack_receive_i = '0' then
          next_state <= receiving_1;
        else
          next_state <= idle;
        end if;

      -- receive word from COM40
      when receiving_1 =>
        receive <= '1';

        if ack_receive_i = '1' then
          -- check if instruction is 64 bit or 128 bit
          if data_receive(6) = '1' or data_receive(7) = '1' then
            next_state <= syncing;
          else
            next_state <= idle;
            pci_valid_i <= not program_store;
            store_valid_i <= program_store;
          end if;
          pci_instruction_i(63 downto 0) <= data_receive;
        else
          next_state <= receiving_1;
        end if;

      -- 64 bit instruction; get another word from COM40
      -- wait until COM40 ready
      when syncing =>
        if ack_receive_i = '0' then
          if data_2_received = '1' then
            next_state <= receiving_3;
          else
            next_state <= receiving_2;
          end if;
        else
          next_state <= syncing;
        end if;

      -- get second word
      when receiving_2 =>
        receive <= '1';

        if ack_receive_i = '1' then
          if pci_instruction_i(7) = '1' then
            next_state <= syncing;
          else
            next_state <= idle;
            pci_valid_i <= not program_store;
            store_valid_i <= program_store;
          end if;
          data_2_received <= '1';
          pci_instruction_i(128 - 1 downto 64) <= data_receive;
        else
          next_state <= receiving_2;
        end if;
        
      when receiving_3 =>
        receive <= '1';
        data_2_received <= '0';
        
        if ack_receive_i = '1' then
          next_state <= idle;
          pci_instruction_i(INSTR_SIZE - 1 downto 128) <= data_receive;
          pci_valid_i <= not program_store;
          store_valid_i <= program_store;
        else
          next_state <= receiving_3;
        end if;
        

    end case;
  end process;

  -----------------------------------------------------------------------------

  process (rst, clk)
  begin
    if rst = '0' then
      receive_ctrl_state <= idle;
      pci_valid <= '0';
      store_valid <= '0';
      pci_instruction <= (others => '0');
    elsif rising_edge (clk) then
      if stall = '0' and valid = '0' then
        receive_ctrl_state <= next_state;
        pci_valid <= pci_valid_i;
        store_valid <= store_valid_i;
        pci_instruction <= pci_instruction_i;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Fetch 1
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin
    if rst = '0' then
      mem_valid <= '0';
    elsif rising_edge (clk) then
      if flush = '1' then
        mem_valid <= '0';
      elsif stall = '0' then
        mem_valid <= valid;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Fetch 2
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin
    if rst = '0' then
      fetch_instruction <= (others => '0');
      fetch_valid <= '0';
    elsif rising_edge (clk) then
      if flush = '1' then
        fetch_valid <= '0';
      elsif stall = '0' then

        if pci_valid = '1' then
          fetch_instruction <= pci_instruction;
        elsif mem_valid = '1' then
          fetch_instruction <= mem_instruction;
        end if;

        fetch_valid <= pci_valid or mem_valid;

      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Store
  -----------------------------------------------------------------------------

  process (rst, clk)
  begin
    if rst = '0' then
      fetch_enter_normal_mode <= '0';
      fetch_count_pc <= '0';
      write_enable <= '0';
    elsif rising_edge (clk) then
      fetch_enter_normal_mode <= '0';
      fetch_count_pc <= '0';
      write_enable <= '0';

      if store_valid = '1' then
        -- decode instruction to see if program store should end
        if pci_instruction(5 downto 0) = "001111" then
          -- program end
          fetch_enter_normal_mode <= '1';
        else
          -- store instruction
          data_write <= pci_instruction;
          write_enable <= '1';
          fetch_count_pc <= '1';
        end if;
      end if;
    end if;
  end process;

end fetch_arch;
