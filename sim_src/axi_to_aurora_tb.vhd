library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.axi4_fic1_from_mss_pkg;

entity axi_to_aurora_tb is
	generic (
		gLanes:          positive := 2; -- must be 1 or 2
		gSequenceLength: positive := 65536
	);
end entity;

architecture behavioral of axi_to_aurora_tb is
	signal wRst:           std_logic := '1';
	signal wClkAxi:        std_logic := '1';
	signal wMosi:          axi4_fic1_from_mss_pkg.tMOSI := axi4_fic1_from_mss_pkg.cMOSIRst;
	signal wMiso:          axi4_fic1_from_mss_pkg.tMISO;
	signal wClkUser:       std_logic_vector(gLanes - 1 downto 0) := (others => '0');
	signal wClkUserStable: std_logic_vector(gLanes - 1 downto 0) := (others => '0');
	signal wPllLock:       std_logic := '0';
	signal wPhyRstN:       std_logic;
	signal wTxData:        std_logic_vector(31 downto 0);
	signal wTxK:           std_logic_vector( 3 downto 0);

	signal wRxReady:       std_logic_vector(gLanes - 1 downto 0) := (others => '0');
	signal wRxVal:         std_logic_vector(gLanes - 1 downto 0) := (others => '0');
	signal wReceivedValid: std_logic;
	signal wReceivedData:  std_logic_vector(7 downto 0);

	signal wClkLane:       std_logic := '0';
	signal wClkByte:       std_logic := '0';
	signal wDone:          std_logic := '0';
	signal wCheckDone:     std_logic := '0';

	type tGeneratorState is record
		seed1: positive;
		seed2: positive;
	end record;

	constant cGeneratorStateInitial: tGeneratorState := (
		seed1 => 42,
		seed2 => 23
	);

	procedure fGenData(vState: inout tGeneratorState; vOut: out std_logic_vector(7 downto 0)) is
		variable vRand: real;

	begin
		uniform(vState.seed1, vState.seed2, vRand);
		vOut := std_logic_vector(to_unsigned(integer(floor(256.0 * vRand)), 8));
	end procedure;

begin
	wClkAxi  <= wClkAxi xnor wDone after 5 ns;
	eClkUser: for i in gLanes - 1 downto 0 generate
		wClkUser(i) <= wClkUser(i) xnor wDone after 2 ns;
	end generate;
	wClkLane <= wClkLane xnor wDone after 0.5 ns * gLanes;
	wClkByte <= wClkByte xnor wDone after 0.5 ns;

	sUut: entity work.axi_to_aurora_impl generic map (
		gLanes            => gLanes
	) port map (
		iRst              => wRst,
		iClkAxi           => wClkAxi,

		iMosi             => wMosi,
		oMiso             => wMiso,

		iClkUser          => wClkUser,
		iClkUserStable    => wClkUserStable,
		iPllLock          => wPllLock,

		oPhyRstN          => wPhyRstN,
		oTxData           => wTxData,
		oTxK              => wTxK
	);

	sAuroraRx: entity work.sim_aurora_rx generic map (
		gLanes            => gLanes,
		gBytesPerLane     => 4 / gLanes
	) port map (
		iRst              => wRst,
		iClkLane          => wClkLane,
		iClkByte          => wClkByte,

		iRxClk            => wClkUser,

		iRxData           => wTxData,
		iRxK              => wTxK,
		iRxCodeViolation  => (others => '0'),
		iRxDisparityError => (others => '0'),

		iRxReady          => wRxReady,
		iRxVal            => wRxVal,

		oValid            => wReceivedValid,
		oData             => wReceivedData
	);

	pStimuli: process
		procedure fInit is
		begin
			wait for 10 ns;
			wRst <= '0';
			wait for 10 ns;
			wPllLock <= '1';
			wait until wPhyRstN = '1';
			wait for 10 ns;
			wClkUserStable <= (others => '1');
			wait for 1 us;
			wRxReady <= (others => '1');
			wait for 1 us;
			for i in gLanes - 1 downto 0 loop
				wait until wClkUser'event and wClkUser'last_value(i) = '0' and wClkUser(i) = '1';
				wRxVal(i) <= '1';
			end loop;
			wait for 1 us;
			wait until rising_edge(wClkAxi);
		end procedure;

		type tAccParams is record
			addr: natural;
			size: positive;
			len: positive;
		end record;

		procedure fMakeAccParams(vAccState: inout tGeneratorState; vAccParams: inout tAccParams) is
			variable vRand: std_logic_vector(7 downto 0);
			variable vMax: natural;

		begin
			fGenData(vAccState, vRand);
			vAccParams.len := to_integer(unsigned(vRand)) + 1;

			fGenData(vAccState, vRand);
			vAccParams.size := 2 ** to_integer(unsigned(vRand(1 downto 0)));

			while vAccParams.addr mod vAccParams.size /= 0 loop
				vAccParams.size := vAccParams.size / 2;
			end loop;

			-- don't cross 4 KiB burst boundary or exceed total number of Bytes we want to write
			vMax := 4096 - (vAccParams.addr mod 4096);
			if vMax > gSequenceLength - vAccParams.addr then
				vMax := gSequenceLength - vAccParams.addr;
			end if;

			if vMax < vAccParams.size then
				-- not even one transfer would fit, just use a byte burst to finish it.
				vAccParams.size := 1;
				vAccParams.len := vMax;
			end if;

			if vMax < vAccParams.size * vAccParams.len then
				vAccParams.len := vMax / vAccParams.size;
			end if;
		end procedure;

		function fSize(cSize: positive) return std_logic_vector is
		begin
			case cSize is
				when 1 =>
					return "00";

				when 2 =>
					return "01";

				when 4 =>
					return "10";

				when others =>
					return "11";
			end case;
		end function;

		procedure fAccess(vDataState: inout tGeneratorState; vAccParams: inout tAccParams) is
			variable vRand: std_logic_vector(7 downto 0);

		begin
			wMosi.aw.valid <= '1';
			wMosi.aw.size  <= fSize(vAccParams.size);
			wMosi.aw.id    <= "100000011";
			wMosi.aw.len   <= std_logic_vector(to_unsigned(vAccParams.len - 1, wMosi.aw.len'length));
			wMosi.aw.addr  <= std_logic_vector(to_unsigned(vAccParams.addr, wMosi.aw.addr'length));
			wait until rising_edge(wClkAxi) and wMiso.awready = '1';
			wMosi.aw.valid <= '0';

			wMosi.w.valid <= '1';
			wMosi.w.last  <= '0';
			for i in 0 to vAccParams.len - 1 loop
				if i = vAccParams.len - 1 then
					wMosi.w.last  <= '1';
				end if;
				wMosi.w.data  <= (others => '0');
				wMosi.w.strb  <= (others => '0');
				for j in 0 to vAccParams.size - 1 loop
					fGenData(vDataState, vRand);
					wMosi.w.strb(vAccParams.addr mod 8) <= '1';
					wMosi.w.data((vAccParams.addr mod 8 + 1) * 8 - 1 downto vAccParams.addr mod 8 * 8) <= vRand;
					vAccParams.addr := vAccParams.addr + 1;
				end loop;
				wait until rising_edge(wClkAxi) and wMiso.wready = '1';
			end loop;
			wMosi.w.valid <= '0';

			wait until rising_edge(wClkAxi) and wMiso.b.valid = '1';
			wMosi.bready <= '1';
			wait until rising_edge(wClkAxi);
			wMosi.bready <= '0';
		end procedure;

		variable vAccState: tGeneratorState := cGeneratorStateInitial;
		variable vDataState: tGeneratorState := cGeneratorStateInitial;
		variable vAccParams: tAccParams := (
			addr => 0,
			size => 1,
			len  => 1
		);

	begin
		fInit;

		-- Write a long sequence of pseudo-random data to the AXI slave using a
		-- random mixture of access types. The unit essentially ignores the
		-- address, but any Byte that is written to a 1024-Byte address will
		-- cause an additional 32 0x00 Bytes to be inserted before that Byte.
		while vAccParams.addr < gSequenceLength loop
			fMakeAccParams(vAccState, vAccParams);
			fAccess(vDataState, vAccParams);
		end loop;

		wait for 100 us;
		assert wCheckDone = '1' report "missing data" severity failure;

		wDone <= '1';
		wait;
	end process;

	pCheck: process
		variable vAddr: natural := 0;
		variable vData: std_logic_vector(7 downto 0);
		variable vDataState: tGeneratorState := cGeneratorStateInitial;

	begin
		-- Verify that we get the same data by using the same random generator.
		-- Note that the access types (size, burst length) completely do not
		-- matter here.
		while vAddr < gSequenceLength loop
			if vAddr mod 1024 = 0 then
				for i in 31 downto 0 loop
					wait until rising_edge(wClkByte) and wReceivedValid = '1';
					assert wReceivedData = x"00" report "sync pattern error" severity failure;
				end loop;
			end if;

			fGenData(vDataState, vData);
			wait until rising_edge(wClkByte) and wReceivedValid = '1';
			assert wReceivedData = vData report "data error" severity failure;

			vAddr := vAddr + 1;
		end loop;

		wCheckDone <= '1';
		wait;
	end process;
end architecture;
