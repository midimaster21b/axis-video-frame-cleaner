library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_cleaner_v1_0 is
  generic (
    AXI_CTRL_PORT_G             : boolean       := True;

    -- Parameters of Axi Slave Bus Interface S_AXI_CTRL
    C_S_AXI_CTRL_DATA_WIDTH	: integer	:= 32;
    C_S_AXI_CTRL_ADDR_WIDTH	: integer	:= 6;

    -- Parameters of Axi Slave Bus Interface S_AXIS_VIDEO
    C_S_AXIS_VIDEO_TDATA_WIDTH	: integer	:= 32;

    -- Parameters of Axi Master Bus Interface M_AXIS_VIDEO
    C_M_AXIS_VIDEO_TDATA_WIDTH	: integer	:= 32;
    C_M_AXIS_VIDEO_START_COUNT	: integer	:= 32
    );
  port (
    trig_in              : in  std_logic;

    -- Ports of Axi Slave Bus Interface S_AXI_CTRL
    s_axi_ctrl_aclk      : in  std_logic;
    s_axi_ctrl_aresetn   : in  std_logic;
    s_axi_ctrl_awaddr    : in  std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    s_axi_ctrl_awprot    : in  std_logic_vector(2 downto 0);
    s_axi_ctrl_awvalid   : in  std_logic;
    s_axi_ctrl_awready   : out std_logic;
    s_axi_ctrl_wdata     : in  std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    s_axi_ctrl_wstrb     : in  std_logic_vector((C_S_AXI_CTRL_DATA_WIDTH/8)-1 downto 0);
    s_axi_ctrl_wvalid    : in  std_logic;
    s_axi_ctrl_wready    : out std_logic;
    s_axi_ctrl_bresp     : out std_logic_vector(1 downto 0);
    s_axi_ctrl_bvalid    : out std_logic;
    s_axi_ctrl_bready    : in  std_logic;
    s_axi_ctrl_araddr    : in  std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    s_axi_ctrl_arprot    : in  std_logic_vector(2 downto 0);
    s_axi_ctrl_arvalid   : in  std_logic;
    s_axi_ctrl_arready   : out std_logic;
    s_axi_ctrl_rdata     : out std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    s_axi_ctrl_rresp     : out std_logic_vector(1 downto 0);
    s_axi_ctrl_rvalid    : out std_logic;
    s_axi_ctrl_rready    : in  std_logic;

    -- Ports of Axi Slave Bus Interface S_AXIS_VIDEO
    s_axis_video_aclk    : in  std_logic;
    s_axis_video_aresetn : in  std_logic;
    s_axis_video_tready  : out std_logic;
    s_axis_video_tdata   : in  std_logic_vector(C_S_AXIS_VIDEO_TDATA_WIDTH-1 downto 0);
    s_axis_video_tstrb   : in  std_logic_vector((C_S_AXIS_VIDEO_TDATA_WIDTH/8)-1 downto 0);
    s_axis_video_tlast   : in  std_logic;
    s_axis_video_tvalid  : in  std_logic;
    s_axis_video_tuser   : in  std_logic_vector(0 downto 0);

    -- Ports of Axi Master Bus Interface M_AXIS_VIDEO
    m_axis_video_aclk    : in  std_logic;
    m_axis_video_aresetn : in  std_logic;
    m_axis_video_tvalid  : out std_logic;
    m_axis_video_tdata   : out std_logic_vector(C_M_AXIS_VIDEO_TDATA_WIDTH-1 downto 0);
    m_axis_video_tstrb   : out std_logic_vector((C_M_AXIS_VIDEO_TDATA_WIDTH/8)-1 downto 0);
    m_axis_video_tlast   : out std_logic;
    m_axis_video_tready  : in  std_logic;
    m_axis_video_tuser   : out std_logic_vector(0 downto 0)
    );
end frame_cleaner_v1_0;

architecture arch_imp of frame_cleaner_v1_0 is

  signal trig_ctrl_s : std_logic := '0';
  signal trig_s      : std_logic := '0';

  -- Register connections
  signal fc_state_s    : std_logic_vector(31 downto 0);
  signal frame_count_s : std_logic_vector(31 downto 0);
  signal line_count_s  : std_logic_vector(31 downto 0);
  signal tlast_reg_s   : std_logic;


  -- component declaration
  component frame_cleaner_v1_0_S_AXI_CTRL is
    generic (
      C_S_AXI_DATA_WIDTH : integer := 32;
      C_S_AXI_ADDR_WIDTH : integer := 6
      );
    port (
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID : in  std_logic;
      S_AXI_AWREADY : out std_logic;
      S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
      S_AXI_WVALID  : in  std_logic;
      S_AXI_WREADY  : out std_logic;
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic;
      S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic;

      -- Registers
      frame_count_in : in std_logic_vector(31 downto 0);
      line_count_in  : in std_logic_vector(31 downto 0);
      fc_state_in    : in std_logic_vector(31 downto 0);

      -- control_reg_out : out std_logic_vector(31 downto 0);

      tlast_reg_out : out std_logic;

      -- Trigger interface
      trig_out      : out std_logic
      );
  end component frame_cleaner_v1_0_S_AXI_CTRL;


  component frame_cleaner is
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
  end component;

begin

  trig_s <= trig_ctrl_s or trig_in;

  axi_ctrl_u: if AXI_CTRL_PORT_G = True generate
    -- Instantiation of Axi Bus Interface S_AXI_CTRL
    frame_cleaner_v1_0_S_AXI_CTRL_inst : frame_cleaner_v1_0_S_AXI_CTRL
      generic map (
        C_S_AXI_DATA_WIDTH	=> C_S_AXI_CTRL_DATA_WIDTH,
        C_S_AXI_ADDR_WIDTH	=> C_S_AXI_CTRL_ADDR_WIDTH
        )
      port map (
        S_AXI_ACLK	=> s_axi_ctrl_aclk,
        S_AXI_ARESETN	=> s_axi_ctrl_aresetn,
        S_AXI_AWADDR	=> s_axi_ctrl_awaddr,
        S_AXI_AWPROT	=> s_axi_ctrl_awprot,
        S_AXI_AWVALID	=> s_axi_ctrl_awvalid,
        S_AXI_AWREADY	=> s_axi_ctrl_awready,
        S_AXI_WDATA	=> s_axi_ctrl_wdata,
        S_AXI_WSTRB	=> s_axi_ctrl_wstrb,
        S_AXI_WVALID	=> s_axi_ctrl_wvalid,
        S_AXI_WREADY	=> s_axi_ctrl_wready,
        S_AXI_BRESP	=> s_axi_ctrl_bresp,
        S_AXI_BVALID	=> s_axi_ctrl_bvalid,
        S_AXI_BREADY	=> s_axi_ctrl_bready,
        S_AXI_ARADDR	=> s_axi_ctrl_araddr,
        S_AXI_ARPROT	=> s_axi_ctrl_arprot,
        S_AXI_ARVALID	=> s_axi_ctrl_arvalid,
        S_AXI_ARREADY	=> s_axi_ctrl_arready,
        S_AXI_RDATA	=> s_axi_ctrl_rdata,
        S_AXI_RRESP	=> s_axi_ctrl_rresp,
        S_AXI_RVALID	=> s_axi_ctrl_rvalid,
        S_AXI_RREADY	=> s_axi_ctrl_rready,

        -- Registers
        frame_count_in  => frame_count_s,
        line_count_in   => line_count_s,
        fc_state_in     => fc_state_s,

        tlast_reg_out   => tlast_reg_s,

        -- Trigger interface
        trig_out        => trig_ctrl_s
        );
  end generate axi_ctrl_u;


  fc: frame_cleaner
    generic map (
      COUNTER_WIDTH_G => 32,
      NUM_ROWS_G      => 480,
      NUM_COLS_G      => 640
      )
    port map (
      -- Control signals
      clk_in          => s_axis_video_aclk,
      rst_in          => s_axis_video_aresetn,
      trig_in         => trig_s,
      -- row_end_tlast_in => control_s(0),
      row_end_tlast_in => tlast_reg_s,

      -- Registers
      frame_count_out => frame_count_s,
      line_count_out  => line_count_s,
      fc_state_out    => fc_state_s,

      -- Video signals [inputs]
      data_in         => s_axis_video_tdata,
      tkeep_in        => s_axis_video_tstrb,
      valid_in        => s_axis_video_tvalid,
      tlast_in        => s_axis_video_tlast,
      frame_start_in  => s_axis_video_tuser(0),

      -- Video signals [outputs]
      data_out        => m_axis_video_tdata,
      tkeep_out       => m_axis_video_tstrb,
      valid_out       => m_axis_video_tvalid,
      tlast_out       => m_axis_video_tlast,
      frame_start_out => m_axis_video_tuser(0)
      );

end arch_imp;
