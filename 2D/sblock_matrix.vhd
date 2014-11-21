-------------------------------------------------------------------------------
-- Title      : sblock_matrix
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sblock_matrix.vhd
-- Author     : Asbjørn Djupdal  <djupdal@idi.ntnu.no>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/02/10
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/02/10  2.0      stoevneng Separated rsf and readback reads.
-- 2003/01/17  1.1      djupdal
-- 2002/10/05  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.sblock_package.all;
use work.funct_package.all;

entity sblock_matrix is
  
  port (
    -- databus with one word of sblock states
    databus_read  : out std_logic_vector(SBM_RDB_SIZE - 1 downto 0);
    -- databus with all sblock states
    databus_read_funk : out std_logic_vector(SBM_FNK_SIZE - 1 downto 0);
    -- selects which sblocks should write to databus_read
    -- One bit for each set of sblocks that should drive the bus
    -- Only one bit must be set at a time
    output_select : in  std_logic_vector(READBACK_WORDS - 1 downto 0);

    
    -- config databuses
    databus_lut_l_write : in std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
    databus_lut_h_write : in std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
    databus_ff_write    : in std_logic_vector(SBM_CFG_SIZE - 1 downto 0);

    config_enable_lut : in std_logic_vector(CONFIG_WORDS - 1 downto 0);
    config_enable_ff  : in std_logic_vector(CONFIG_WORDS - 1 downto 0);

    -- enables all sblocks in the sblock matrix
    run_matrix : in std_logic;

    rst : in std_logic;
    clk : in std_logic);

end sblock_matrix;

architecture sblock_matrix_arch of sblock_matrix is

  type outputwords_t is
    array (integer range <>) of std_logic_vector(SBM_RDB_SIZE - 1 downto 0);

  type std_logic_matrix is
    array (ROWS-1 downto 0) of std_logic_vector(COLUMNS-1 downto 0);

  signal output_words : outputwords_t(READBACK_WORDS - 1 downto 0);

  signal east_i              : std_logic_matrix;
  signal south_i             : std_logic_matrix;
  signal north_i             : std_logic_matrix;
  signal west_i              : std_logic_matrix;
  signal output_i            : std_logic_matrix;
  signal conf_data_l_i       : std_logic_matrix;
  signal conf_data_h_i       : std_logic_matrix;
  signal conf_data_ff_i      : std_logic_matrix;
  signal config_lut_enable_i : std_logic_matrix;
  signal config_ff_enable_i  : std_logic_matrix;

  signal databus_read_i : std_logic_vector(SBM_RDB_SIZE - 1 downto 0);
  signal databus_read_funk_i : std_logic_vector(SBM_FNK_SIZE - 1 downto 0);

begin  -- sblock_matrix_arch

  -- databus is registered
  process (rst, clk)
  begin
    if rst = '0' then
      databus_read <= (others => '0');
      databus_read_funk <= (others => '0');
    elsif rising_edge (clk) then
      databus_read <= databus_read_i;
      databus_read_funk <= databus_read_funk_i;
    end if;
  end process;


  -- selects which set of sblocks should drive inputs to databus register
  -- This is a scalability problem, because only a given amount of tristate
  -- buffers may drive the same bus. 
  driveBus_out: for i in 0 to READBACK_WORDS - 1 generate
    databus_read_i <= output_words(i) when output_select(i) = '1' else
                      (others => 'Z');
  end generate driveBus_out;

  driveBus_fnk_out: for i in 0 to ROWS - 1 generate
    databus_read_funk_i( (i + 1) * COLUMNS - 1 downto i * COLUMNS ) <= output_i(i);
  end generate driveBus_fnk_out;

  -- setup output_words signals.  Grouped strangely because it enables use of
  -- all of BRAM-1 write ports for each cycle in readback phase
  rdb_foreachword: for i in 0 to READBACK_WORDS - 1 generate
    rdb_foreachbramword : for j in 0 to 4 - 1 generate
      output_words(i)(ENTRIES_PER_WORD * (j + 1) - 1 downto ENTRIES_PER_WORD * j) 
           <= reverse_slv(output_i((2 * ((i * 16) / COLUMNS)) + 0)
                      ((i*16) mod COLUMNS + ENTRIES_PER_WORD * (j+1) - 1
                      downto (i * 16) mod COLUMNS + ENTRIES_PER_WORD * j));
      output_words(i)(ENTRIES_PER_WORD * (j + 5) - 1 downto ENTRIES_PER_WORD * (j+4)) 
           <= reverse_slv(output_i((2 * ((i * 16) / COLUMNS)) + 1)
                      ((i*16) mod COLUMNS + ENTRIES_PER_WORD * (j+1) - 1
                      downto (i * 16) mod COLUMNS + ENTRIES_PER_WORD * j));
    end generate rdb_foreachbramword;
  end generate rdb_foreachword;

  -- setup config signals
  cfg_foreachword: for i in 0 to CONFIG_WORDS - 1 generate
    cfg_foreachbit: for j in 0 to SBM_CFG_SIZE - 1 generate
      cfg_setsignals: if ((i * SBM_CFG_SIZE + j) / COLUMNS) < ROWS generate
        -- config data
        conf_data_l_i((i * SBM_CFG_SIZE + j) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= 
          databus_lut_l_write(j);

        conf_data_h_i((i * SBM_CFG_SIZE + j) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= 
          databus_lut_h_write(j);

        conf_data_ff_i((i * SBM_CFG_SIZE + j) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= 
          databus_ff_write(j);

        -- config enable
        config_lut_enable_i((i * SBM_CFG_SIZE + j) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= config_enable_lut(i);

        config_ff_enable_i((i * SBM_CFG_SIZE + j) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= config_enable_ff(i);
      end generate cfg_setsignals;

    end generate cfg_foreachbit;
  end generate cfg_foreachword;

  -- generate sblock matrix from lots of sblocks
  sblock_rows: for i in 0 to ROWS-1 generate
    sblock_columns: for j in 0 to COLUMNS-1 generate

      -- instantiation of sblock

      sblock_inst: sblock
        port map (
          east   => east_i(i)(j),
          south  => south_i(i)(j),
          north  => north_i(i)(j),
          west   => west_i(i)(j),

          conf_data_l       => conf_data_l_i(i)(j),
          conf_data_h       => conf_data_h_i(i)(j),
          conf_data_ff      => conf_data_ff_i(i)(j),
          config_lut_enable => config_lut_enable_i(i)(j),
          config_ff_enable  => config_ff_enable_i(i)(j),

          output => output_i(i)(j),
          run    => run_matrix,
          clk    => clk);

      -- east-west routing

      west_end: if j=0 generate
        west_i(i)(j) <= output_i(i)(COLUMNS-1);  -- wrap around
        east_i(i)(j) <= output_i(i)(j+1);
      end generate west_end;

      west_east: if j>0 and j<(COLUMNS-1) generate
        west_i(i)(j) <= output_i(i)(j-1);
        east_i(i)(j) <= output_i(i)(j+1);
      end generate west_east;

      east_end: if j=(COLUMNS-1) generate
        west_i(i)(j) <= output_i(i)(j-1);
        east_i(i)(j) <= output_i(i)(0);  -- wrap around
      end generate east_end;
      
      -- north-south routing

      north_end: if i=0 generate
        north_i(i)(j) <= output_i(ROWS-1)(j);  -- wrap around
        south_i(i)(j) <= output_i(i+1)(j);
      end generate north_end;

      north_south: if i>0 and i<(ROWS-1) generate
        north_i(i)(j) <= output_i(i-1)(j);
        south_i(i)(j) <= output_i(i+1)(j);
      end generate north_south;

      south_end: if i=(ROWS-1) generate
        north_i(i)(j) <= output_i(i-1)(j);
        south_i(i)(j) <= output_i(0)(j);  -- wrap around
      end generate south_end;

    end generate sblock_columns;
  end generate sblock_rows;
  
end sblock_matrix_arch;
