--------------------------------------------------------------------------------
-- Title       : Cell Fetcher
-- Project     : Cellular Automata Research Project
--------------------------------------------------------------------------------
-- Authors     : Per Thomas Lundal <perthomas@gmail.com>
-- Institution : Norwegian University of Science and Technology
--------------------------------------------------------------------------------
-- Description : Fetches cell neighborhoods from Cell BRAM
--------------------------------------------------------------------------------
-- Revisions   : Year  Author    Description
--             : 2015  Lundal    Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.functions.all;
use work.types.all;

entity cell_fetcher is
  generic (
    matrix_width     : positive := 8;
    matrix_height    : positive := 8;
    matrix_depth     : positive := 8;
    matrix_wrap      : boolean  := true;
    cell_type_bits   : positive := 8;
    cell_state_bits  : positive := 1
  );
  port (
    bram_address_z    : out std_logic_vector(bits(matrix_depth) - 1 downto 0);
    bram_address_y    : out std_logic_vector(bits(matrix_height) - 1 downto 0);
    bram_types_write  : out std_logic;
    bram_types_in     : in  std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_types_out    : out std_logic_vector(matrix_width*cell_type_bits - 1 downto 0);
    bram_states_write : out std_logic;
    bram_states_in    : in  std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);
    bram_states_out   : out std_logic_vector(matrix_width*cell_state_bits - 1 downto 0);

    row_neighborhood_types_slv  : out std_logic_vector(matrix_width * cell_type_bits * if_else(matrix_depth = 1, 5, 7) - 1 downto 0);
    row_neighborhood_states_slv : out std_logic_vector(matrix_width * cell_state_bits * if_else(matrix_depth = 1, 5, 7) - 1 downto 0);

    address_z : in std_logic_vector(bits(matrix_depth) - 1 downto 0);
    address_y : in std_logic_vector(bits(matrix_height) - 1 downto 0);

    run  : in std_logic;
    done : out std_logic;

    clock : in std_logic
  );
end cell_fetcher;

architecture rtl of cell_fetcher is

  constant neighborhood_size : positive := if_else(matrix_depth = 1, 5, 7);
  constant row_amount        : positive := if_else(matrix_depth = 1, 3, 5);

  type state_type is (
    FETCH_CENTER, FETCH_Y_NEGATIVE, FETCH_Y_POSITIVE, FETCH_Z_NEGATIVE, FETCH_Z_POSITIVE,
    WAIT_1, WAIT_2
  );

  signal address_state : state_type := FETCH_CENTER;
  signal fetch_state   : state_type := WAIT_1;

  type neighborhood_types_type  is array (neighborhood_size - 1 downto 0) of std_logic_vector(cell_type_bits - 1 downto 0);
  type neighborhood_states_type is array (neighborhood_size - 1 downto 0) of std_logic_vector(cell_state_bits - 1 downto 0);

  type row_neighborhood_types_type  is array (matrix_width - 1 downto 0) of neighborhood_types_type;
  type row_neighborhood_states_type is array (matrix_width - 1 downto 0) of neighborhood_states_type;

  signal row_neighborhood_types : row_neighborhood_types_type;
  signal row_neighborhood_states : row_neighborhood_states_type;

  type types_type  is array (matrix_width - 1 downto 0) of std_logic_vector(cell_type_bits - 1 downto 0);
  type states_type is array (matrix_width - 1 downto 0) of std_logic_vector(cell_state_bits - 1 downto 0);

  signal types_in  : types_type;
  signal states_in : states_type;

  type fetch_types_type  is array (row_amount - 1 downto 0) of types_type;
  type fetch_states_type is array (row_amount - 1 downto 0) of states_type;

  signal fetch_types  : fetch_types_type;
  signal fetch_states : fetch_states_type;

  signal address_z_negative : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal address_z_center   : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal address_z_positive : std_logic_vector(bits(matrix_depth) - 1 downto 0);
  signal address_y_negative : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal address_y_center   : std_logic_vector(bits(matrix_height) - 1 downto 0);
  signal address_y_positive : std_logic_vector(bits(matrix_height) - 1 downto 0);

  -- Internally used out-signals
  signal done_i : std_logic := '1';

begin

  array_to_slv : for i in 0 to matrix_width * neighborhood_size - 1 generate
    row_neighborhood_types_slv((i+1) * cell_type_bits - 1 downto (i) * cell_type_bits)
      <= row_neighborhood_types(i / neighborhood_size)(i mod neighborhood_size);
    row_neighborhood_states_slv((i+1) * cell_state_bits - 1 downto (i) * cell_state_bits)
      <= row_neighborhood_states(i / neighborhood_size)(i mod neighborhood_size);
  end generate;

  slv_to_array : for i in 0 to matrix_width - 1 generate
    types_in(i)  <= bram_types_in((i+1) * cell_type_bits - 1 downto i * cell_type_bits);
    states_in(i) <= bram_states_in((i+1) * cell_state_bits - 1 downto i * cell_state_bits);
  end generate;

  -- Adjacent address calculation
  address_z_negative <= std_logic_vector(to_unsigned(matrix_depth - 1, bits(matrix_depth)))
                     when unsigned(address_z_center) = 0
                     else std_logic_vector(unsigned(address_z_center) - 1);
  address_z_positive <= std_logic_vector(to_unsigned(0, bits(matrix_depth)))
                     when unsigned(address_z_center) = matrix_depth - 1
                     else std_logic_vector(unsigned(address_z_center) + 1);
  address_y_negative <= std_logic_vector(to_unsigned(matrix_height - 1, bits(matrix_height)))
                     when unsigned(address_y_center) = 0
                     else std_logic_vector(unsigned(address_y_center) - 1);
  address_y_positive <= std_logic_vector(to_unsigned(0, bits(matrix_height)))
                     when unsigned(address_y_center) = matrix_height - 1
                     else std_logic_vector(unsigned(address_y_center) + 1);

  -- State machine that sets buffer address
  process begin
    wait until rising_edge(clock);

    case (address_state) is

      when FETCH_CENTER =>
        -- Store center address
        address_z_center <= address_z;
        address_y_center <= address_y;
        bram_address_z <= address_z;
        bram_address_y <= address_y;
        if (run = '1') then
          address_state <= FETCH_Y_POSITIVE;
          done_i <= '0';
        end if;

      when FETCH_Y_POSITIVE =>
        bram_address_z <= address_z_center;
        bram_address_y <= address_y_positive;
        address_state <= FETCH_Y_NEGATIVE;

      when FETCH_Y_NEGATIVE =>
        bram_address_z <= address_z_center;
        bram_address_y <= address_y_negative;
        -- Skip Z axis if depth is 1
        if (matrix_depth > 1) then
          address_state <= FETCH_Z_POSITIVE;
        else
          address_state <= WAIT_1;
        end if;

      when FETCH_Z_POSITIVE =>
        bram_address_z <= address_z_positive;
        bram_address_y <= address_y_center;
        address_state <= FETCH_Z_NEGATIVE;

      when FETCH_Z_NEGATIVE =>
        bram_address_z <= address_z_negative;
        bram_address_y <= address_y_center;
        address_state <= WAIT_1;

      when WAIT_1 =>
        address_state <= WAIT_2;

      when WAIT_2 =>
        address_state <= FETCH_CENTER;
        done_i <= '1';

    end case;
  end process;

  -- State machine that reads data
  process begin
    wait until rising_edge(clock);

    case (fetch_state) is

      when WAIT_1 =>
        if (run = '1') then
          fetch_state <= WAIT_2;
        end if;

      when WAIT_2 =>
        fetch_state <= FETCH_CENTER;

      when FETCH_CENTER =>
        fetch_types(0)  <= types_in;
        fetch_states(0) <= states_in;
        fetch_state <= FETCH_Y_POSITIVE;

      when FETCH_Y_POSITIVE =>
        if (unsigned(address_y_center) = matrix_height - 1 and not matrix_wrap) then
          fetch_types(1)  <= (others => (others => '0'));
          fetch_states(1) <= (others => (others => '0'));
        else
          fetch_types(1)  <= types_in;
          fetch_states(1) <= states_in;
        end if;
        fetch_state <= FETCH_Y_NEGATIVE;

      when FETCH_Y_NEGATIVE =>
        if (unsigned(address_y_center) = 0 and not matrix_wrap) then
          fetch_types(2)  <= (others => (others => '0'));
          fetch_states(2) <= (others => (others => '0'));
        else
          fetch_types(2)  <= types_in;
          fetch_states(2) <= states_in;
        end if;
        -- Skip Z axis if depth is 1
        if (matrix_depth > 1) then
          fetch_state <= FETCH_Z_POSITIVE;
        else
          fetch_state <= WAIT_1;
        end if;

      when FETCH_Z_POSITIVE =>
        -- Outer if is required for synthesis
        if (matrix_depth > 1) then
          if (unsigned(address_z_center) = matrix_depth - 1 and not matrix_wrap) then
            fetch_types(3)  <= (others => (others => '0'));
            fetch_states(3) <= (others => (others => '0'));
          else
            fetch_types(3)  <= types_in;
            fetch_states(3) <= states_in;
          end if;
        end if;
        fetch_state <= FETCH_Z_NEGATIVE;

      when FETCH_Z_NEGATIVE =>
        -- Outer if is required for synthesis
        if (matrix_depth > 1) then
          if (unsigned(address_z_center) = 0 and not matrix_wrap) then
            fetch_types(4)  <= (others => (others => '0'));
            fetch_states(4) <= (others => (others => '0'));
          else
            fetch_types(4)  <= types_in;
            fetch_states(4) <= states_in;
          end if;
        end if;
        fetch_state <= WAIT_1;

    end case;
  end process;

  map_neighborhoods : for i in 0 to matrix_width - 1 generate

    -- Center
    row_neighborhood_types(i)(0)  <= fetch_types(0)(i);
    row_neighborhood_states(i)(0) <= fetch_states(0)(i);

    -- X
    x_positive_nowrap : if (i = matrix_width - 1 and not matrix_wrap) generate
      row_neighborhood_types(i)(1)  <= (others => '0');
      row_neighborhood_states(i)(1) <= (others => '0');
      row_neighborhood_types(i)(2)  <= fetch_types(0)(i-1);
      row_neighborhood_states(i)(2) <= fetch_states(0)(i-1);
    end generate;
    x_positive_wrap : if (i = matrix_width - 1 and matrix_wrap) generate
      row_neighborhood_types(i)(1)  <= fetch_types(0)(0);
      row_neighborhood_states(i)(1) <= fetch_states(0)(0);
      row_neighborhood_types(i)(2)  <= fetch_types(0)(i-1);
      row_neighborhood_states(i)(2) <= fetch_states(0)(i-1);
    end generate;
    x_center : if (i > 0 and i < matrix_width - 1) generate
      row_neighborhood_types(i)(1)  <= fetch_types(0)(i+1);
      row_neighborhood_states(i)(1) <= fetch_states(0)(i+1);
      row_neighborhood_types(i)(2)  <= fetch_types(0)(i-1);
      row_neighborhood_states(i)(2) <= fetch_states(0)(i-1);
    end generate;
    x_negative_wrap : if (i = 0 and matrix_wrap) generate
      row_neighborhood_types(i)(1)  <= fetch_types(0)(i+1);
      row_neighborhood_states(i)(1) <= fetch_states(0)(i+1);
      row_neighborhood_types(i)(2)  <= fetch_types(0)(matrix_width - 1);
      row_neighborhood_states(i)(2) <= fetch_states(0)(matrix_width - 1);
    end generate;
    x_negative_nowrap : if (i = 0 and not matrix_wrap) generate
      row_neighborhood_types(i)(1)  <= fetch_types(0)(i+1);
      row_neighborhood_states(i)(1) <= fetch_states(0)(i+1);
      row_neighborhood_types(i)(2)  <= (others => '0');
      row_neighborhood_states(i)(2) <= (others => '0');
    end generate;

    -- Y
    y : if (matrix_height > 1) generate
      row_neighborhood_types(i)(3)  <= fetch_types(1)(i);
      row_neighborhood_states(i)(3) <= fetch_states(1)(i);
      row_neighborhood_types(i)(4)  <= fetch_types(2)(i);
      row_neighborhood_states(i)(4) <= fetch_states(2)(i);
    end generate;

    -- Z
    z : if (matrix_depth > 1) generate
      row_neighborhood_types(i)(5)  <= fetch_types(3)(i);
      row_neighborhood_states(i)(5) <= fetch_states(3)(i);
      row_neighborhood_types(i)(6)  <= fetch_types(4)(i);
      row_neighborhood_states(i)(6) <= fetch_states(4)(i);
    end generate;

  end generate;

  -- Output tie-offs
  bram_types_out    <= (others => '0');
  bram_types_write  <= '0';
  bram_states_out   <= (others => '0');
  bram_states_write <= '0';

  -- Internally used out-signals
  done <= done_i;

end rtl;
