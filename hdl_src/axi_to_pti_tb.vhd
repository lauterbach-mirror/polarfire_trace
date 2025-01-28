library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4_fic1_from_mss_pkg;

entity axi_to_pti_tb is
end entity;

architecture behavioral of axi_to_pti_tb is
	signal wRst:       std_logic := '1';
	signal wClk:       std_logic := '1';
	signal wMosi:      axi4_fic1_from_mss_pkg.tMOSI;
	signal wMiso:      axi4_fic1_from_mss_pkg.tMISO;
	signal wTraceClk:  std_logic;
	signal wTraceData: std_logic_vector(15 downto 0);
	signal wDone:      std_logic := '0';

begin
	wRst <= '0' after 1 ns;
	wClk <= wClk xnor wDone after 5 ns;

	sUut: entity work.axi_to_pti_impl port map (
		iRst       => wRst,
		iClk       => wClk,
		iMosi      => wMosi,
		oMiso      => wMiso,
		oTraceClk  => wTraceClk,
		oTraceData => wTraceData
	);

	pStimuli: process
	begin
		wMosi <= axi4_fic1_from_mss_pkg.cMOSIRst;

		wait until wRst = '0' and rising_edge(wClk);
		wait until rising_edge(wClk);
		wait until rising_edge(wClk);
		wait until rising_edge(wClk);

		wMosi.aw.valid <= '1';
		wMosi.aw.size  <= "10";
		wMosi.aw.id    <= "100000011";
		wMosi.aw.len   <= std_logic_vector(to_unsigned(1 - 1, wMosi.aw.len'length));
		wMosi.aw.addr  <= std_logic_vector(to_unsigned(0, wMosi.aw.addr'length));
		wait until rising_edge(wClk) and wMiso.awready = '1';
		wMosi.aw.valid <= '0';

		wMosi.w.valid <= '1';
		wMosi.w.last  <= '1';
		wMosi.w.data  <= x"00000000DEADBEEF";
		wMosi.w.strb  <= "00001111";
		wait until rising_edge(wClk) and wMiso.wready = '1';
		wMosi.w.valid <= '0';

		wait until rising_edge(wClk) and wMiso.b.valid = '1';
		wMosi.bready <= '1';
		wait until rising_edge(wClk);
		wMosi.bready <= '0';

		wMosi.aw.valid <= '1';
		wMosi.aw.size  <= "11";
		wMosi.aw.id    <= "011111100";
		wMosi.aw.len   <= std_logic_vector(to_unsigned(2 - 1, wMosi.aw.len'length));
		wMosi.aw.addr  <= std_logic_vector(to_unsigned(0, wMosi.aw.addr'length));
		wait until rising_edge(wClk) and wMiso.awready = '1';
		wMosi.aw.valid <= '0';

		wMosi.w.valid <= '1';
		wMosi.w.last  <= '0';
		wMosi.w.data  <= x"AAAAAAAAAAAAAAAA";
		wMosi.w.strb  <= "11111111";
		wait until rising_edge(wClk) and wMiso.wready = '1';
		wMosi.w.last  <= '1';
		wMosi.w.data  <= x"BBBBBBBBBBBBBBBB";
		wait until rising_edge(wClk) and wMiso.wready = '1';
		wMosi.w.valid <= '0';

		wait until rising_edge(wClk) and wMiso.b.valid = '1';
		wMosi.bready <= '1';
		wait until rising_edge(wClk);
		wMosi.bready <= '0';

		wait for 100 ns;
		wDone <= '1';
		wait;
	end process;
end architecture;
