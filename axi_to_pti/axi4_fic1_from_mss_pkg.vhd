library ieee;
use ieee.std_logic_1164.all;

-- record package with signals for MPSoC M_AXI_HPMx_FPD slaves with port width 64
package axi4_fic1_from_mss_pkg is
	-- AXI4 has many many signals
	-- 5 Channels
	--    Address  Write
	--    Data     Write
	--    Response Write
	--    Address  Read
	--    Response Read
	-- MOSI: MasterOut-SlaveIn  (Master to Slave signals)

	subtype tAddr   is std_logic_vector(38 downto 0);
	subtype tId     is std_logic_vector( 8 downto 0);
	subtype tData   is std_logic_vector(63 downto 0);
	subtype tStrb   is std_logic_vector( 7 downto 0);
	subtype tUser   is std_logic_vector( 0 downto 0);

	-- these are not really specific to the parameters of the AXI bus, so they
	-- could be in a shared package...
	subtype tBurst  is std_logic_vector( 1 downto 0);
	subtype tCache  is std_logic_vector( 3 downto 0);
	subtype tLen    is std_logic_vector( 7 downto 0);
	subtype tProt   is std_logic_vector( 2 downto 0);
	subtype tQos    is std_logic_vector( 3 downto 0);
	subtype tResp   is std_logic_vector( 1 downto 0);
	subtype tSize   is std_logic_vector( 1 downto 0);

	constant cBurstFixed: tBurst := "00";
	constant cBurstIncr:  tBurst := "01";
	constant cBurstWrap:  tBurst := "10";

	type tMOSIaw is record
		valid:   std_logic;
		id:      tId;
		addr:    tAddr;

		len:     tLen;   -- Burst length in transfers
		burst:   tBurst; -- Burst TYPE
		size:    tSize;  -- bytes per transfer (<= 4 ?)

		-- misc... no idea... ignore I guess
		lock:    std_logic;
		prot:    tProt;
		cache:   tCache;
		user:    tUser;
		qos:     tQos;
	end record;
	constant cMOSIawRst: tMOSIaw := (
		valid    => '0',
		id       => (others => '0'),
		addr     => (others => '0'),

		burst    => (others => '0'),
		len      => (others => '0'),
		size     => (others => '0'),

		lock     => '0',
		prot     => (others => '0'),
		cache    => (others => '0'),
		user     => (others => '0'),
		qos      => (others => '0')
	);
	type tMOSIw is record
		valid:   std_logic;
		last:    std_logic;
		strb:    tStrb;
		data:    tData;
	end record;
	constant cMOSIwRst: tMOSIw := (
		valid    => '0',
		last     => '0',
		strb     => (others => '0'),
		data     => (others => '0')
	);
	type tMOSIar is record
		valid:   std_logic;
		id:      tId;
		addr:    tAddr;

		len:     tLen;   -- Burst length in transfers
		burst:   tBurst; -- Burst TYPE
		size:    tSize;  -- bytes per transfer (<= 4 ?)

		-- misc... no idea... ignore I guess
		lock:    std_logic;
		prot:    tProt;
		cache:   tCache;
		user:    tUser;
		qos:     tQos;
	end record;
	constant cMOSIarRst : tMOSIar := (
		valid    => '0',
		id       => (others => '0'),
		addr     => (others => '0'),

		burst    => (others => '0'),
		len      => (others => '0'),
		size     => (others => '0'),

		lock     => '0',
		prot     => (others => '0'),
		cache    => (others => '0'),
		user     => (others => '0'),
		qos      => (others => '0')
	);
	type tMOSI is record
		-- 5 AXI4 channels
		aw:      tMOSIaw;   -- address  write channel
		w:       tMOSIw;    -- data     write channel
		bready:  std_logic; -- response write channel
		ar:      tMOSIar;   -- address  read  channel
		rready:  std_logic; -- response read  channel
	end record;
	constant cMOSIRst: tMOSI := (
		aw       => cMOSIawRst,
		w        => cMOSIwRst,
		bready   => '0',
		ar       => cMOSIarRst,
		rready   => '0'
	);

	type tMISOb is record
		valid:   std_logic;
		id:      tId;
		resp:    tResp; -- resp status (OK, error etc)
	end record;
	type tMISOr is record
		valid:   std_logic;
		id:      tId;
		resp:    tResp;
		last:    std_logic;
		data:    tData;
	end record;
	type tMISO is record
		awready: std_logic; -- address  write
		wready:  std_logic; -- data     write
		b:       tMISOb;    -- response write
		arready: std_logic; -- address  read
		r:       tMISOr;    -- data     read
	end record;

	constant cMISObRst: tMISOb := (
		valid    => '0',
		id       => (others => '0'),
		resp     => (others => '0')
	);
	constant cMISOrRst: tMISOr := (
		valid    => '0',
		id       => (others => '0'),
		resp     => (others => '0'),
		last     => '0',
		data     => (others => '0')
	);
	constant cMISORst: tMISO := (
		awready  => '0',
		wready   => '0',
		b        => cMISObRst,
		arready  => '0',
		r        => cMISOrRst
	);

	subtype tMOSIawSlv is std_logic_vector(1 + tId'length + tAddr'length + tLen'length + tBurst'length + tSize'length + 1 + tProt'length + tCache'length + tUser'length + tQos'length - 1 downto 0);
	subtype tMOSIwSlv is std_logic_vector(1 + 1 + tStrb'length + tData'length - 1 downto 0);
	subtype tMOSIarSlv is std_logic_vector(1 + tId'length + tAddr'length + tLen'length + tBurst'length + tSize'length + 1 + tProt'length + tCache'length + tUser'length + tQos'length - 1 downto 0);
	subtype tMISObSlv is std_logic_vector(1 + tId'length + tResp'length - 1 downto 0);
	subtype tMISOrSlv is std_logic_vector(1 + tId'length + tResp'length + 1 + tData'length - 1 downto 0);

	function fMOSIawFromSlv(cIn: tMOSIawSlv) return tMOSIaw;
	function fMOSIwFromSlv (cIn: tMOSIwSlv ) return tMOSIw;
	function fMOSIarFromSlv(cIn: tMOSIarSlv) return tMOSIar;
	function fMISObFromSlv (cIn: tMISObSlv ) return tMISOb;
	function fMISOrFromSlv (cIn: tMISOrSlv ) return tMISOr;

	function fMOSIawToSlv(cIn: tMOSIaw) return tMOSIawSlv;
	function fMOSIwToSlv (cIn: tMOSIw ) return tMOSIwSlv;
	function fMOSIarToSlv(cIn: tMOSIar) return tMOSIarSlv;
	function fMISObToSlv (cIn: tMISOb ) return tMISObSlv;
	function fMISOrToSlv (cIn: tMISOr ) return tMISOrSlv;
end package;

package body axi4_fic1_from_mss_pkg is
	function fMOSIawFromSlv(cIn: tMOSIawSlv) return tMOSIaw is
		variable vI: natural := 0;
		variable vRet: tMOSIaw;

	begin
		vRet.valid   := cIn(vI);
		vI := vI + 1;
		vRet.id      := cIn(vI + tId'length - 1 downto vI);
		vI := vI + tId'length;
		vRet.addr    := cIn(vI + tAddr'length - 1 downto vI);
		vI := vI + tAddr'length;
		vRet.len     := cIn(vI + tLen'length - 1 downto vI);
		vI := vI + tLen'length;
		vRet.burst   := cIn(vI + tBurst'length - 1 downto vI);
		vI := vI + tBurst'length;
		vRet.size    := cIn(vI + tSize'length - 1 downto vI);
		vI := vI + tSize'length;
		vRet.lock    := cIn(vI);
		vI := vI + 1;
		vRet.prot    := cIn(vI + tProt'length - 1 downto vI);
		vI := vI + tProt'length;
		vRet.cache   := cIn(vI + tCache'length - 1 downto vI);
		vI := vI + tCache'length;
		vRet.user    := cIn(vI + tUser'length - 1 downto vI);
		vI := vI + tUser'length;
		vRet.qos     := cIn(vI + tQos'length - 1 downto vI);
		vI := vI + tQos'length;
		return vRet;
	end function;

	function fMOSIwFromSlv (cIn: tMOSIwSlv ) return tMOSIw is
		variable vI: natural := 0;
		variable vRet: tMOSIw;

	begin
		vRet.valid   := cIn(vI);
		vI := vI + 1;
		vRet.last    := cIn(vI);
		vI := vI + 1;
		vRet.strb    := cIn(vI + tStrb'length - 1 downto vI);
		vI := vI + tStrb'length;
		vRet.data    := cIn(vI + tData'length - 1 downto vI);
		vI := vI + tData'length;
		return vRet;
	end function;

	function fMOSIarFromSlv(cIn: tMOSIarSlv) return tMOSIar is
		variable vI: natural := 0;
		variable vRet: tMOSIar;

	begin
		vRet.valid   := cIn(vI);
		vI := vI + 1;
		vRet.id      := cIn(vI + tId'length - 1 downto vI);
		vI := vI + tId'length;
		vRet.addr    := cIn(vI + tAddr'length - 1 downto vI);
		vI := vI + tAddr'length;
		vRet.len     := cIn(vI + tLen'length - 1 downto vI);
		vI := vI + tLen'length;
		vRet.burst   := cIn(vI + tBurst'length - 1 downto vI);
		vI := vI + tBurst'length;
		vRet.size    := cIn(vI + tSize'length - 1 downto vI);
		vI := vI + tSize'length;
		vRet.lock    := cIn(vI);
		vI := vI + 1;
		vRet.prot    := cIn(vI + tProt'length - 1 downto vI);
		vI := vI + tProt'length;
		vRet.cache   := cIn(vI + tCache'length - 1 downto vI);
		vI := vI + tCache'length;
		vRet.user    := cIn(vI + tUser'length - 1 downto vI);
		vI := vI + tUser'length;
		vRet.qos     := cIn(vI + tQos'length - 1 downto vI);
		vI := vI + tQos'length;
		return vRet;
	end function;

	function fMISObFromSlv (cIn: tMISObSlv ) return tMISOb is
		variable vI: natural := 0;
		variable vRet: tMISOb;

	begin
		vRet.valid   := cIn(vI);
		vI := vI + 1;
		vRet.id      := cIn(vI + tId'length - 1 downto vI);
		vI := vI + tId'length;
		vRet.resp    := cIn(vI + tResp'length - 1 downto vI);
		vI := vI + tResp'length;
		return vRet;
	end function;

	function fMISOrFromSlv (cIn: tMISOrSlv ) return tMISOr is
		variable vI: natural := 0;
		variable vRet: tMISOr;

	begin
		vRet.valid   := cIn(vI);
		vI := vI + 1;
		vRet.id      := cIn(vI + tId'length - 1 downto vI);
		vI := vI + tId'length;
		vRet.resp    := cIn(vI + tResp'length - 1 downto vI);
		vI := vI + tResp'length;
		vRet.last    := cIn(vI);
		vI := vI + 1;
		vRet.data    := cIn(vI + tData'length - 1 downto vI);
		vI := vI + tData'length;
		return vRet;
	end function;

	function fMOSIawToSlv(cIn: tMOSIaw) return tMOSIawSlv is
		variable vI: natural := 0;
		variable vRet: tMOSIawSlv;

	begin
		vRet(vI) := cIn.valid;
		vI := vI + 1;
		vRet(vI + tId'length - 1 downto vI) := cIn.id;
		vI := vI + tId'length;
		vRet(vI + tAddr'length - 1 downto vI) := cIn.addr;
		vI := vI + tAddr'length;
		vRet(vI + tLen'length - 1 downto vI) := cIn.len;
		vI := vI + tLen'length;
		vRet(vI + tBurst'length - 1 downto vI) := cIn.burst;
		vI := vI + tBurst'length;
		vRet(vI + tSize'length - 1 downto vI) := cIn.size;
		vI := vI + tSize'length;
		vRet(vI) := cIn.lock;
		vI := vI + 1;
		vRet(vI + tProt'length - 1 downto vI) := cIn.prot;
		vI := vI + tProt'length;
		vRet(vI + tCache'length - 1 downto vI) := cIn.cache;
		vI := vI + tCache'length;
		vRet(vI + tUser'length - 1 downto vI) := cIn.user;
		vI := vI + tUser'length;
		vRet(vI + tQos'length - 1 downto vI) := cIn.qos;
		vI := vI + tQos'length;
		return vRet;
	end function;

	function fMOSIwToSlv (cIn: tMOSIw ) return tMOSIwSlv is
		variable vI: natural := 0;
		variable vRet: tMOSIwSlv;

	begin
		vRet(vI) := cIn.valid;
		vI := vI + 1;
		vRet(vI) := cIn.last;
		vI := vI + 1;
		vRet(vI + tStrb'length - 1 downto vI) := cIn.strb;
		vI := vI + tStrb'length;
		vRet(vI + tData'length - 1 downto vI) := cIn.data;
		vI := vI + tData'length;
		return vRet;
	end function;

	function fMOSIarToSlv(cIn: tMOSIar) return tMOSIarSlv is
		variable vI: natural := 0;
		variable vRet: tMOSIarSlv;

	begin
		vRet(vI) := cIn.valid;
		vI := vI + 1;
		vRet(vI + tId'length - 1 downto vI) := cIn.id;
		vI := vI + tId'length;
		vRet(vI + tAddr'length - 1 downto vI) := cIn.addr;
		vI := vI + tAddr'length;
		vRet(vI + tLen'length - 1 downto vI) := cIn.len;
		vI := vI + tLen'length;
		vRet(vI + tBurst'length - 1 downto vI) := cIn.burst;
		vI := vI + tBurst'length;
		vRet(vI + tSize'length - 1 downto vI) := cIn.size;
		vI := vI + tSize'length;
		vRet(vI) := cIn.lock;
		vI := vI + 1;
		vRet(vI + tProt'length - 1 downto vI) := cIn.prot;
		vI := vI + tProt'length;
		vRet(vI + tCache'length - 1 downto vI) := cIn.cache;
		vI := vI + tCache'length;
		vRet(vI + tUser'length - 1 downto vI) := cIn.user;
		vI := vI + tUser'length;
		vRet(vI + tQos'length - 1 downto vI) := cIn.qos;
		vI := vI + tQos'length;
		return vRet;
	end function;

	function fMISObToSlv (cIn: tMISOb ) return tMISObSlv is
		variable vI: natural := 0;
		variable vRet: tMISObSlv;

	begin
		vRet(vI) := cIn.valid;
		vI := vI + 1;
		vRet(vI + tId'length - 1 downto vI) := cIn.id;
		vI := vI + tId'length;
		vRet(vI + tResp'length - 1 downto vI) := cIn.resp;
		vI := vI + tResp'length;
		return vRet;
	end function;

	function fMISOrToSlv (cIn: tMISOr ) return tMISOrSlv is
		variable vI: natural := 0;
		variable vRet: tMISOrSlv;

	begin
		vRet(vI) := cIn.valid;
		vI := vI + 1;
		vRet(vI + tId'length - 1 downto vI) := cIn.id;
		vI := vI + tId'length;
		vRet(vI + tResp'length - 1 downto vI) := cIn.resp;
		vI := vI + tResp'length;
		vRet(vI) := cIn.last;
		vI := vI + 1;
		vRet(vI + tData'length - 1 downto vI) := cIn.data;
		vI := vI + tData'length;
		return vRet;
	end function;
end package body;
