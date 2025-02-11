library ieee;
use ieee.std_logic_1164.all;

use work.axi4_fic1_from_mss_pkg;

entity axi_to_aurora_2lane is
	port (
		iRstN:               in  std_logic;
		iClkAxi:             in  std_logic;

		AWREADY:             out std_logic;
		AWVALID:             in  std_logic;
		AWID:                in  std_logic_vector( 8 downto 0);
		AWADDR:              in  std_logic_vector(38 downto 0);
		AWLEN:               in  std_logic_vector( 7 downto 0);
		AWBURST:             in  std_logic_vector( 1 downto 0);
		AWSIZE:              in  std_logic_vector( 1 downto 0);

		WREADY:              out std_logic;
		WVALID:              in  std_logic;
		WLAST:               in  std_logic;
		WSTRB:               in  std_logic_vector( 7 downto 0);
		WDATA:               in  std_logic_vector(63 downto 0);

		ARREADY:             out std_logic;
		ARVALID:             in  std_logic;
		ARID:                in  std_logic_vector( 8 downto 0);
		ARADDR:              in  std_logic_vector(38 downto 0);
		ARLEN:               in  std_logic_vector( 7 downto 0);
		ARBURST:             in  std_logic_vector( 1 downto 0);
		ARSIZE:              in  std_logic_vector( 1 downto 0);

		BREADY:              in  std_logic;
		BVALID:              out std_logic;
		BID:                 out std_logic_vector( 8 downto 0);
		BRESP:               out std_logic_vector( 1 downto 0);

		RREADY:              in  std_logic;
		RVALID:              out std_logic;
		RID:                 out std_logic_vector( 8 downto 0);
		RRESP:               out std_logic_vector( 1 downto 0);
		RLAST:               out std_logic;
		RDATA:               out std_logic_vector(63 downto 0);

		PLL_LOCK:            in  std_logic;
		LANE0_TX_CLK_R:      in  std_logic;
		LANE0_TX_CLK_STABLE: in  std_logic;
		LANE1_TX_CLK_R:      in  std_logic;
		LANE1_TX_CLK_STABLE: in  std_logic;

		LANE0_PCS_ARST_N:    out std_logic;
		LANE0_PMA_ARST_N:    out std_logic;
		LANE0_TX_DATA:       out std_logic_vector(15 downto 0);
		LANE0_8B10B_TX_K:    out std_logic_vector( 1 downto 0);
		LANE0_TX_DISPFNC:    out std_logic_vector( 3 downto 0);
		LANE1_PCS_ARST_N:    out std_logic;
		LANE1_PMA_ARST_N:    out std_logic;
		LANE1_TX_DATA:       out std_logic_vector(15 downto 0);
		LANE1_8B10B_TX_K:    out std_logic_vector( 1 downto 0);
		LANE1_TX_DISPFNC:    out std_logic_vector( 3 downto 0)
	);
end entity;

architecture behavioral of axi_to_aurora_2lane is
	signal wRst: std_logic;
	signal wPhyRstN: std_logic;

begin
	wRst <= not iRstN;

	sAxiToHsstp: entity work.axi_to_aurora_impl generic map (
		gLanes            => 2
	) port map (
		iRst              => wRst,
		iClkAxi           => iClkAxi,

		iMosi.aw.valid    => AWVALID,
		iMosi.aw.id       => AWID,
		iMosi.aw.addr     => AWADDR,
		iMosi.aw.len      => AWLEN,
		iMosi.aw.burst    => AWBURST,
		iMosi.aw.size     => AWSIZE,
		iMosi.aw.lock     => '0',
		iMosi.aw.prot     => (others => '0'),
		iMosi.aw.cache    => (others => '0'),
		iMosi.aw.user     => (others => '0'),
		iMosi.aw.qos      => (others => '0'),
		iMosi.w.valid     => WVALID,
		iMosi.w.last      => WLAST,
		iMosi.w.strb      => WSTRB,
		iMosi.w.data      => WDATA,
		iMosi.ar.valid    => ARVALID,
		iMosi.ar.id       => ARID,
		iMosi.ar.addr     => ARADDR,
		iMosi.ar.len      => ARLEN,
		iMosi.ar.burst    => ARBURST,
		iMosi.ar.size     => ARSIZE,
		iMosi.ar.lock     => '0',
		iMosi.ar.prot     => (others => '0'),
		iMosi.ar.cache    => (others => '0'),
		iMosi.ar.user     => (others => '0'),
		iMosi.ar.qos      => (others => '0'),
		iMosi.bready      => BREADY,
		iMosi.rready      => RREADY,

		oMiso.awready     => AWREADY,
		oMiso.wready      => WREADY,
		oMiso.arready     => ARREADY,
		oMiso.b.valid     => BVALID,
		oMiso.b.id        => BID,
		oMiso.b.resp      => BRESP,
		oMiso.r.valid     => RVALID,
		oMiso.r.id        => RID,
		oMiso.r.resp      => RRESP,
		oMiso.r.last      => RLAST,
		oMiso.r.data      => RDATA,

		iClkUser(0)       => LANE0_TX_CLK_R,
		iClkUser(1)       => LANE1_TX_CLK_R,
		iClkUserStable(0) => LANE0_TX_CLK_STABLE,
		iClkUserStable(1) => LANE1_TX_CLK_STABLE,
		iPllLock          => PLL_LOCK,

		oPhyRstN              => wPhyRstN,
		oTxData(15 downto  0) => LANE0_TX_DATA,
		oTxData(31 downto 16) => LANE1_TX_DATA,
		oTxK   ( 1 downto  0) => LANE0_8B10B_TX_K,
		oTxK   ( 3 downto  2) => LANE1_8B10B_TX_K
	);

	-- disparity control, two bits per symbol, "00" seems to be fine for normal
	-- purposes
	LANE0_TX_DISPFNC <= (others => '0');
	LANE1_TX_DISPFNC <= (others => '0');

	LANE0_PCS_ARST_N <= wPhyRstN;
	LANE0_PMA_ARST_N <= wPhyRstN;
	LANE1_PCS_ARST_N <= wPhyRstN;
	LANE1_PMA_ARST_N <= wPhyRstN;
end architecture;
