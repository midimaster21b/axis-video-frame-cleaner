library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_cleaner is
  generic (
    COUNTER_WIDTH_G : integer := 32;
    NUM_ROWS_G      : integer := 480;
    NUM_COLS_G      : integer := 640
    );
  port (
    -- Control signals
    clk_in          : in  std_logic;
    rst_in          : in  std_logic;
    trig_in         : in  std_logic;
    row_end_tlast_in : in std_logic;

    -- Registers
    frame_count_out : out std_logic_vector(31 downto 0);
    line_count_out  : out std_logic_vector(31 downto 0);
    fc_state_out    : out std_logic_vector(31 downto 0);

    -- Video signals [inputs]
    data_in         : in  std_logic_vector(31 downto 0);
    tkeep_in        : in  std_logic_vector( 3 downto 0);
    valid_in        : in  std_logic;
    tlast_in        : in  std_logic;
    frame_start_in  : in  std_logic;

    -- Video signals [outputs]
    data_out        : out std_logic_vector(31 downto 0);
    tkeep_out       : out std_logic_vector( 3 downto 0);
    valid_out       : out std_logic;
    tlast_out       : out std_logic;
    frame_start_out : out std_logic
    );
end frame_cleaner;

architecture rtl of frame_cleaner is

  signal data_r           : std_logic_vector(31 downto 0);
  signal keep_r           : std_logic_vector( 3 downto 0);
  signal valid_r          : std_logic;
  signal line_end_r       : std_logic;
  signal start_of_frame_r : std_logic;

  signal row_r            : unsigned(COUNTER_WIDTH_G-1 downto 0) := (others => '0');
  signal col_r            : unsigned(COUNTER_WIDTH_G-1 downto 0) := (others => '0');

  signal data_out_r           : std_logic_vector(31 downto 0);
  signal keep_out_r           : std_logic_vector( 3 downto 0);
  signal valid_out_r          : std_logic;
  signal start_of_frame_out_r : std_logic;
  signal frame_end_out_r      : std_logic;

  type GATE_STATE_T is (IDLE_STATE, WAIT_STATE, TX_STATE);
  signal curr_state_r : gate_state_t := IDLE_STATE;
  signal next_state_s : gate_state_t := IDLE_STATE;

  -- Registers
  signal frame_count_r : unsigned(31 downto 0) := (others => '0');
  signal line_count_r  : unsigned(31 downto 0) := (others => '0');
  signal fc_state_r    : std_logic_vector(31 downto 0) := (others => '0');

begin

  -- Output registers
  frame_count_out <= std_logic_vector(frame_count_r);
  line_count_out  <= std_logic_vector(line_count_r);
  fc_state_out    <= fc_state_r;


  -- Advance the state to the next state
  adv_state: process(clk_in)
  begin
    if rising_edge(clk_in) then
      -- If in reset
      if rst_in = '0' then
        curr_state_r <= IDLE_STATE;

      else
        curr_state_r <= next_state_s;

      end if;
    end if;
  end process;


  -- Calculate the next state
  next_state: process(rst_in, curr_state_r, trig_in, start_of_frame_r, valid_r, row_r, col_r)
  begin
    if(rst_in = '0') then
      next_state_s <= IDLE_STATE;

    else
      case curr_state_r is
        when IDLE_STATE =>
          if trig_in = '1' then
            next_state_s <= WAIT_STATE;

          else
            next_state_s <= IDLE_STATE;

          end if;


        when WAIT_STATE =>
          if start_of_frame_r = '1' then
            next_state_s <= TX_STATE;

          else
            next_state_s <= WAIT_STATE;

          end if;


        when TX_STATE =>
          if valid_r = '1' and row_r = NUM_ROWS_G-1 and col_r = NUM_COLS_G-1 then
            next_state_s <= IDLE_STATE;

          else
            next_state_s <= TX_STATE;

          end if;


        when others =>
          next_state_s <= WAIT_STATE;


      end case;
    end if;
  end process;


  -- Shift data in
  shift_proc: process(clk_in)
  begin
    if rising_edge(clk_in) then
      -- If in reset
      if rst_in = '0' then
        data_r           <= (others => '0');
        keep_r           <= (others => '0');
        valid_r          <= '0';
        line_end_r       <= '0';
        start_of_frame_r <= '0';


      -- Normal operation
      else
        data_r           <= data_in;
        keep_r           <= tkeep_in;
        valid_r          <= valid_in;
        line_end_r       <= tlast_in;
        start_of_frame_r <= frame_start_in;

      end if;
    end if;
  end process;


  -- Output proc
  out_proc: process(clk_in)
  begin
    if rising_edge(clk_in) then
      -- If in reset
      if rst_in = '0' then
        data_out        <= (others => '0');
        tkeep_out       <= (others => '0');
        valid_out       <= '0';
        frame_start_out <= '0';
        tlast_out       <= '0';

      -- Normal operation
      else
        -- If valid image pixel
        if (curr_state_r = TX_STATE or (row_r = 0 and col_r = 0 and curr_state_r = WAIT_STATE)) and valid_r = '1' and row_r <= NUM_ROWS_G-1 and col_r <= NUM_COLS_G-1 then
            data_out        <= data_r;
            tkeep_out       <= keep_r;
            valid_out       <= valid_r;
            frame_start_out <= start_of_frame_r;


            if ((row_end_tlast_in = '1' and row_r <= NUM_ROWS_G-1) or
                (row_end_tlast_in = '0' and row_r  = NUM_ROWS_G-1))
              and col_r = NUM_COLS_G-1 then
              tlast_out   <= '1';

            else
              tlast_out   <= '0';

            end if;


        -- Not valid beat
        else
          data_out        <= (others => '0');
          tkeep_out       <= (others => '0');
          valid_out       <= '0';
          frame_start_out <= '0';
          tlast_out       <= '0';

        end if;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Count process
  -----------------------------------------------------------------------------
  count_proc: process(clk_in)
  begin
    if rising_edge(clk_in) then
      -- If in reset
      if rst_in = '0' then
        row_r <= (others => '0');
        col_r <= (others => '0');


      -- Normal operation
      else
        -- If valid image pixel
        if valid_in = '1' and frame_start_in = '1' then
            row_r <= (others => '0');
            col_r <= (others => '0');

        -- If valid end of line found
        elsif line_end_r = '1' and valid_r = '1' then
          row_r <= row_r + 1;
          col_r <= (others => '0'); -- Start column count over at zero

        -- Else normal operation
        elsif valid_r = '1' then
          col_r <= col_r + 1;
          
        end if;

      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------
  reg_proc: process(clk_in)
  begin
    if rising_edge(clk_in) then
      -- If in reset
      if rst_in = '0' then
        frame_count_r <= (others => '0');
        line_count_r  <= (others => '0');

      -- Else not in reset
      else
        -- If valid end of line
        if valid_in = '1' and tlast_in = '1' then
          line_count_r <= line_count_r + 1;
        end if;

        -- If valid start of frame
        if valid_in = '1' and frame_start_in = '1' then
          frame_count_r <= frame_count_r + 1;
        end if;

        -- Current state
        case curr_state_r is
          when IDLE_STATE =>
            fc_state_r <= x"0000_0001";

          when WAIT_STATE =>
            fc_state_r <= x"0000_0002";

          when TX_STATE =>
            fc_state_r <= x"0000_0003";

          when others =>
            fc_state_r <= x"0000_0004";

        end case;

      end if;
    end if;
  end process;
end rtl;
