-------------------------------------------------------------------------------
-- Title      : LUT Conversion Table
-- Project    : 
-------------------------------------------------------------------------------
-- File       : lutconv.vhd
-- Author     : Asbjrn Djupdal  <djupdal@harryklein>
--            : Ola Martin Tiseth Stoevneng
-- Company    :
-- Last update: 2014/03/31
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: A table used to find LUT contents for a specific sblock type
--              Many port; processes LUTCONVS_PER_CYCLE requests each cycle
--              Writing is dual port.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/03/31  4.0      stoevneng Now read only parts of LUTs at a time
-- 2014/01/07  3.0      stoevneng Parameterized efficiency
-- 2013/12/10  2.0      stoevneng Updated to use inferred BRAM
-- 2003/02/24  1.0      djupdal   Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;
use IEEE.numeric_std.all;

library unisim;

entity lutconv is
  
  port (
    -- sblock types to find LUT contents for
    index : in lutconv_type_bus_t;
    slct  : in std_logic_vector(LUTCONV_SELECT_SIZE - 1 downto 0);

    -- LUT contents
    lut_read : out lutconv_lut_bus_t;

    -- LUT value to write to conv table
    lut_write : in std_logic_vector(LUT_SIZE - 1 downto 0);
    -- write enable
    write_en  : in std_logic;

    rst : in std_logic;
    clk : in std_logic);

end lutconv;

architecture lutconv_arch of lutconv is
  type lutconv_lut_bus_i_t is array (LUTCONV_READS_PER_CYCLE - 1 downto 0)
                                      of std_logic_vector(LUT_SIZE - 1 downto 0);
  signal rst_i : std_logic;

  signal one : std_logic_vector(LUTCONV_SELECT_SIZE - 1 downto 0) := (others => '1');
  signal zero : std_logic_vector(LUTCONV_READ_SIZE - 1 downto 0) := (others => '0');
  
  signal write_select : unsigned(LUTCONV_SELECT_SIZE - 1 downto 0);
  signal write_en_i : std_logic;
  signal write_index : std_logic_vector(TYPE_SIZE - 1 downto 0);
  signal lut_write_i : std_logic_vector(LUT_SIZE - 1 downto 0);

  signal write : std_logic_vector(LUTCONV_READ_SIZE - 1 downto 0);
  
  type  lutconv_addr_bus_t is array (LUTCONV_READS_PER_CYCLE - 1 downto 0)
    of std_logic_vector(TYPE_SIZE + LUTCONV_SELECT_SIZE - 1 downto 0); 
  signal addr : lutconv_addr_bus_t;

begin

  rst_i <= not rst;

  process (clk, rst)
  begin
    if (rst = '0') then
      write_en_i <= '0';
      write_select <= (others => '0');
      write_index <= (others => '0');
      lut_write_i <= (others => '0');
    elsif (rising_edge(clk)) then
      if write_en = '1' then
        write_en_i <= '1';
        lut_write_i <= lut_write;
        write_select <= (others => '0');
        write_index <= index(0);
      else
        if write_select = unsigned(one) then
          write_en_i <= '0';
        else
          write_select <= write_select + 1;
        end if;
      end if;
    end if;
  end process;



foreachSrl: for i in 0 to SRLS_PER_LUT - 1 generate
  write((i+1) * LUTCONV_READ_SIZE/SRLS_PER_LUT - 1 downto i * LUTCONV_READ_SIZE/SRLS_PER_LUT)
    <= lut_write_i(i * SRL_LENGTH + LUTCONV_READ_SIZE/SRLS_PER_LUT
                     * (to_integer(unsigned(write_select)) + 1) - 1
            downto i * SRL_LENGTH + LUTCONV_READ_SIZE/SRLS_PER_LUT
                     * to_integer(unsigned(write_select)));
end generate foreachSrl;

foreachaddr: for i in 0 to LUTCONV_READS_PER_CYCLE - 1 generate
  addr(i) <= (write_index & std_logic_vector(write_select)) when write_en_i = '1' else (index(i) & slct);
end generate foreachaddr;

lutconvBrams: for i in 0 to LUTCONV_READS_PER_CYCLE / 2 - 1 generate
  lutconvram : bram_inferrer
    generic map (
      addr_bits => TYPE_SIZE + LUTCONV_SELECT_SIZE,
      data_bits => LUTCONV_READ_SIZE
    )
    port map (
      clk_a => clk,
      clk_b => clk,

      addr_a     => addr(i*2),
      data_i_a   => write,
      data_o_a   => lut_read(i*2),
      we_a       => write_en_i,
      en_a       => one(0),
      rst_a      => rst_i,
    
      addr_b     => addr(i*2+1),
      data_i_b   => zero,
      data_o_b   => lut_read(i*2+1),
      we_b       => zero(0),
      en_b       => one(0),
      rst_b      => rst_i);
end generate;

end lutconv_arch;
