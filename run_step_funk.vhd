-----------------------------------------------------------------------------
-- Title      : run_step funksjon
-- Project    : 
-------------------------------------------------------------------------------
-- File       : run_step_funk.vhd
-- Author     : Kjetil Aamodt
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/03/25
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Wrapper for sum-step function
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/03/25  2.5      stoevneng Re-introduced accumulator to save resources
-- 2013/12/10  2.0      stoevneng Sums all sblock output at the same time.
-- 2005/03/17  1.0      aamodt    Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;
use IEEE.std_logic_signed.all;

entity run_step_funk is

  port (
    data_bus : in  std_logic_vector (SBM_FNK_SIZE - 1 downto 0);
    active   : in  std_logic;

    address_in     : in std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    write_enable_in: in std_logic;
    first_in       : in std_logic;

    value           : out std_logic_vector (RUN_STEP_DATA_BUS_SIZE - 1 downto 0);
    address_out     : out std_logic_vector (RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
    write_enable_out: out std_logic;

    clk      : in  std_logic;
    rst      : in  std_logic);
end run_step_funk;

architecture run_step_funk_arch of run_step_funk is
      signal setup_address     : std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      signal setup_write_enable: std_logic;
      signal setup_data        : std_logic_vector(SBM_FNK_SIZE - 1 downto 0);
      signal setup_first       : std_logic;

      signal trans_address     : std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      signal trans_write_enable: std_logic;
      signal trans_sum         : std_logic_vector(RUN_STEP_DATA_BUS_SIZE - 1 downto 0);

      type   apa is array (RSF_PIPE_LEN - 1 downto 0) 
                    of std_logic_vector(RUN_STEP_ADDR_BUS_SIZE - 1 downto 0);
      signal pipe_address     : apa;
      signal pipe_write_enable: std_logic_vector(RSF_PIPE_LEN - 1 downto 0);
      signal pipe_first       : std_logic_vector(RSF_PIPE_LEN - 1 downto 0);
      
      signal zero  : std_logic_vector(RUN_STEP_DATA_BUS_SIZE - RSF_VAL_SIZE - 1 downto 0) := (others => '0');
      signal sum  : std_logic_vector(RSF_VAL_SIZE - 1 downto 0);

      
begin 

  -----------------------------------------------------------------------------
  -- Setup
  -----------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge (clk) then
      setup_address <= address_in;
      setup_write_enable <= write_enable_in;
      setup_first <= first_in;
      if active = '1' then
        setup_data <= data_bus(SBM_FNK_SIZE - 1 downto 0);
      else
        setup_data <= (others => '0');
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Transform
  -----------------------------------------------------------------------------
  --transform data

  count_unit: bitcounterN
    generic map (
      N => SBM_FNK_SIZE,
      L => RSF_VAL_SIZE)
    port map (
      input => setup_data,
      f     => sum,
      clk => clk);

  process (clk)
  begin
    if rising_edge (clk) then
      pipe_address(0) <= setup_address;
      pipe_write_enable(0) <= setup_write_enable;
      pipe_first(0) <= setup_first;
    end if;
  end process;
  
  -----------------------------------------------------------------------------
  -- Wait
  -----------------------------------------------------------------------------
  rsfpipe: for i in RSF_PIPE_LEN - 1 downto 1 generate
    process (clk)
    begin
      if rising_edge (clk) then
        pipe_address(i) <= pipe_address(i-1);
        pipe_write_enable(i) <= pipe_write_enable(i-1);
        pipe_first(i) <= pipe_first(i-1);
      end if;
    end process;
  end generate rsfpipe;

  -----------------------------------------------------------------------------
  -- Last Sum
  -----------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge (clk) then
      trans_write_enable <= pipe_write_enable(RSF_PIPE_LEN-1);
      trans_address <= pipe_address(RSF_PIPE_LEN-1);
      if pipe_first(RSF_PIPE_LEN-1) = '1' then
        trans_sum <= zero & sum;
      else
        trans_sum <= trans_sum + (zero & sum);
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Output
  -----------------------------------------------------------------------------
  value  <= trans_sum;
  address_out <= trans_address when trans_write_enable = '1' else (others => 'Z');
  write_enable_out <= trans_write_enable;
  
  
end run_step_funk_arch;
