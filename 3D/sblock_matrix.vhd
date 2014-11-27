-------------------------------------------------------------------------------
-- Title      : sblock_matrix
-- Project    : 
-------------------------------------------------------------------------------
-- File       : sblock_matrix.vhd
-- Author     : Asbjørn Djupdal  <djupdal@idi.ntnu.no>
--            : Ola Martin Tiseth Stoevneng
-- Company    : 
-- Last update: 2014/03/25
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2014/03/25  2.5      stoevneng Updated for 3D
-- 2014/02/10  2.0      stoevneng Separated rsf and readback reads.
-- 2003/01/17  1.1      djupdal
-- 2002/10/05  1.0      djupdal	  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sblock_package.all;
use work.funct_package.all;

entity sblock_matrix is
  
  port (
    -- databus with one word of sblock states
    databus_read  : out std_logic_vector(SBM_RDB_SIZE - 1 downto 0);
    -- databus with all sblock states
    databus_read_funk : out std_logic_vector(SBM_FNK_SIZE - 1 downto 0);
    output_funk_select : in std_logic_vector(RSF_READS_SIZE - 1 downto 0);
    -- selects which sblocks should write to databus_read
    -- One bit for each set of sblocks that should drive the bus
    -- Only one bit must be set at a time
    output_select : in  std_logic_vector(READBACK_WORDS - 1 downto 0);

    
    -- config databuses
--    databus_lut_l_write : in std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
--    databus_lut_h_write : in std_logic_vector(SBM_CFG_SIZE - 1 downto 0);
    databus_lut_write : in std_logic_vector(SBM_CFG_SIZE*SRLS_PER_LUT - 1 downto 0);
    databus_ff_write  : in std_logic_vector(SBM_CFG_SIZE - 1 downto 0);

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
    
  type std_logic_layer is
    array (ROWS - 1 downto 0) of std_logic_vector(COLUMNS - 1 downto 0);

  type std_logic_matrix is
    array (LAYERS - 1 downto 0) of std_logic_layer;

  type std_logic_vector_row is
    array (COLUMNS-1 downto 0) of std_logic_vector(SRLS_PER_LUT-1 downto 0);
  type std_logic_vector_layer is
    array (ROWS-1 downto 0) of std_logic_vector_row;
  type std_logic_vector_matrix is
    array (LAYERS-1 downto 0) of std_logic_vector_layer;

  signal output_words : outputwords_t(READBACK_WORDS - 1 downto 0);

  signal east_i              : std_logic_matrix;
  signal south_i             : std_logic_matrix;
  signal north_i             : std_logic_matrix;
  signal west_i              : std_logic_matrix;
  signal up_i                : std_logic_matrix;
  signal down_i              : std_logic_matrix;
  signal output_i            : std_logic_matrix;
  signal conf_data_i         : std_logic_vector_matrix;
--  signal conf_data_l_i       : std_logic_matrix;
--  signal conf_data_h_i       : std_logic_matrix;
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

  driveBus_fnk_z: for i in 0 to LAYERS/RSF_READS - 1 generate
    driveBus_fnk_y: for j in 0 to ROWS - 1 generate
      databus_read_funk_i( (i*ROWS+j + 1) * COLUMNS - 1 downto (i*ROWS+j) * COLUMNS ) <= output_i(i+to_integer(unsigned(output_funk_select))*LAYERS/RSF_READS)(j);
    end generate driveBus_fnk_y;
  end generate driveBus_fnk_z;

  -- setup output_words signals.  Grouped strangely because it enables use of
  -- all of BRAM-1 write ports for each cycle in readback phase
  rdb_foreachword: for i in 0 to READBACK_WORDS - 1 generate
    rdb_forlayer : for j in 0 to 1 generate
      rdb_forrow : for k in 0 to 3 generate
        rdb_forc : for l in 0 to 1 generate
          output_words(i)(ENTRIES_PER_WORD * (j*8+(k mod 2)*4+k/2+l*2 + 1) - 1 
                          downto ENTRIES_PER_WORD * (j*8+(k mod 2)*4+k/2+l*2))
            <= reverse_slv(
                 output_i(2*((i*4)/ROWS) + j)
                         ((i*ROWS/4+k) mod ROWS)
                         ((l+1)*ENTRIES_PER_WORD - 1 downto l*ENTRIES_PER_WORD)
               );
        end generate rdb_forc;
      end generate rdb_forrow;
    end generate rdb_forlayer;
  end generate rdb_foreachword;

  -- setup config signals
  cfg_foreachword: for i in 0 to CONFIG_WORDS - 1 generate
    cfg_foreachbit: for j in 0 to SBM_CFG_SIZE - 1 generate
      cfg_setsignals: if (((i * SBM_CFG_SIZE + j) / COLUMNS)/ LAYERS) < LAYERS generate
        -- config data
        conf_data_i((i * SBM_CFG_SIZE + j) / (COLUMNS * ROWS))
		    (((i * SBM_CFG_SIZE + j) mod (COLUMNS * ROWS)) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= 
          databus_lut_write((j+1)*SRLS_PER_LUT-1 downto j*SRLS_PER_LUT);

        conf_data_ff_i((i * SBM_CFG_SIZE + j) / (COLUMNS * ROWS))
		    (((i * SBM_CFG_SIZE + j) mod (COLUMNS * ROWS)) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= 
          databus_ff_write(j);

        -- config enable
        config_lut_enable_i((i * SBM_CFG_SIZE + j) / (COLUMNS * ROWS))
		    (((i * SBM_CFG_SIZE + j) mod (COLUMNS * ROWS)) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= config_enable_lut(i);

        config_ff_enable_i((i * SBM_CFG_SIZE + j) / (COLUMNS * ROWS))
		    (((i * SBM_CFG_SIZE + j) mod (COLUMNS * ROWS)) / COLUMNS)
          ((i * SBM_CFG_SIZE + j) mod COLUMNS) <= config_enable_ff(i);
      end generate cfg_setsignals;

    end generate cfg_foreachbit;
  end generate cfg_foreachword;

  -- generate sblock matrix from lots of sblocks
  sblock_layers: for i in 0 to LAYERS-1 generate
    sblock_rows: for j in 0 to ROWS-1 generate
      sblock_columns: for k in 0 to COLUMNS-1 generate

        -- instantiation of sblock

        sblock_inst: sblock
          port map (
            east   => east_i(i)(j)(k),
            south  => south_i(i)(j)(k),
            north  => north_i(i)(j)(k),
            west   => west_i(i)(j)(k),
            up     => up_i(i)(j)(k),
            down   => down_i(i)(j)(k),

--            conf_data_l       => conf_data_l_i(i)(j),
--            conf_data_h       => conf_data_h_i(i)(j),
            conf_data         => conf_data_i(i)(j)(k),
            conf_data_ff      => conf_data_ff_i(i)(j)(k),
            config_lut_enable => config_lut_enable_i(i)(j)(k),
            config_ff_enable  => config_ff_enable_i(i)(j)(k),

            output => output_i(i)(j)(k),
            run    => run_matrix,
            clk    => clk);

        -- east-west routing

        west_end: if k=0 generate
          west_i(i)(j)(k) <= output_i(i)(j)(COLUMNS-1);  -- wrap around
          east_i(i)(j)(k) <= output_i(i)(j)(k+1);
        end generate west_end;

        west_east: if k>0 and k<(COLUMNS-1) generate
          west_i(i)(j)(k) <= output_i(i)(j)(k-1);
          east_i(i)(j)(k) <= output_i(i)(j)(k+1);
        end generate west_east;

        east_end: if k=(COLUMNS-1) generate
          west_i(i)(j)(k) <= output_i(i)(j)(k-1);
          east_i(i)(j)(k) <= output_i(i)(j)(0);  -- wrap around
        end generate east_end;
        
        -- north-south routing

        north_end: if j=0 generate
          north_i(i)(j)(k) <= output_i(i)(ROWS-1)(k);  -- wrap around
          south_i(i)(j)(k) <= output_i(i)(j+1)(k);
        end generate north_end;

        north_south: if j>0 and j<(ROWS-1) generate
          north_i(i)(j)(k) <= output_i(i)(j-1)(k);
          south_i(i)(j)(k) <= output_i(i)(j+1)(k);
        end generate north_south;

        south_end: if j=(ROWS-1) generate
          north_i(i)(j)(k) <= output_i(i)(j-1)(k);
          south_i(i)(j)(k) <= output_i(i)(0)(k);  -- wrap around
        end generate south_end;

        -- up-down routing

        up_end: if i=0 generate
          up_i(i)(j)(k) <= output_i(LAYERS-1)(j)(k);  -- wrap around
          down_i(i)(j)(k) <= output_i(i+1)(j)(k);
        end generate up_end;

        up_down: if i>0 and i<(LAYERS-1) generate
          up_i(i)(j)(k) <= output_i(i-1)(j)(k);
          down_i(i)(j)(k) <= output_i(i+1)(j)(k);
        end generate up_down;

        down_end: if i=(LAYERS-1) generate
          up_i(i)(j)(k) <= output_i(i-1)(j)(k);
          down_i(i)(j)(k) <= output_i(0)(j)(k);  -- wrap around
        end generate down_end;

      end generate sblock_columns;
    end generate sblock_rows;
  end generate sblock_layers;
end sblock_matrix_arch;
