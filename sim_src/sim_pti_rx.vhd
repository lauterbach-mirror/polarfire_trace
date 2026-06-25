library ieee;
use ieee.std_logic_1164.all;

use work.sim_axi_to_x_pkg;

entity sim_pti_rx is
	generic (
		gBits:             positive := 16
	);
	port (
		iRst:              in  std_logic;

		-- Raw trace data
		iTraceClk:         in  std_logic;
		iTraceData:        in  std_logic_vector(gBits - 1 downto 0);

		-- decoded payload data, synchronous to iClkByte
		iClkByte:          in  std_logic;
		oValid:            out std_logic;
		oData:             out std_logic_vector(7 downto 0)
	);
end entity;

architecture behavioral of sim_pti_rx is
	signal wDesValid:  std_logic;
	signal wDesData:   std_logic_vector(7 downto 0);

begin
	eWide: if gBits >= 8 generate
		constant cBytes: positive := gBits / 8;
		signal wTraceData: sim_axi_to_x_pkg.tData(cBytes - 1 downto 0);

	begin
		eBytes: for i in cBytes - 1 downto 0 generate
			wTraceData(i) <= iTraceData((i + 1) * 8 - 1 downto i * 8) after 1 ps;
		end generate;

		pSerialize: process(iRst, iTraceClk, iClkByte)
			variable vData:  sim_axi_to_x_pkg.tData(4 * cBytes - 1 downto 0);
			variable vCnt:   natural := 0;

		begin
			if iRst = '1' then
				vData  := (others => (others => 'U'));
				vCnt   := 0;

				wDesValid <= '0';
				wDesData  <= (others => '0');
			else
				if iTraceClk'event then
					vData(vCnt + cBytes - 1 downto vCnt) := wTraceData;
					vCnt := vCnt + cBytes;
				end if;

				if rising_edge(iClkByte) then
					if vCnt >= 1 then
						wDesValid <= '1';
						wDesData  <= vData(0);
						vData(vData'high - 1 downto 0) := vData(vData'high downto 1);
						vData(vData'high) := (others => 'U');
						vCnt := vCnt - 1;
					else
						wDesValid <= '0';
						wDesData  <= (others => '0');
					end if;
				end if;
			end if;
		end process;
	end generate;

	eNarrow: if gBits < 8 generate
	begin
		pDeserialize: process(iRst, iTraceClk, iClkByte)
			variable vSynced: boolean := false;
			variable vData:   std_logic_vector(39 downto 0) := (others => '0');
			variable vCnt:    natural := 0;

		begin
			if iRst = '1' then
				vData  := (others => 'U');
				vCnt   := 0;

				wDesValid <= '0';
				wDesData  <= (others => '0');
			else
				if iTraceClk'event then
					if vSynced then
						vData(vCnt + gBits - 1 downto vCnt) := iTraceData;
						vCnt := vCnt + gBits;
					else
						vData(31 downto 0) := iTraceData & vData(31 downto gBits);
						if vData(31 downto 0) = x"7FFFFFFF" then
							vCnt := 32;
							vSynced := true;
						end if;
					end if;
				end if;

				if rising_edge(iClkByte) then
					if vCnt >= 8 then
						wDesValid <= '1';
						wDesData  <= vData(7 downto 0);
						vData(31 downto 0) := vData(39 downto 8);
						vData(39 downto 32) := (others => 'U');
						vCnt := vCnt - 8;
					else
						wDesValid <= '0';
						wDesData  <= (others => '0');
					end if;
				end if;
			end if;
		end process;
	end generate;

	sDecode: entity work.sim_tpiu_decode port map (
		iRst                 => iRst,
		iClkByte             => iClkByte,

		iInValid             => wDesValid,
		iInData              => wDesData,

		oOutValid            => oValid,
		oOutData             => oData
	);
end architecture;
