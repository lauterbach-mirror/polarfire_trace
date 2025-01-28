library IEEE;
use IEEE.std_logic_1164.all;

-- uses the DDR feature of I/O blocks to produce DDR output from a double-width input
-- oData and oClk must be directly connected to FPGA pins.

entity tpiu_ddr_pfio is
	generic (
		gOutBits:        positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		iData:           in  std_logic_vector(gOutBits * 2 - 1 downto 0);

		oData:           out std_logic_vector(gOutBits - 1 downto 0);
		oClk:            out std_logic
	);
end entity;

architecture behavioral of tpiu_ddr_pfio is
	-- register stage intended to be placed close to the I/O blocks
	signal rData:       std_logic_vector(gOutBits * 2 - 1 downto 0) := (others => '1');

	-- "IP" component generated to get one single DDR output register in an I/O
	-- block
	component PF_IO_DDR_OUT
		port (
			DF:     in  std_logic; -- launched on falling edge of TX_CLK, after corresponding DR beat
			DR:     in  std_logic; -- launched on rising edge of TX_CLK, before corresponding DF beat
			TX_CLK: in  std_logic;
			PADO:   out std_logic
		);
	end component;

begin
	process(iRst, iClk)
	begin
		if iRst = '1' then
			rData         <= (others => '1');
		elsif rising_edge(iClk) then
			rData         <= iData;
		end if;
	end process;

	sClkDdr: component PF_IO_DDR_OUT port map (
		TX_CLK => iClk,
		DR     => '0',
		DF     => '1',
		PADO   => oClk
	);

	sData: for i in oData'range generate
		sDdr: component PF_IO_DDR_OUT port map (
			TX_CLK => iClk,
			DR     => rData(i),
			DF     => rData(i + gOutBits),
			PADO   => oData(i)
		);
	end generate;
end architecture;
