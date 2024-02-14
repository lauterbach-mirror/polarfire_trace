library ieee;
use ieee.std_logic_1164.all;

use work.axi4_fic1_from_mss_pkg;

entity axi_to_pti_wrapper is
	port (
		iRstN:      in  std_logic;
		iClk:       in  std_logic;

		oAwready:   out std_logic;
		iAwvalid:   in  std_logic;
		iAwid:      in  std_logic_vector( 8 downto 0);
		iAwaddr:    in  std_logic_vector(38 downto 0);
		iAwlen:     in  std_logic_vector( 7 downto 0);
		iAwburst:   in  std_logic_vector( 1 downto 0);
		iAwsize:    in  std_logic_vector( 1 downto 0);

		oWready:    out std_logic;
		iWvalid:    in  std_logic;
		iWlast:     in  std_logic;
		iWstrb:     in  std_logic_vector( 7 downto 0);
		iWdata:     in  std_logic_vector(63 downto 0);

		oArready:   out std_logic;
		iArvalid:   in  std_logic;
		iArid:      in  std_logic_vector( 8 downto 0);
		iAraddr:    in  std_logic_vector(38 downto 0);
		iArlen:     in  std_logic_vector( 7 downto 0);
		iArburst:   in  std_logic_vector( 1 downto 0);
		iArsize:    in  std_logic_vector( 1 downto 0);

		iBready:    in  std_logic;
		oBvalid:    out std_logic;
		oBid:       out std_logic_vector( 8 downto 0);
		oBresp:     out std_logic_vector( 1 downto 0);

		iRready:    in  std_logic;
		oRvalid:    out std_logic;
		oRid:       out std_logic_vector( 8 downto 0);
		oRresp:     out std_logic_vector( 1 downto 0);
		oRlast:     out std_logic;
		oRdata:     out std_logic_vector(63 downto 0);

		oTraceClk:  out std_logic;
		oTraceData: out std_logic_vector(15 downto 0)
	);
end entity;

architecture behavioral of axi_to_pti_wrapper is
	signal wRst: std_logic;

begin
	wRst <= not iRstN;

	sAxiToPti: entity work.axi_to_pti port map (
		iRst            => wRst,
		iClk            => iClk,

		iMosi.aw.valid  => iAwvalid,
		iMosi.aw.id     => iAwid,
		iMosi.aw.addr   => iAwaddr,
		iMosi.aw.len    => iAwlen,
		iMosi.aw.burst  => iAwburst,
		iMosi.aw.size   => iAwsize,
		iMosi.aw.lock   => '0',
		iMosi.aw.prot   => (others => '0'),
		iMosi.aw.cache  => (others => '0'),
		iMosi.aw.user   => (others => '0'),
		iMosi.aw.qos    => (others => '0'),
		iMosi.w.valid   => iWvalid,
		iMosi.w.last    => iWlast,
		iMosi.w.strb    => iWstrb,
		iMosi.w.data    => iWdata,
		iMosi.ar.valid  => iArvalid,
		iMosi.ar.id     => iArid,
		iMosi.ar.addr   => iAraddr,
		iMosi.ar.len    => iArlen,
		iMosi.ar.burst  => iArburst,
		iMosi.ar.size   => iArsize,
		iMosi.ar.lock   => '0',
		iMosi.ar.prot   => (others => '0'),
		iMosi.ar.cache  => (others => '0'),
		iMosi.ar.user   => (others => '0'),
		iMosi.ar.qos    => (others => '0'),
		iMosi.bready    => iBready,
		iMosi.rready    => iRready,

		oMiso.awready   => oAwready,
		oMiso.wready    => oWready,
		oMiso.arready   => oArready,
		oMiso.b.valid   => oBvalid,
		oMiso.b.id      => oBid,
		oMiso.b.resp    => oBresp,
		oMiso.r.valid   => oRvalid,
		oMiso.r.id      => oRid,
		oMiso.r.resp    => oRresp,
		oMiso.r.last    => oRlast,
		oMiso.r.data    => oRdata,

		oTraceClk       => oTraceClk,
		oTraceData      => oTraceData
	);
end architecture;
