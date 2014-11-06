library ieee;
use ieee.std_logic_1164.all;

entity sp605_application is
  port (
    -- General
    clock     : in  std_logic;
    reset     : in  std_logic;
    link_up   : in  std_logic;
    device_id : in  std_logic_vector(15 downto 0);

    -- Tx
    tx_ready  : in  std_logic;
    tx_valid  : out std_logic;
    tx_last   : out std_logic;
    tx_data   : out std_logic_vector(31 downto 0);
    tx_keep   : out std_logic_vector(3 downto 0);
    tx_user   : out std_logic_vector(3 downto 0);

    -- Rx
    rx_ready  : out std_logic;
    rx_valid  : in  std_logic;
    rx_last   : in  std_logic;
    rx_data   : in  std_logic_vector(31 downto 0);
    rx_keep   : in  std_logic_vector(3 downto 0);
    rx_user   : in  std_logic_vector(21 downto 0);

    -- LEDs
    led_0     : out std_logic;
    led_1     : out std_logic;
    led_2     : out std_logic;
    led_3     : out std_logic
  );
end sp605_application;

architecture rtl of sp605_application is

  -- Request
  signal rq_ready   : std_logic;
  signal rq_valid   : std_logic;
  signal rq_address : std_logic_vector(31 downto 0);
  signal rq_length  : std_logic_vector(9 downto 0);
  signal rq_id      : std_logic_vector(15 downto 0);
  signal rq_tag     : std_logic_vector(7 downto 0);
  
  -- FIFO
  signal fifo_in           : std_logic_vector(31 downto 0);
  signal fifo_in_reversed  : std_logic_vector(31 downto 0);
  signal fifo_out          : std_logic_vector(31 downto 0);
  signal fifo_out_reversed : std_logic_vector(31 downto 0);
  signal fifo_read         : std_logic;
  signal fifo_write        : std_logic;

begin
  
  tx : entity work.tx_engine
  port map (
    -- General
    clock      => clock,
    reset      => reset,
    link_up    => link_up,
    device_id  => device_id,
    -- Tx
    tx_ready   => tx_ready,
    tx_valid   => tx_valid,
    tx_last    => tx_last,
    tx_data    => tx_data,
    tx_keep    => tx_keep,
    tx_user    => tx_user,
    -- Request
    rq_ready   => rq_ready,
    rq_valid   => rq_valid,
    rq_address => rq_address,
    rq_length  => rq_length,
    rq_id      => rq_id,
    rq_tag     => rq_tag,
    -- FIFO
    fifo_data  => fifo_out_reversed,
    fifo_read  => fifo_read
  );

  rx : entity work.rx_engine
  port map (
    -- General
    clock      => clock,
    reset      => reset,
    link_up    => link_up,
    device_id  => device_id,
    -- Rx
    rx_ready   => rx_ready,
    rx_valid   => rx_valid,
    rx_last    => rx_last,
    rx_data    => rx_data,
    rx_keep    => rx_keep,
    rx_user    => rx_user,
    -- Request
    rq_ready   => rq_ready,
    rq_valid   => rq_valid,
    rq_address => rq_address,
    rq_length  => rq_length,
    rq_id      => rq_id,
    rq_tag     => rq_tag,
    -- LEDs
    led_0      => led_0,
    led_1      => led_1,
    led_2      => led_2,
    led_3      => led_3,
    -- FIFO
    fifo_data  => fifo_in,
    fifo_write => fifo_write
  );
  
  fifo : entity work.fifo
  generic map (
    addr_bits => 10,
    data_bits => 32
  )
  port map (
    clock      => clock,
    reset      => reset,
    data_in    => fifo_in_reversed,
    data_out   => fifo_out,
    data_read  => fifo_read,
    data_write => fifo_write
  );
  
  fifo_in_reverser : entity work.endian_reverser
  port map (
    original => fifo_in,
    reversed => fifo_in_reversed
  );
  
  fifo_out_reverser : entity work.endian_reverser
  port map (
    original => fifo_out,
    reversed => fifo_out_reversed
  );

end rtl;
