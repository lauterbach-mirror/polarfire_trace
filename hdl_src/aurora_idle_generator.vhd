library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity aurora_idle_generator is
	generic (
		gBytesPerLane: positive
	);
	port (
		iClk:          in  std_logic;

		oData:         out std_logic_vector(8 * gBytesPerLane - 1 downto 0)
	);
end entity;

architecture behavioral of aurora_idle_generator is
	signal rRandom:     std_logic_vector(64 downto 0) := (others => '1');
	signal wRandomNext: std_logic_vector(64 downto 0);

	signal wRandomN:    unsigned(4 downto 0);
	signal wRandomBits: std_logic_vector(gBytesPerLane - 1 downto 0);

	signal rCounter:    unsigned(4 downto 0) := (others => '0');

	signal wData:       std_logic_vector(oData'range);
	signal rData:       std_logic_vector(oData'range) := (others => '0');

begin
	sLfsr: entity work.lfsr_65_1034 port map (
		iData            => rRandom,
		oData            => wRandomNext
	);

	wRandomN            <= '1' & unsigned(rRandom(3 downto 0));
	wRandomBits         <= rRandom(4 + gBytesPerLane - 1 downto 4);

	pCounter: process(iClk)
	begin
		if rising_edge(iClk) then
			if rCounter < gBytesPerLane then
				rCounter <= rCounter + wRandomN - gBytesPerLane;
			else
				rCounter <= rCounter            - gBytesPerLane;
			end if;
		end if;
	end process;

	eBytes: for i in gBytesPerLane - 1 downto 0 generate
		wData(8 * (i + 1) - 1 downto 8 * i) <= x"7C" when rCounter = i         -- /A/ == /K28.3/ == 0x7C
		                                  else x"BC" when wRandomBits(i) = '1' -- /K/ == /K28.5/ == 0xBC
		                                  else x"1C";                          -- /R/ == /K28.0/ == 0x1C
	end generate;

	pPipeline: process(iClk)
	begin
		if rising_edge(iClk) then
			rData <= wData;
			rRandom <= wRandomNext;
		end if;
	end process;

	oData <= rData;
end architecture;
