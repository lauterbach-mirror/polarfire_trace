library ieee;
use ieee.std_logic_1164.all;

use work.sim_aurora_pkg;

entity sim_rcvr_deserialize is
	generic (
		gBytesPerLane:     positive
	);
	port (
		iRst:              in  std_logic;

		-- clock from receiver
		iRxClk:            in  std_logic;

		-- per-symbol data
		iRxData:           in  sim_aurora_pkg.tData(gBytesPerLane - 1 downto 0);
		iRxK:              in  std_logic_vector(gBytesPerLane - 1 downto 0);
		iRxCodeViolation:  in  std_logic_vector(gBytesPerLane - 1 downto 0);
		iRxDisparityError: in  std_logic_vector(gBytesPerLane - 1 downto 0);

		-- sideband signals from receiver
		iRxReady:          in  std_logic; -- async!
		iRxVal:            in  std_logic;

		-- cleaned-up output stream containing only valid symbols
		iOutClk:           in  std_logic;
		oOutValid:         out std_logic;
		oOutK:             out std_logic;
		oOutData:          out std_logic_vector(7 downto 0)
	);
end entity;

architecture behavioral of sim_rcvr_deserialize is
	type tInput is record
		data:            sim_aurora_pkg.tData(gBytesPerLane - 1 downto 0);
		k:               std_logic_vector(gBytesPerLane - 1 downto 0);
		code_violation:  std_logic_vector(gBytesPerLane - 1 downto 0);
		disparity_error: std_logic_vector(gBytesPerLane - 1 downto 0);
		val:             std_logic;
	end record;
	signal wInputOrig: tInput;
	signal wInput:     tInput;

	signal wTgl:       std_logic := '0';

begin
	wInputOrig.data            <= iRxData;
	wInputOrig.k               <= iRxK;
	wInputOrig.code_violation  <= iRxCodeViolation;
	wInputOrig.disparity_error <= iRxDisparityError;
	wInputOrig.val             <= iRxVal;

	-- try to clean up after potentially gated clocks...
	wInput <= wInputOrig after 1 ps;

	pInput: process(iRst, iRxReady, iRxClk)
		type tState is (
			cStateRst,
			cStateReady,
			cStateVal
		);
		variable vState: tState := cStateRst;

	begin
		if iRst = '1' then
			vState := cStateRst;
		elsif vState = cStateRst and rising_edge(iRxReady) then
			vState := cStateReady;
		elsif rising_edge(iRxClk) and (wInput.val = '1' or vState = cStateVal) then
			vState := cStateVal;
			for i in gBytesPerLane - 1 downto 0 loop
				assert wInput.code_violation(i) = '0' report "code violation on symbol " & integer'image(i) severity failure;
				assert wInput.disparity_error(i) = '0' report "disparity error on symbol " & integer'image(i) severity failure;
			end loop;
			wTgl <= not wTgl;
		end if;

		if vState >= cStateReady then
			assert iRxReady = '1' report "receiver ceased to be ready" severity failure;
		end if;

		if vState >= cStateVal and rising_edge(iRxClk) then
			assert wInput.val = '1' report "receiver ceased to be val" severity failure;
		end if;
	end process;

	pOutput: process(iRst, iOutClk, wTgl)
		variable vData:  sim_aurora_pkg.tData(4 * gBytesPerLane - 1 downto 0);
		variable vK:     std_logic_vector(4 * gBytesPerLane - 1 downto 0);
		variable vCnt:   natural := 0;
		variable vValid: std_logic := '0';

	begin
		if iRst = '1' then
			vData  := (others => (others => 'U'));
			vK     := (others => 'U');
			vCnt   := 0;
			vValid := '0';

			oOutValid <= '0';
			oOutK     <= '0';
			oOutData  <= (others => '0');
		else
			if wTgl'event then
				vData(vCnt + gBytesPerLane - 1 downto vCnt) := wInput.data;
				vK   (vCnt + gBytesPerLane - 1 downto vCnt) := wInput.k;
				vCnt := vCnt + gBytesPerLane;
				if vCnt >= 2 * gBytesPerLane then
					vValid := '1';
				end if;
			end if;

			if rising_edge(iOutClk) and vValid = '1' then
				oOutValid <= '1';
				oOutK     <= vK(0);
				oOutData  <= vData(0);
				vData(vData'high) := (others => 'U');
				vData(vData'high - 1 downto 0) := vData(vData'high downto 1);
				vK := 'U' & vK(vK'high downto 1);
				vCnt := vCnt - 1;
			end if;
		end if;
	end process;
end architecture;
