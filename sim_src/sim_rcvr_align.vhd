library ieee;
use ieee.std_logic_1164.all;

use work.sim_aurora_pkg;

entity sim_rcvr_align is
	generic (
		gLanes:            positive
	);
	port (
		iRst:              in  std_logic;
		iClkLane:          in  std_logic;
		iClkByte:          in  std_logic;

		iInValid:          in  std_logic;
		iInK:              in  std_logic_vector(gLanes - 1 downto 0);
		iInData:           in  sim_aurora_pkg.tData(gLanes - 1 downto 0);

		oOutValid:         out std_logic;
		oOutData:          out std_logic_vector(7 downto 0)
	);
end entity;

architecture behavioral of sim_rcvr_align is
	signal wValid: std_logic;
	signal wData:  sim_aurora_pkg.tData(2 * gLanes - 1 downto 0);
	signal wK:     std_logic_vector(2 * gLanes - 1 downto 0);

begin
	pAlign: process(iRst, iClkLane)
		variable vData: sim_aurora_pkg.tData(2 * gLanes - 1 downto 0);
		variable vK: std_logic_vector(2 * gLanes - 1 downto 0);
		variable vPhase: integer;

	begin
		if iRst = '1' then
			vData := (others => (others => '0'));
			vK := (others => '0');
			vPhase := -1;
			wValid <= '0';
			wData <= vData;
			wK <= vK;
		elsif rising_edge(iClkLane) then
			for i in gLanes - 1 downto 0 loop
				vData(2 * i + 0) := vData(2 * i + 1);
				vData(2 * i + 1) := iInData(i);
				vK(2 * i + 0) := vK(2 * i + 1);
				vK(2 * i + 1) := iInK(i);

				-- /SCP/ == /K28.2/K27.7/ == 0x5C 0xFB
				if vK(2 * i + 0) = '1' and vData(2 * i + 0) = x"5C" and vK(2 * i + 1) = '1' and vData(2 * i + 1) = x"FB" then
					assert vPhase /= 0 report "alignment error" severity failure;
					vPhase := 1;
				end if;
			end loop;

			if vPhase = 1 then
				wValid <= '1';
				wData <= vData;
				wK <= vK;
				vPhase := 0;
			elsif vPhase = 0 then
				wValid <= '0';
				vPhase := 1;
			end if;
		end if;
	end process;

	pOut: process(iRst, iClkByte)
		variable vCnt: natural;
		variable vValid: std_logic;
		variable vData: sim_aurora_pkg.tData(2 * gLanes - 1 downto 0);
		variable vK: std_logic_vector(2 * gLanes - 1 downto 0);

	begin
		if iRst = '1' then
			vCnt := 2 * gLanes;
			vData := (others => (others => '0'));
			vK := (others => '0');
			vValid := '0';
			oOutValid <= '0';
			oOutData <= (others => '0');
		elsif rising_edge(iClkByte) then
			if vCnt = 2 * gLanes and wValid = '1' and vValid = '0' then
				vCnt := 0;
				vData := wData;
				vK := wK;
			end if;

			if vCnt < 2 * gLanes then
				oOutValid <= not vK(vCnt);
				oOutData <= vData(vCnt);
				vCnt := vCnt + 1;
			else
				oOutValid <= '0';
				oOutData <= (others => '0');
			end if;

			vValid := wValid;
		end if;
	end process;
end architecture;
