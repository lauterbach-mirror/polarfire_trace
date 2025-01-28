library IEEE;
use IEEE.std_logic_1164.all;

-- simply halves iClk to produce oClk
entity tpiu_ddr_halfspeed is
	generic (
		gOutBits:        positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		iData:           in  std_logic_vector(gOutBits - 1 downto 0);

		oData:           out std_logic_vector(gOutBits - 1 downto 0);
		oClk:            out std_logic
	);
end entity;

architecture behavioral of tpiu_ddr_halfspeed is
	signal rData:       std_logic_vector(gOutBits - 1 downto 0) := (others => '0');
	signal rClk:        std_logic := '1';
	signal rClkP:       std_logic := '0';

begin
	pReg: process(iRst, iClk)
	begin
		if iRst = '1' then
			rData         <= (others => '0');
			rClk          <= '1';
			rClkP         <= '0';
		elsif rising_edge(iClk) then
			rData         <= iData;
			rClk          <= not rClk;
			rClkP         <= rClk;
		end if;
	end process;

	oData               <= rData;
	oClk                <= rClkP;
end architecture;
