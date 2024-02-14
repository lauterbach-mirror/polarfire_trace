library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.util_pkg.minbits;

entity tpiu_output_fifo_reader is
	generic (
		gInBits:         positive;
		gOutBits:        positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		iData:           in  std_logic_vector(gInBits - 1 downto 0);
		oReady:          out std_logic;

		oData:           out std_logic_vector(gOutBits - 1 downto 0)
	);

begin
	assert gInBits mod gOutBits = 0 report "tpiu_output_fifo_reader argument error: gInBits = " & integer'image(gInBits) & ", gOutBits = " & integer'image(gOutBits) severity failure;
end entity;

architecture behavioral of tpiu_output_fifo_reader is
	constant cRatio: positive := gInBits / gOutBits;

	signal rCnt:        unsigned(minbits(cRatio) - 1 downto 0) := (others => '0');
	signal rReady:      std_logic;

	signal rData:       std_logic_vector(gInBits - 1 downto 0) := (others => '0');

begin
	oReady              <= rReady;
	oData               <= rData(oData'range);

	pReg: process(iRst, iClk)
	begin
		if iRst = '1' then
			rReady        <= '1';
			rCnt          <= (others => '0');
			rData         <= (others => '0');
		elsif rising_edge(iClk) then
			if ('0' & rCnt) = cRatio - 1 then
				rReady     <= '1';
				rCnt       <= (others => '0');
			else
				rReady     <= '0';
				rCnt       <= rCnt + 1;
			end if;

			if rReady = '1' then
				rData      <= iData;
			else
				rData      <= (others => 'U');
				rData(rData'high - gOutBits downto 0) <= rData(rData'high downto gOutBits);
			end if;
		end if;
	end process;
end architecture;
