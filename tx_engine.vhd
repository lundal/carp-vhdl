library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_engine is
  generic (
    reverse_payload_endian : boolean
  );
  port (
    -- General
    clock      : in  std_logic;
    reset      : in  std_logic;
    link_up    : in  std_logic;
    device_id  : in  std_logic_vector(15 downto 0);
    -- Tx
    tx_ready   : in  std_logic;
    tx_valid   : out std_logic;
    tx_last    : out std_logic;
    tx_data    : out std_logic_vector(31 downto 0);
    tx_user    : out std_logic_vector(3 downto 0);
    -- Request
    rq_ready   : out std_logic;
    rq_valid   : in  std_logic;
    rq_address : in  std_logic_vector(31 downto 0);
    rq_length  : in  std_logic_vector(9 downto 0);
    rq_id      : in  std_logic_vector(15 downto 0);
    rq_tag     : in  std_logic_vector(7 downto 0);
    -- FIFO
    fifo_data  : in  std_logic_vector(31 downto 0);
    fifo_count : in  std_logic_vector(31 downto 0);
    fifo_read  : out std_logic
  );
end tx_engine;

architecture rtl of tx_engine is

  constant TYPE_COMPLETE       : std_logic_vector(7 downto 0) := "01001010";

  type state_type is (
    IDLE,
    COMPLETE_DW0, COMPLETE_DW1, COMPLETE_DW2, COMPLETE_WORDS, COMPLETE_DATA
  );

  signal state                 : state_type := IDLE;
  
  -- DW 0
  signal tlp_type              : std_logic_vector(7 downto 0);
  signal tlp_traffic_class     : std_logic_vector(2 downto 0);
  signal tlp_digest            : std_logic;
  signal tlp_poisoned          : std_logic;
  signal tlp_attributes        : std_logic_vector(1 downto 0);
  signal tlp_length            : std_logic_vector(9 downto 0);
  
  -- DW 1
  signal tlp_completer_id      : std_logic_vector(15 downto 0);
  signal tlp_status            : std_logic_vector(2 downto 0);
  signal tlp_bcm               : std_logic;
  signal tlp_byte_count        : std_logic_vector(11 downto 0);

  -- DW 2
  signal tlp_requester_id      : std_logic_vector(15 downto 0);
  signal tlp_tag               : std_logic_vector(7 downto 0);
  signal tlp_address           : std_logic_vector(6 downto 0);

  -- Other
  signal tlp_remaining         : std_logic_vector(9 downto 0);

  -- Reverse Endian
  function reverse_endian(input : std_logic_vector) return std_logic_vector is
    variable output    : std_logic_vector(input'range);
    constant num_bytes : natural := input'length / 8;
  begin
    for i in 0 to num_bytes-1 loop
      for j in 7 downto 0 loop
        output(8*i + j) := input(8*(num_bytes-1-i) + j);
      end loop;
    end loop;
    return output;
  end function reverse_endian;

begin

  -- Constant values
  tlp_type          <= TYPE_COMPLETE;
  tlp_traffic_class <= (others => '0');
  tlp_digest        <= '0';
  tlp_poisoned      <= '0';
  tlp_attributes    <= (others => '0');
  tlp_completer_id  <= device_id;
  tlp_status        <= (others => '0');
  tlp_bcm           <= '0';
  tlp_byte_count    <= tlp_length & "00";

  tx_user(0) <= '0'; -- Unused for S6
  tx_user(1) <= '0'; -- Error forward packet
  tx_user(2) <= '0'; -- Stream packet
  tx_user(3) <= '0'; -- Source discontinue

  -- State dependant variables
  rq_ready <= '1' when state = IDLE else '0';

  process begin
    wait until rising_edge(clock);
    --
    case (state) is
      when IDLE =>
        tx_valid <= '0';
        tx_last  <= '0';
        --
        if (rq_valid = '1') then
          tlp_address      <= rq_address(6 downto 0);
          tlp_length       <= rq_length;
          tlp_requester_id <= rq_id;
          tlp_tag          <= rq_tag;
          tlp_remaining    <= rq_length;
          --
          state <= COMPLETE_DW0;
        end if;
        -- FIFO
        fifo_read <= '0';
        --
      when COMPLETE_DW0 =>
        if (tx_ready = '1') then
          tx_valid <= '1';
          tx_data  <= tlp_type & "0" & tlp_traffic_class & "0000"
                    & tlp_digest & tlp_poisoned & tlp_attributes & "00" & tlp_length;
          --
          state <= COMPLETE_DW1;
        end if;
        --
      when COMPLETE_DW1 =>
        if (tx_ready = '1') then
          tx_valid <= '1';
          tx_data  <= tlp_completer_id & tlp_status & tlp_bcm & tlp_byte_count;
          --
          state <= COMPLETE_DW2;
        end if;
        --
      when COMPLETE_DW2 =>
        if (tx_ready = '1') then
          tx_valid <= '1';
          tx_data  <= tlp_requester_id & tlp_tag & "0" & tlp_address;
          --
          state <= COMPLETE_WORDS;
        end if;
        --
      when COMPLETE_WORDS =>
        if (tx_ready = '1') then
          tx_valid <= '1';
          if (reverse_payload_endian) then
            tx_data <= reverse_endian(fifo_count);
          else
            tx_data <= fifo_count;
          end if;
          --
          tlp_remaining <= std_logic_vector(unsigned(tlp_remaining) - 1);
          if (tlp_remaining = "0000000001") then
            tx_last <= '1';
            state   <= IDLE;
          else
            state <= COMPLETE_DATA;
          end if;
        end if;
        --
      when COMPLETE_DATA =>
        if (tx_ready = '1') then
          tx_valid <= '1';
          if (reverse_payload_endian) then
            tx_data <= reverse_endian(fifo_data);
          else
            tx_data <= fifo_data;
          end if;
          --
          tlp_remaining <= std_logic_vector(unsigned(tlp_remaining) - 1);
          if (tlp_remaining = "0000000001") then
            tx_last <= '1';
            state   <= IDLE;
          end if;
        end if;
        -- FIFO
        if (tx_ready = '1') then
          fifo_read <= '1';
        else
          fifo_read <= '0';
        end if;
        --
    end case;
  end process;

end rtl;
