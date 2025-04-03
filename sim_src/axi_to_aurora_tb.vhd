library ieee;
use ieee.std_logic_1164.all;

use work.axi4_fic1_from_mss_pkg;
use work.sim_axi_to_x_pkg;

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

	signal wCheckDone:     std_logic;

	signal wClkLane:       std_logic := '0';
	signal wClkByte:       std_logic := '0';
	signal wDone:          std_logic := '0';

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

	sCheck: entity work.sim_check_against_bfm generic map (
		gSequenceLength   => gSequenceLength
	) port map (
		iClkByte          => wClkByte,
		iValid            => wReceivedValid,
		iData             => wReceivedData,
		oDone             => wCheckDone
	);

	pStimuli: process
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

		sim_axi_to_x_pkg.fStimulateAxi(wClkAxi, wMosi, wMiso, gSequenceLength);

		wait for 100 us;
		assert wCheckDone = '1' report "missing data" severity failure;

		wDone <= '1';
		wait;
	end process;
end architecture;
