-------------------------------------------------------------------------------
-- Title      : Sblock Matrix
-- Project    : Cellular Automata Research Platform
-------------------------------------------------------------------------------
-- File       : sblock_matrix.vhd
-- Author     : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2015-01-20
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: TODO
--            : For optimal shift_register usage, configuration_bits should not
--            : be higher than 2 for 2D and 8 for 3D.
--            : The configuration enable signals has one bit for each row.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author    Description
-- 2015-01-29  1.0      lundal	  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;

entity sblock_matrix is
  generic (
    matrix_width           : positive := 8;
    matrix_height          : positive := 8;
    matrix_depth           : positive := 8;
    matrix_wrap            : boolean := true;
    lut_configuration_bits : positive := 8  -- Must be a power of two
  );
  port (
    configuration_lut_slv    : in std_logic_vector(matrix_width * lut_configuration_bits - 1 downto 0);
    configuration_state_slv  : in std_logic_vector(matrix_width - 1 downto 0);
    configuration_enable_slv : in std_logic_vector(matrix_depth * matrix_height - 1 downto 0);

    states_slv : out std_logic_vector(matrix_depth * matrix_height * matrix_width - 1 downto 0);

    update : in  std_logic;

    clock : in  std_logic
  );
end sblock_matrix;

architecture rtl of sblock_matrix is

  constant neighborhood_size : positive := if_else(matrix_depth = 1, 5, 7);

  type bit_row    is array (matrix_width - 1 downto 0)  of std_logic;
  type bit_layer  is array (matrix_height - 1 downto 0) of bit_row;
  type bit_matrix is array (matrix_depth - 1 downto 0)  of bit_layer;

  type neighborhood_row    is array (matrix_width - 1 downto 0)  of std_logic_vector(neighborhood_size - 1 downto 1);
  type neighborhood_layer  is array (matrix_height - 1 downto 0) of neighborhood_row;
  type neighborhood_matrix is array (matrix_depth - 1 downto 0)  of neighborhood_layer;

  type configuration_row    is array (matrix_width - 1 downto 0)  of std_logic_vector(lut_configuration_bits - 1 downto 0);
  type configuration_layer  is array (matrix_height - 1 downto 0) of configuration_row;
  type configuration_matrix is array (matrix_depth - 1 downto 0)  of configuration_layer;

  signal states               : bit_matrix;
  signal neighbor_states      : neighborhood_matrix;
  signal configuration_lut    : configuration_matrix;
  signal configuration_enable : bit_matrix;
  signal configuration_state  : bit_matrix;

begin

  layers : for z in 0 to matrix_depth - 1 generate
    rows  : for y in 0 to matrix_height - 1 generate
      cells : for x in 0 to matrix_width - 1 generate

        sblock : entity work.sblock
        generic map (
          neighborhood_size      => neighborhood_size,
          lut_configuration_bits => lut_configuration_bits
        )
        port map (
          state                => states(z)(y)(x),
          neighbor_states      => neighbor_states(z)(y)(x),
          configuration_lut    => configuration_lut(z)(y)(x),
          configuration_state  => configuration_state(z)(y)(x),
          configuration_enable => configuration_enable(z)(y)(x),
          update               => update,
          clock                => clock
        );

        -- X neighbor mapping
        x_negative_nowrap : if (x = 0 and not matrix_wrap) generate
          neighbor_states(z)(y)(x)(1) <= states(z)(y)(x+1);
          neighbor_states(z)(y)(x)(2) <= '0';
        end generate;
        x_negative_wrap : if (x = 0 and matrix_wrap) generate
          neighbor_states(z)(y)(x)(1) <= states(z)(y)(x+1);
          neighbor_states(z)(y)(x)(2) <= states(z)(y)(matrix_width-1);
        end generate;
        x_center : if (x > 0 and x < matrix_width - 1) generate
          neighbor_states(z)(y)(x)(1) <= states(z)(y)(x+1);
          neighbor_states(z)(y)(x)(2) <= states(z)(y)(x-1);
        end generate;
        x_positive_wrap : if (x = matrix_width - 1 and matrix_wrap) generate
          neighbor_states(z)(y)(x)(1) <= states(z)(y)(0);
          neighbor_states(z)(y)(x)(2) <= states(z)(y)(x-1);
        end generate;
        x_positive_nowrap : if (x = matrix_width - 1 and not matrix_wrap) generate
          neighbor_states(z)(y)(x)(1) <= '0';
          neighbor_states(z)(y)(x)(2) <= states(z)(y)(x-1);
        end generate;

        -- Y neighbor mapping
        y_negative_nowrap : if (y = 0 and not matrix_wrap) generate
          neighbor_states(z)(y)(x)(3) <= states(z)(y+1)(x);
          neighbor_states(z)(y)(x)(4) <= '0';
        end generate;
        y_negative_wrap : if (y = 0 and matrix_wrap) generate
          neighbor_states(z)(y)(x)(3) <= states(z)(y+1)(x);
          neighbor_states(z)(y)(x)(4) <= states(z)(matrix_height-1)(x);
        end generate;
        y_center : if (y > 0 and y < matrix_height - 1) generate
          neighbor_states(z)(y)(x)(3) <= states(z)(y+1)(x);
          neighbor_states(z)(y)(x)(4) <= states(z)(y-1)(x);
        end generate;
        y_positive_wrap : if (y = matrix_height - 1 and matrix_wrap) generate
          neighbor_states(z)(y)(x)(3) <= states(z)(0)(x);
          neighbor_states(z)(y)(x)(4) <= states(z)(y-1)(x);
        end generate;
        y_positive_nowrap : if (y = matrix_height - 1 and not matrix_wrap) generate
          neighbor_states(z)(y)(x)(3) <= '0';
          neighbor_states(z)(y)(x)(4) <= states(z)(y-1)(x);
        end generate;

        -- Z neighbor mapping
        z_negative_nowrap : if (z = 0 and not matrix_wrap and matrix_depth > 1) generate
          neighbor_states(z)(y)(x)(5) <= states(z+1)(y)(x);
          neighbor_states(z)(y)(x)(6) <= '0';
        end generate;
        z_negative_wrap : if (z = 0 and matrix_wrap and matrix_depth > 1) generate
          neighbor_states(z)(y)(x)(5) <= states(z+1)(y)(x);
          neighbor_states(z)(y)(x)(6) <= states(matrix_depth-1)(y)(x);
        end generate;
        z_center : if (z > 0 and z < matrix_depth - 1 and matrix_depth > 1) generate
          neighbor_states(z)(y)(x)(5) <= states(z+1)(y)(x);
          neighbor_states(z)(y)(x)(6) <= states(z-1)(y)(x);
        end generate;
        z_positive_wrap : if (z = matrix_depth - 1 and matrix_wrap and matrix_depth > 1) generate
          neighbor_states(z)(y)(x)(5) <= states(0)(y)(x);
          neighbor_states(z)(y)(x)(6) <= states(z-1)(y)(x);
        end generate;
        z_positive_nowrap : if (z = matrix_depth - 1 and not matrix_wrap and matrix_depth > 1) generate
          neighbor_states(z)(y)(x)(5) <= '0';
          neighbor_states(z)(y)(x)(6) <= states(z-1)(y)(x);
        end generate;

        -- Configuration mappings
        configuration_lut(z)(y)(x)    <= configuration_lut_slv((x+1)*lut_configuration_bits - 1 downto x*lut_configuration_bits);
        configuration_state(z)(y)(x)  <= configuration_state_slv(x);
        configuration_enable(z)(y)(x) <= configuration_enable_slv(z*matrix_height + y);

        -- State SLV mapping
        states_slv(z*matrix_height*matrix_width + y*matrix_width + x) <= states(z)(y)(x);

      end generate;
    end generate;
  end generate;

end rtl;
