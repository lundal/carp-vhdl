-------------------------------------------------------------------------------
-- Title      : Decode
-- Project    : 
-------------------------------------------------------------------------------
-- File       : decode.vhd
-- Author     : Asbjørn Djupdal  <asbjoern@djupdal.org>
--            : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/04/09
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Decode pipeline stage
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/04/09  3.0      stoevneng Extended and added instructions.
-- 2005/04/11  2.0      aamodt    Added instruksjons
-- 2003/03/28  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;

entity decode is

  port (
    ---------------------------------------------------------------------------
    -- fetch

    fetch_instruction : in std_logic_vector(INSTR_SIZE - 1 downto 0);
    fetch_valid       : in std_logic;

    fetch_enter_normal_mode : in std_logic;
    fetch_count_pc          : in std_logic;

    dec_program_counter : out std_logic_vector(INSTR_ADDR_SIZE - 1 downto 0);
    -- fetch should get instruction from memory
    dec_valid           : out std_logic;

    flush_fetch : out std_logic;

    -- fetch should store PCI instructions to memory
    dec_program_store : out std_logic;

    ---------------------------------------------------------------------------
    -- load send store

    -- flags telling LSS what to do
    dec_read_sblock : out std_logic;
    dec_send_type   : out std_logic;
    dec_send_types  : out std_logic;
    dec_send_state  : out std_logic;
    dec_send_states : out std_logic;
    dec_clear_bram  : out std_logic;
    dec_write_type  : out std_logic;
    dec_write_state : out std_logic;
    dec_write_word  : out std_logic;
--Kaa
    dec_send_sums      : out std_logic;
    dec_send_used_rules: out std_logic;
    dec_read_usedrules : out std_logic;
    dec_send_rulevector: out std_logic;
    dec_send_fitness   : out std_logic;
    dec_start_fitness  : out std_logic;
--Kaa
    -- additional data
    dec_address       : out std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
    dec_port_select   : out std_logic_vector(2 downto 0);
    dec_sblock_number : out std_logic_vector(COORD_SIZE_X - 2 downto 0);
    dec_type_data     : out std_logic_vector(TYPE_SIZE - 1 downto 0);
    dec_state_data    : out std_logic;
    dec_type_word     : out std_logic_vector(TYPE_BUS_SIZE - 1 downto 0);
    dec_state_words   : out std_logic_vector(STATE_BUS_SIZE * SBM_BRAM_MODULES - 1 downto 0);

--Kaa
    dec_number_of_readback_values: out std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
--Kaa
    
    ---------------------------------------------------------------------------
    -- hazard

    stall               : in  std_logic;
    dont_issue          : in  std_logic;
    dec_sbm_pipe_access : out std_logic;
    dec_lss_access      : out std_logic;

    ---------------------------------------------------------------------------
    -- rule storage, used for writing rules

    dec_store_rule    : out std_logic;
    dec_rule_number   : out std_logic_vector(RULE_NBR_BUS_SIZE - 1 downto 0);
    dec_rule_to_store : out std_logic_vector(RULE_SIZE - 1 downto 0);
    dec_nbr_of_last_rule : out std_logic_vector(7 downto 0);

    ---------------------------------------------------------------------------
    -- lutconv, used for writing entries

    dec_lutconv_index    : out lutconv_type_bus_t;
    dec_lutconv_write    : out std_logic_vector(LUT_SIZE - 1 downto 0);
    dec_lutconv_write_en : out std_logic;

    ---------------------------------------------------------------------------
    -- dev

    dec_start_devstep : out std_logic;

    ---------------------------------------------------------------------------
    -- sbm pipe

    dec_start_config   : out std_logic;
    dec_start_readback : out std_logic;
    dec_run_matrix     : out std_logic;

    dec_cycles_to_run  : out std_logic_vector(23 downto 0);

    ---------------------------------------------------------------------------
    -- sbm bram mgr

    ---------------------------------------------------------------------------
    -- dft
    
    dec_dft_first_addr     : out std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    dec_dft_set_first_addr : out std_logic;
    dec_start_dft          : out std_logic;

    dec_select_sbm : out std_logic;

    ---------------------------------------------------------------------------
    -- other

    rst : in std_logic;
    clk : in std_logic);

end decode;

architecture decode_arch of decode is

  signal flush_fetch_i          : std_logic;
  signal dec_valid_i            : std_logic;
  signal dec_program_counter_i  : std_logic_vector(INSTR_ADDR_SIZE - 1 downto 0);
  signal dec_program_store_i    : std_logic;
  signal dec_select_sbm_i       : std_logic;
  signal dec_lutconv_write_en_i : std_logic;
  signal dec_nbr_of_last_rule_i : std_logic_vector(7 downto 0);
  signal dec_type_data_i        : std_logic_vector(TYPE_SIZE - 1 downto 0);
--Kaa
  signal dec_number_of_readback_values_i : std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
--Kaa
  signal dec_program_store_address_i : std_logic_vector(INSTR_ADDR_SIZE - 1 downto 0);

  signal addr                  : std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
  signal port_select           : std_logic_vector(2 downto 0);
  signal sblock_number         : std_logic_vector(COORD_SIZE_X - 2 downto 0);
  signal read_sblock           : std_logic;
--Kaa
  signal read_usedrules        : std_logic;
  signal read_sums_mem         : std_logic;
--Kaa
  signal send_type             : std_logic;
  signal send_types            : std_logic;
  signal send_state            : std_logic;
  signal send_states           : std_logic;
--Kaa
  signal send_sums             : std_logic;
  signal send_used_rules       : std_logic;
  signal send_rulevector       : std_logic;
  signal send_fitness          : std_logic;
  signal start_fitness         : std_logic;
--Kaa
  signal write_type            : std_logic;
  signal write_state           : std_logic;
  signal write_word            : std_logic;
  signal start_devstep         : std_logic;
  signal start_config          : std_logic;
  signal start_readback        : std_logic;
  signal run_matrix            : std_logic;
  signal lutconv_write_en      : std_logic;
  signal store_rule            : std_logic;
  signal select_sbm            : std_logic;
  signal nbr_of_last_rule      : std_logic_vector(7 downto 0);
--Kaa
  signal number_of_readback_values : std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
  signal jump_value              : std_logic_vector (7 downto 0);
--Kaa
  signal valid                 : std_logic;
  signal program_counter       : std_logic_vector(INSTR_ADDR_SIZE - 1 downto 0);
  signal program_store         : std_logic;
  signal program_store_address : std_logic_vector(INSTR_ADDR_SIZE - 1 downto 0);
  signal sbm_pipe_access       : std_logic;
  signal lss_access            : std_logic;
  signal clear_bram            : std_logic;

  signal reset_dev_step        : std_logic;
--Kaa
  --register for counting of dev-steps
  signal dev_step_value     : unsigned(7 downto 0);
--Kaa
  signal start_dft          : std_logic;
  signal dft_set_first_addr : std_logic;
  signal dft_first_addr     : std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
begin

  loadsendstore_addr : addr_gen
    port map (
      x             => fetch_instruction(COORD_SIZE_X + 7 downto 8),
      y             => fetch_instruction(COORD_SIZE_Y + 15 downto 16),
      z             => fetch_instruction(COORD_SIZE_Z + 23 downto 24),
      addr          => addr,
      sblock_number => sblock_number,
      port_select   => port_select);

  -----------------------------------------------------------------------------

  -- instruction decoder
  -- calculates next values of pipeline registers based on instruction register
  process (stall, dec_select_sbm_i, fetch_valid, fetch_instruction,
           dec_valid_i, fetch_count_pc, dec_program_counter_i,
           dec_program_store_i, fetch_enter_normal_mode,
           dec_nbr_of_last_rule_i,
           dec_number_of_readback_values_i, jump_value, dev_step_value)
  begin
    
    ---------------------------------------------------------------------------
    -- default values

    -- clear flags
    read_sblock      <= '0';
--Kaa
    read_usedrules   <= '0';
--Kaa
    send_type        <= '0';
    send_types       <= '0';
    send_state       <= '0';
    send_states      <= '0';
--Kaa
    read_sums_mem    <= '0';
    send_sums        <= '0';
    send_used_rules  <= '0';
    reset_dev_step   <= '0';
    send_rulevector  <= '0';
    send_fitness     <= '0';
    start_fitness    <= '0';
--Kaa
    write_type       <= '0';
    write_state      <= '0';
    write_word       <= '0';
    start_devstep    <= '0';
    sbm_pipe_access  <= '0';
    start_config     <= '0';
    start_readback   <= '0';
    run_matrix       <= '0';
    lutconv_write_en <= '0';
    store_rule       <= '0';
    lss_access       <= '0';
    clear_bram       <= '0';
    flush_fetch_i    <= '0';
    jump_value       <= (others => '0');

    dft_set_first_addr <= '0';
    start_dft          <= '0';
    -- should keep its value
    select_sbm       <= dec_select_sbm_i;
    valid            <= dec_valid_i;
    nbr_of_last_rule <= dec_nbr_of_last_rule_i;
--Kaa
    number_of_readback_values <= dec_number_of_readback_values_i ;
--Kaa

    -- program counter, either increment or keep value
    if dec_program_store_i = '0' or fetch_count_pc = '1' then
      program_counter <=
        std_logic_vector (unsigned (dec_program_counter_i) + 1);
    else
      program_counter <= dec_program_counter_i;
    end if;

    -- either keep value or clear based on signal from Store
    program_store <= dec_program_store_i and not fetch_enter_normal_mode;

    ---------------------------------------------------------------------------
    -- decode instruction
    if fetch_valid = '1' then
      case fetch_instruction(5 downto 0) is

        when "000000" =>
          -- nop
          null;

        when "000001" =>
          -- write type
          read_sblock <= '1';
          write_type <= '1';
          lss_access <= '1';

        when "000010" =>
          -- read type
          read_sblock <= '1';
          send_type <= '1';
          lss_access <= '1';

        when "000011" =>
          -- switch sbm
          select_sbm <= not dec_select_sbm_i;

        when "000100" =>
          -- write state
          read_sblock <= '1';
          write_state <= '1';
          lss_access <= '1';

        when "000101" =>
          -- read state
          read_sblock <= '1';
          send_state <= '1';
          lss_access <= '1';

        when "000110" =>
          -- write lut conv
          lutconv_write_en <= '1';

        when "000111" =>
          -- config
          start_config <= '1';
          sbm_pipe_access <= '1';

        when "001000" =>
          -- readback
          start_readback <= '1';
          sbm_pipe_access <= '1';

        when "001001" =>
          -- run matrix
          run_matrix <= '1';
          sbm_pipe_access <= '1';

        when "001010" =>
          -- devstep
          start_devstep <= '1';

        when "001011" =>
          -- store rule
          store_rule <= '1';

        when "001100" =>
          -- jump
          valid <= '1';
          program_counter <= fetch_instruction(INSTR_ADDR_SIZE + 7 downto 8);
          flush_fetch_i <= not stall;

        when "001101" =>
          -- break
          valid <= '0';
          flush_fetch_i <= not stall;

        when "001110" =>
          -- store program
          program_store <= '1';
          program_counter <= fetch_instruction(INSTR_ADDR_SIZE + 7 downto 8);

        -- when 01111 =>
        -- -- end
        -- this instruction is controlled in fetch
          
        when "010000" =>
          -- read types
          send_types <= '1';
          lss_access <= '1';

        when "010001" =>
          -- read states
          send_states <= '1';
          lss_access <= '1';

        when "010010" =>
          -- set number of rules
          nbr_of_last_rule <= fetch_instruction(15 downto 8);

        when "010011" =>
          -- clear sbm bram
          clear_bram <= '1';
          lss_access <= '1';
--Kaa
        when "010100" =>
          -- read sums
          send_sums <=  '1';
          lss_access <=  '1';
          number_of_readback_values <=
            fetch_instruction((RUN_STEP_ADDR_BUS_SIZE - 1) + 8 downto 8);
          
        when "010101" =>
          -- readDevRules
          send_used_rules <= '1';
          lss_access <= '1';
          read_usedrules <= '1';
          
        when "010110" =>
          --jump if parameter is equal to dev_counter value
          jump_value <= fetch_instruction(55 downto 48);
          if unsigned(jump_value) = dev_step_value then
            valid <= '1';
            program_counter <= fetch_instruction(INSTR_ADDR_SIZE + 7 downto 8);
            flush_fetch_i <= not stall;
          end if;
          
        when "010111" =>
          -- reset dev step counter
          reset_dev_step <= '1';
          
        when "011000" =>
          -- read rulevector
          send_rulevector <= '1';
          lss_access <= '1';
          number_of_readback_values(RUN_STEP_ADDR_BUS_SIZE - 1 downto 8) <= (others => '0'); 
          -- address bus is 8 bit
          number_of_readback_values(7 downto 0) <= fetch_instruction(7 + 8 downto 8);

        when "011001" =>
          -- send fitness
          send_fitness <= '1';
          lss_access <= '1';

        when "011010" =>
          -- start fitness
          start_fitness <= '1';
          number_of_readback_values <=
            fetch_instruction((RUN_STEP_ADDR_BUS_SIZE - 1) + 8 downto 8);
--Kaa
        when "100001" =>
          -- write 4 types
          write_type <= '1';
          lss_access <= '1';
          write_word <= '1';
          read_sblock <= '1';

        when "100100" =>
          -- write 16 states
          write_state <= '1';
          lss_access <= '1';
          write_word <= '1';
          read_sblock <= '1';

        when "111000" =>
          --start dft
          start_dft <= '1';
          dft_set_first_addr <= '1';
        when others =>
          null;
      end case;
    end if;
  end process;

  -----------------------------------------------------------------------------

  -- pipeline registers
  process (rst, clk)
  begin

    if rst = '0' then
      dec_read_sblock        <= '0';
--Kaa
      dec_read_usedrules     <= '0';
--Kaa
      dec_send_type          <= '0';
      dec_send_types         <= '0';
      dec_send_state         <= '0';
      dec_send_states        <= '0';
      dec_write_type         <= '0';
--Kaa
      dec_send_sums          <= '0';
      dec_send_used_rules    <= '0';
      dec_send_rulevector    <= '0';
      dec_send_fitness       <= '0';
      dec_start_fitness      <= '0';
--Kaa
      dec_write_state        <= '0';
      dec_write_word         <= '0';
      dec_start_devstep      <= '0';
      dec_start_config       <= '0';
      dec_start_readback     <= '0';
      dec_run_matrix         <= '0';
      dec_lutconv_write_en_i <= '0';
      dec_store_rule         <= '0';
      dec_sbm_pipe_access    <= '0';
      dec_lss_access         <= '0';
      dec_clear_bram         <= '0';
      dec_select_sbm_i       <= '0';
      dec_valid_i            <= '0';
      dec_program_counter_i  <= (others => '0');
      dec_program_store_i    <= '0';
      dec_nbr_of_last_rule_i <= (others => '0');
--Kaa
      dec_number_of_readback_values_i <= (others => '0');
--Kaa
      dec_start_dft          <= '0';
      dec_dft_set_first_addr <= '0';
      dec_dft_first_addr     <= (others => '0');
    elsif rising_edge (clk) then
      if stall = '0' then
        if dont_issue = '0' then
          dec_read_sblock        <= read_sblock;
--Kaa
          dec_read_usedrules     <= read_usedrules;
--Kaa
          dec_send_type          <= send_type;
          dec_send_types         <= send_types;
          dec_send_state         <= send_state;
          dec_send_states        <= send_states;
          dec_send_fitness       <= send_fitness;
          dec_start_fitness      <= start_fitness;
--Kaa
          dec_send_sums          <= send_sums;
          dec_send_used_rules    <= send_used_rules;
          dec_send_rulevector    <= send_rulevector;
--Kaa
          dec_write_type         <= write_type;
          dec_write_state        <= write_state;
          dec_write_word         <= write_word;
          dec_start_devstep      <= start_devstep;
          dec_start_config       <= start_config;
          dec_start_readback     <= start_readback;
          dec_run_matrix         <= run_matrix;
          dec_lutconv_write_en_i <= lutconv_write_en;
          dec_store_rule         <= store_rule;
          dec_sbm_pipe_access    <= sbm_pipe_access;
          dec_lss_access         <= lss_access;
          dec_clear_bram         <= clear_bram;

          dec_select_sbm_i        <= select_sbm;
          dec_valid_i             <= valid;
          dec_program_counter_i   <= program_counter;
          dec_program_store_i     <= program_store;
          dec_nbr_of_last_rule_i  <= nbr_of_last_rule;
          dec_dft_set_first_addr  <= dft_set_first_addr;
          dec_start_dft           <= start_dft;
--Kaa
          dec_number_of_readback_values_i <= number_of_readback_values;

          --increment counter for each dev step
          if start_devstep = '1' then
            dev_step_value <= dev_step_value + 1;
          end if;

          if reset_dev_step = '1' then
            dev_step_value <= (others => '0');
          end if;
--Kaa
        else
          -- hazard sais: don't issue instruction
          -- clearing all signals that activates later pipelines
          dec_read_sblock        <= '0';
--Kaa
          dec_read_usedrules     <= '0';
--Kaa
          dec_send_type          <= '0';
          dec_send_types         <= '0';
          dec_send_state         <= '0';
          dec_send_states        <= '0';
--Kaa
          dec_send_sums          <= '0';
          dec_send_used_rules    <= '0';
          dec_send_rulevector    <= '0';
          dec_send_fitness       <= '0';
          dec_start_fitness      <= '0';
--Kaa
          dec_write_type         <= '0';
          dec_write_state        <= '0';
          dec_write_word         <= '0';
          dec_start_devstep      <= '0';
          dec_start_config       <= '0';
          dec_start_readback     <= '0';
          dec_run_matrix         <= '0';
          dec_lutconv_write_en_i <= '0';
          dec_store_rule         <= '0';
          dec_sbm_pipe_access    <= '0';
          dec_lss_access         <= '0';
          dec_clear_bram         <= '0';
          dec_start_dft          <= '0';
          dec_dft_set_first_addr <= '0';

        end if;

        -- other registers, directly dependent on instruction register

        dec_type_data_i <= fetch_instruction(TYPE_SIZE + 31 downto 32);
        dec_state_data <= fetch_instruction(63);
        for i in 0 to ENTRIES_PER_WORD - 1 loop
          dec_type_word(TYPE_SIZE * (i+1) - 1 downto TYPE_SIZE * i)
            <= fetch_instruction(8 * i + TYPE_SIZE + 63 downto 8 * i + 64);
        end loop;
        dec_state_words <= fetch_instruction(STATE_BUS_SIZE * SBM_BRAM_MODULES + 63 downto 64);
        
        dec_rule_number <= fetch_instruction(RULE_NBR_BUS_SIZE + 7 downto 8);
        dec_rule_to_store <= fetch_instruction(RULE_SIZE + 38 downto 39);

        dec_address <= addr;
        dec_sblock_number <= sblock_number;
        dec_port_select <= port_select;

        dec_lutconv_write <= fetch_instruction(LUT_SIZE + 63 downto 64);
        
        dec_cycles_to_run <= fetch_instruction(31 downto 8);
--Kaa
        dec_number_of_readback_values <= dec_number_of_readback_values_i;
--Kaa
        dec_dft_first_addr <= fetch_instruction(RUN_STEP_ADDR_BUS_SIZE + 31 downto 32);
      end if;

    end if;
  end process;

  -----------------------------------------------------------------------------

  -- real pipeline registers are just alias of the internal ones

  dec_type_data <= dec_type_data_i;
  dec_select_sbm <= dec_select_sbm_i;
  dec_lutconv_write_en <= dec_lutconv_write_en_i;
  dec_program_counter <= dec_program_counter_i;
  dec_valid <= dec_valid_i;
  dec_program_store <= dec_program_store_i;
  dec_nbr_of_last_rule <= dec_nbr_of_last_rule_i;
  flush_fetch <= flush_fetch_i and not dont_issue;

  -----------------------------------------------------------------------------

  -- setup index for lut convert table
  process (dec_lutconv_write_en_i, dec_type_data_i)
  begin
    if dec_lutconv_write_en_i = '1' then
      for i in 0 to LUTCONV_READS_PER_CYCLE / 2 - 1 loop
        dec_lutconv_index(i*2)   <= dec_type_data_i;
        dec_lutconv_index(i*2+1) <= (others => 'Z');
      end loop;
    else
      dec_lutconv_index <= (others => (others => 'Z'));
    end if;
  end process;

  -----------------------------------------------------------------------------

end decode_arch;
