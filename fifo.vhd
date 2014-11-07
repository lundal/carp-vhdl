library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
  generic (
    addr_bits : integer;
    data_bits : integer
  );
  port (
    clock      : in  std_logic;
    reset      : in  std_logic;
    data_in    : in  std_logic_vector(data_bits - 1 downto 0);
    data_out   : out std_logic_vector(data_bits - 1 downto 0);
    data_count : out std_logic_vector(addr_bits - 1 downto 0);
    data_read  : in  std_logic;
    data_write : in  std_logic
  );
end fifo;

architecture rtl of fifo is

  signal pointer_read  : std_logic_vector(addr_bits - 1 downto 0);
  signal pointer_write : std_logic_vector(addr_bits - 1 downto 0);

begin

  data_count <= std_logic_vector(unsigned(pointer_write) - unsigned(pointer_read));

  process begin
    wait until rising_edge(clock);
    if (reset = '1') then
      pointer_read  <= (others => '0');
      pointer_write <= (others => '0');
    else
      if (data_read = '1') then
        pointer_read <= std_logic_vector(unsigned(pointer_read) + 1);
      end if;
      if (data_write = '1') then
        pointer_write <= std_logic_vector(unsigned(pointer_write) + 1);
      end if;
    end if;
  end process;

  bram : entity work.bram_inferrer
  generic map (
    addr_bits => addr_bits,
    data_bits => data_bits
  )
  port map (
    clk_a    => clock,
    clk_b    => clock,

    addr_a   => pointer_read,
    data_i_a => (others => '0'),
    data_o_a => data_out,
    we_a     => '0',
    en_a     => '1',
    rst_a    => '0',

    addr_b   => pointer_write,
    data_i_b => data_in,
    data_o_b => open,
    we_b     => '1',
    en_b     => '1',
    rst_b    => '0'
  );

end rtl;

