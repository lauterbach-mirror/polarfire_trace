library ieee;
use ieee.std_logic_1164.all;

use work.sim_axi_to_x_pkg;

entity sim_pti_rx is
	generic (
		gBytes:            positive := 2
	);
	port (
		iRst:              in  std_logic;

		-- Raw trace data
		iTraceClk:         in  std_logic;
		iTraceData:        in  std_logic_vector(8 * gBytes - 1 downto 0);

		-- decoded payload data, synchronous to iClkByte
		iClkByte:          in  std_logic;
		oValid:            out std_logic;
		oData:             out std_logic_vector(7 downto 0)
	);
end entity;

architecture behavioral of sim_pti_rx is
	signal wTraceData: sim_axi_to_x_pkg.tData(gBytes - 1 downto 0);

	signal wDesValid:  std_logic;
	signal wDesData:   std_logic_vector(7 downto 0);

begin
	eBytes: for i in gBytes - 1 downto 0 generate
		wTraceData(i) <= iTraceData((i + 1) * 8 - 1 downto i * 8) after 1 ps;
	end generate;

	pDeserialize: process(iRst, iTraceClk, iClkByte)
		variable vData:  sim_axi_to_x_pkg.tData(4 * gBytes - 1 downto 0);
		variable vCnt:   natural := 0;

	begin
		if iRst = '1' then
			vData  := (others => (others => 'U'));
			vCnt   := 0;

			wDesValid <= '0';
			wDesData  <= (others => '0');
		else
			if iTraceClk'event then
				vData(vCnt + gBytes - 1 downto vCnt) := wTraceData;
				vCnt := vCnt + gBytes;
			end if;

			if rising_edge(iClkByte) then
				if vCnt > 0 then
					wDesValid <= '1';
					wDesData  <= vData(0);
					vData(vData'high) := (others => 'U');
					vData(vData'high - 1 downto 0) := vData(vData'high downto 1);
					vCnt := vCnt - 1;
				else
					wDesValid <= '0';
					wDesData  <= (others => '0');
				end if;
			end if;
		end if;
	end process;

	sDecode: entity work.sim_tpiu_decode port map (
		iRst                 => iRst,
		iClkByte             => iClkByte,

		iInValid             => wDesValid,
		iInData              => wDesData,

		oOutValid            => oValid,
		oOutData             => oData
	);
end architecture;
