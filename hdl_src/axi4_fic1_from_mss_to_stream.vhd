library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4_fic1_from_mss_pkg;

entity axi4_fic1_from_mss_to_stream is
	port (
		iRst:                 in  std_logic;
		iClk:                 in  std_logic;

		iMosi:                in  axi4_fic1_from_mss_pkg.tMOSI;
		oMiso:                out axi4_fic1_from_mss_pkg.tMISO;

		iStreamReady:         in  std_logic;
		oStreamValid:         out std_logic;
		oStreamAligned:       out std_logic;
		oStreamStrb:          out std_logic_vector( 7 downto 0);
		oStreamData:          out std_logic_vector(63 downto 0)
	);
end entity;

architecture behavioral of axi4_fic1_from_mss_to_stream is
	-- we want to detect writes that are aligned to 1 KiB, which determines the
	-- number of address bits we need to count.
	subtype tAddr is std_logic_vector(9 downto 0);

	-- librero synthesis doesn't seem to like work.axi4_fic1_from_mss_pkg.tLen
	-- as return type...
	subtype tLen is work.axi4_fic1_from_mss_pkg.tLen;

	type tState is record
		aw_size:      axi4_fic1_from_mss_pkg.tSize;
		aw_len:       tLen;
		aw_addr:      tAddr;

		x_wr_valid:   std_logic;
		x_wr_id:      axi4_fic1_from_mss_pkg.tId;
		x_wr_last:    std_logic;
		x_wr_aligned: std_logic;

		r_valid:      std_logic;
		r_len:        tLen;
		r_id:         axi4_fic1_from_mss_pkg.tId;
	end record;

	constant cStateInitial: tState := (
		aw_size       => (others => '0'),
		aw_len        => (others => '0'),
		aw_addr       => (others => '0'),
		x_wr_valid    => '0',
		x_wr_id       => (others => '0'),
		x_wr_last     => '0',
		x_wr_aligned  => '0',
		r_valid       => '0',
		r_len         => (others => '0'),
		r_id          => (others => '0')
	);

	signal rState: tState := cStateInitial;
	signal wState: tState;

	signal wXWrReady:   std_logic;
	signal wXWrData:    std_logic_vector(axi4_fic1_from_mss_pkg.tId'length + 2 - 1 downto 0);

	signal wXRdReady:   std_logic;
	signal wXRdValid:   std_logic;
	signal wXRdData:    std_logic_vector(axi4_fic1_from_mss_pkg.tId'length + 2 - 1 downto 0);
	signal wXRdId:      axi4_fic1_from_mss_pkg.tId;
	signal wXRdLast:    std_logic;
	signal wXRdAligned: std_logic;

	signal wBReady:     std_logic;
	signal wBValid:     std_logic;

begin
	sXFifo: entity work.FifoScReg generic map (
		gBits  => wXWrData'length,
		gDepth => 3
	) port map (
		iRst   => iRst,
		iClk   => iClk,

		oReady => wXWrReady,
		iValid => rState.x_wr_valid,
		iData  => wXWrData,

		iReady => wXRdReady,
		oValid => wXRdValid,
		oData  => wXRdData
	);

	wXWrData(0)                      <= rState.x_wr_last;
	wXWrData(1)                      <= rState.x_wr_aligned;
	wXWrData(wXWrData'high downto 2) <= rState.x_wr_id;

	wXRdLast    <= wXRdData(0);
	wXRdAligned <= wXRdData(1);
	wXRdId      <= wXRdData(wXRdData'high downto 2);

	sBFifo: entity work.FifoScReg generic map (
		gBits  => axi4_fic1_from_mss_pkg.tId'length,
		gDepth => 3
	) port map (
		iRst   => iRst,
		iClk   => iClk,

		oReady => wBReady,
		iValid => wBValid,
		iData  => wXRdId,

		iReady => iMosi.bready,
		oValid => oMiso.b.valid,
		oData  => oMiso.b.id
	);

	pCombinatorial: process(rState, wXWrReady, wXRdValid, wXRdLast, wXRdAligned, wXRdId, wBReady, iMosi, iStreamReady)
		function fAddrInc(cAddr: tAddr; cSize: axi4_fic1_from_mss_pkg.tSize) return tAddr is
		begin
			case cSize is
				when "00" =>
					return std_logic_vector(unsigned(cAddr) + 1);

				when "01" =>
					return std_logic_vector(unsigned(cAddr) + 2);

				when "10" =>
					return std_logic_vector(unsigned(cAddr) + 4);

				when others =>
					return std_logic_vector(unsigned(cAddr) + 8);
			end case;
		end function;

		function fAddrMatch(cAddr: tAddr) return std_logic is
		begin
			if unsigned(cAddr) = 0 then
				return '1';
			else
				return '0';
			end if;
		end function;

		function fLenDec(cLen: tLen) return tLen is
		begin
			return std_logic_vector(unsigned(cLen) - 1);
		end function;

		function fLenMatch(cLen: tLen) return std_logic is
		begin
			if unsigned(cLen) = 0 then
				return '1';
			else
				return '0';
			end if;
		end function;

		procedure fGenX(cValid: std_logic; cId: axi4_fic1_from_mss_pkg.tId; cLen: tLen; cSize: axi4_fic1_from_mss_pkg.tSize; cAddr: tAddr) is
		begin
			wState.x_wr_valid   <= cValid;
			wState.x_wr_id      <= cId;
			wState.x_wr_last    <= fLenMatch(cLen);
			wState.x_wr_aligned <= fAddrMatch(cAddr);

			wState.aw_size      <= cSize;
			wState.aw_len       <= fLenDec(cLen);
			wState.aw_addr      <= fAddrInc(cAddr, cSize);
		end procedure;

	begin
		wState <= rState;

		-- Transform aw requests into "beat descriptors" stored in a small FIFO.
		oMiso.awready <= '0';
		if rState.x_wr_valid = '0' or (rState.x_wr_last = '1' and wXWrReady = '1') then
			oMiso.awready <= '1';
			fGenX(iMosi.aw.valid, iMosi.aw.id, iMosi.aw.len, iMosi.aw.size, iMosi.aw.addr(rState.aw_addr'range));
		elsif wXWrReady = '1' then
			fGenX('1', rState.x_wr_id, rState.aw_len, rState.aw_size, rState.aw_addr);
		end if;

		-- Connect or disconnect the w channel to the output stream depending on
		-- whether we have a valid beat descriptor and no overflow on the b
		-- channel.
		wXRdReady    <= wBReady and iStreamReady and wXRdValid and iMosi.w.valid;
		wBValid      <= wBReady and iStreamReady and wXRdValid and iMosi.w.valid and wXRdLast;
		oStreamValid <= wBReady                  and wXRdValid and iMosi.w.valid;
		oMiso.wready <= wBReady and iStreamReady and wXRdValid;

		oMiso.b.resp  <= "00"; -- OKAY

		oStreamAligned <= wXRdAligned;
		oStreamStrb    <= iMosi.w.strb;
		oStreamData    <= iMosi.w.data;

		-- Accept ar and send r responses. This is annoying because we don't care
		-- about reading at all, yet we have to send the correct number of r
		-- beats. At least we really don't have to care about performance here.
		oMiso.arready <= not rState.r_valid;
		oMiso.r.valid <= rState.r_valid;
		oMiso.r.id    <= rState.r_id;
		oMiso.r.resp  <= "00"; -- OKAY
		oMiso.r.last  <= fLenMatch(rState.r_len);
		oMiso.r.data  <= (others => '0');
		if rState.r_valid = '0' then
			wState.r_valid <= iMosi.ar.valid;
			wState.r_id    <= iMosi.ar.id;
			wState.r_len   <= iMosi.ar.len;
		elsif iMosi.rready = '0' then
		elsif fLenMatch(rState.r_len) = '1' then
			wState.r_valid <= '0';
		else
			wState.r_len <= fLenDec(rState.r_len);
		end if;
	end process;

	pSequential: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState <= cStateInitial;
		elsif rising_edge(iClk) then
			rState <= wState;
		end if;
	end process;
end architecture;
