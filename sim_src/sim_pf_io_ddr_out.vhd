library ieee;
use ieee.std_logic_1164.all;

entity PF_IO_DDR_OUT is
	port (
		DF:     in  std_logic; -- launched on falling edge of TX_CLK, after corresponding DR beat
		DR:     in  std_logic; -- launched on rising edge of TX_CLK, before corresponding DF beat
		TX_CLK: in  std_logic;
		PADO:   out std_logic
	);
end entity;

architecture behavioral of PF_IO_DDR_OUT is
begin
	pDdr: process(TX_CLK)
		variable vD: std_logic;

	begin
		if rising_edge(TX_CLK) then
			PADO <= DR;
			vD := DF;
		end if;

		if falling_edge(TX_CLK) then
			PADO <= vD;
		end if;
	end process;
end architecture;
