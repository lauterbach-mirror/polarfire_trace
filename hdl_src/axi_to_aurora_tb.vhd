library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4_fic1_from_mss_pkg;

entity axi_to_aurora_tb is
end entity;

architecture behavioral of axi_to_aurora_tb is
	signal wRst:           std_logic := '1';
	signal wClkAxi:        std_logic := '1';
	signal wMosi:          axi4_fic1_from_mss_pkg.tMOSI;
	signal wMiso:          axi4_fic1_from_mss_pkg.tMISO;
	signal wClkUser:       std_logic := '1';
	signal wClkUserStable: std_logic;
	signal wPllLock:       std_logic;
	signal wPcsRstN:       std_logic;
	signal wPmaRstN:       std_logic;
	signal wTxData:        std_logic_vector(31 downto 0);
	signal wTxK:           std_logic_vector( 3 downto 0);
	signal wDone:          std_logic := '0';

begin
	wRst <= '0' after 1 ns;
	wClkAxi <= wClkAxi xnor wDone after 5 ns;
	wClkUser <= wClkUser xnor wDone after 3.141593 ns;

	sUut: entity work.axi_to_aurora_impl port map (
		iRst                => wRst,
		iClkAxi             => wClkAxi,
		iMosi               => wMosi,
		oMiso               => wMiso,
		iClkUser            => wClkUser,
		iClkUserStable      => wClkUserStable,
		iPllLock            => wPllLock,
		oPcsRstN            => wPcsRstN,
		oPmaRstN            => wPmaRstN,
		oTxData             => wTxData,
		oTxK                => wTxK
	);

	wClkUserStable <= not wRst;
	wPllLock       <= not wRst;

	pStimuli: process
	begin
		wMosi <= axi4_fic1_from_mss_pkg.cMOSIRst;

		wait until wRst = '0' and rising_edge(wClkAxi);
		wait until rising_edge(wClkAxi);
		wait until rising_edge(wClkAxi);
		wait until rising_edge(wClkAxi);

		wMosi.aw.valid <= '1';
		wMosi.aw.size  <= "10";
		wMosi.aw.id    <= "100000011";
		wMosi.aw.len   <= std_logic_vector(to_unsigned(1 - 1, wMosi.aw.len'length));
		wMosi.aw.addr  <= std_logic_vector(to_unsigned(0, wMosi.aw.addr'length));
		wait until rising_edge(wClkAxi) and wMiso.awready = '1';
		wMosi.aw.valid <= '0';

		wMosi.w.valid <= '1';
		wMosi.w.last  <= '1';
		wMosi.w.data  <= x"00000000DEADBEEF";
		wMosi.w.strb  <= "00001111";
		wait until rising_edge(wClkAxi) and wMiso.wready = '1';
		wMosi.w.valid <= '0';

		wait until rising_edge(wClkAxi) and wMiso.b.valid = '1';
		wMosi.bready <= '1';
		wait until rising_edge(wClkAxi);
		wMosi.bready <= '0';

		wMosi.aw.valid <= '1';
		wMosi.aw.size  <= "11";
		wMosi.aw.id    <= "011111100";
		wMosi.aw.len   <= std_logic_vector(to_unsigned(2 - 1, wMosi.aw.len'length));
		wMosi.aw.addr  <= std_logic_vector(to_unsigned(0, wMosi.aw.addr'length));
		wait until rising_edge(wClkAxi) and wMiso.awready = '1';
		wMosi.aw.valid <= '0';

		wMosi.w.valid <= '1';
		wMosi.w.last  <= '0';
		wMosi.w.data  <= x"AAAAAAAAAAAAAAAA";
		wMosi.w.strb  <= "11111111";
		wait until rising_edge(wClkAxi) and wMiso.wready = '1';
		wMosi.w.last  <= '1';
		wMosi.w.data  <= x"BBBBBBBBBBBBBBBB";
		wait until rising_edge(wClkAxi) and wMiso.wready = '1';
		wMosi.w.valid <= '0';

		wait until rising_edge(wClkAxi) and wMiso.b.valid = '1';
		wMosi.bready <= '1';
		wait until rising_edge(wClkAxi);
		wMosi.bready <= '0';

		wait for 200 ns;
		wDone <= '1';
		wait;
	end process;
end architecture;
