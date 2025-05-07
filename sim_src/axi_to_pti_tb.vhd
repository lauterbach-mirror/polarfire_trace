library ieee;
use ieee.std_logic_1164.all;

use work.axi4_fic1_from_mss_pkg;
use work.sim_axi_to_x_pkg;

entity axi_to_pti_tb is
	generic (
		gBytes:          positive := 2;
		gSequenceLength: positive := 65536
	);
end entity;

architecture behavioral of axi_to_pti_tb is
	signal wRst:           std_logic := '1';
	signal wClkAxi:        std_logic := '1';
	signal wClkTrace:      std_logic := '1';
	signal wMosi:          axi4_fic1_from_mss_pkg.tMOSI := axi4_fic1_from_mss_pkg.cMOSIRst;
	signal wMiso:          axi4_fic1_from_mss_pkg.tMISO;
	signal wTraceClk:      std_logic;
	signal wTraceData:     std_logic_vector(8 * gBytes - 1 downto 0);

	signal wReceivedValid: std_logic;
	signal wReceivedData:  std_logic_vector(7 downto 0);

	signal wCheckDone:     std_logic;

	signal wClkByte:       std_logic := '0';
	signal wDone:          std_logic := '0';

begin
	wClkAxi   <= wClkAxi   xnor wDone after 8 ns;
	wClkTrace <= wClkTrace xnor wDone after 4 ns;
	wClkByte  <= wClkByte  xnor wDone after 2 ns / gBytes;

	sUut: entity work.axi_to_pti_impl generic map (
		gOutBits   => 8 * gBytes
	) port map (
		iRst       => wRst,
		iClkAxi    => wClkAxi,
		iClkTrace  => wClkTrace,

		iMosi      => wMosi,
		oMiso      => wMiso,

		oTraceClk  => wTraceClk,
		oTraceData => wTraceData
	);

	sPtiRx: entity work.sim_pti_rx generic map (
		gBytes            => gBytes
	) port map (
		iRst              => wRst,

		iTraceClk         => wTraceClk,
		iTraceData        => wTraceData,

		iClkByte          => wClkByte,
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
		wait for 1 us;

		sim_axi_to_x_pkg.fStimulateAxi(wClkAxi, wMosi, wMiso, gSequenceLength);

		wait for 100 us;
		assert wCheckDone = '1' report "missing data" severity failure;

		wDone <= '1';
		wait;
	end process;
end architecture;
