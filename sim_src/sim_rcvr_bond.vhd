library ieee;
use ieee.std_logic_1164.all;

use work.sim_aurora_pkg;

entity sim_rcvr_bond is
	generic (
		gLanes:            positive
	);
	port (
		iRst:              in  std_logic;
		iClkLane:          in  std_logic;

		iInValid:          in  std_logic_vector(gLanes - 1 downto 0);
		iInK:              in  std_logic_vector(gLanes - 1 downto 0);
		iInData:           in  sim_aurora_pkg.tData(gLanes - 1 downto 0);

		oOutValid:         out std_logic;
		oOutK:             out std_logic_vector(gLanes - 1 downto 0);
		oOutData:          out sim_aurora_pkg.tData(gLanes - 1 downto 0)
	);
end entity;

architecture behavioral of sim_rcvr_bond is
begin
	pBond: process(iRst, iClkLane)
		function fFind(cData: in sim_aurora_pkg.tData; cK: std_logic_vector) return integer is
			variable vPos: integer := -1;

		begin
			for i in cData'range loop
				if cK(i) = '1' and cData(i) = x"7C" then
					assert vPos = -1 report "multiple /A/ detected" severity failure;
					vPos := i;
				end if;
			end loop;

			return vPos;
		end function;

		constant cAllValid: std_logic_vector(gLanes - 1 downto 0) := (others => '1');
		constant cLength: natural := 8;

		type tLane is record
			data: sim_aurora_pkg.tData(cLength - 1 downto 0);
			k:    std_logic_vector(cLength - 1 downto 0);
			pos:  integer;
			pos2: integer;
		end record;

		constant cLaneRst: tLane := (
			data  => (others => (others => '0')),
			k     => (others => '0'),
			pos   => -1,
			pos2  => -1
		);

		type tLaneArray is array(natural range <>) of tLane;
		variable vLane: tLaneArray(gLanes - 1 downto 0) := (others => cLaneRst);

		type tState is (
			cStateRst,
			cStateValid,
			cStateBond
		);
		variable vState: tState := cStateRst;

		variable vEq: std_logic_vector(gLanes - 1 downto 0);

	begin
		if iRst = '1' then
			vLane := (others => cLaneRst);
			vState := cStateRst;
			oOutValid <= '0';
			oOutData <= (others => (others => '0'));
			oOutK <= (others => '0');
		elsif rising_edge(iClkLane) then
			if vState = cStateRst and iInValid = cAllValid then
				vState := cStateValid;
			end if;

			if vState >= cStateValid then
				assert iInValid = cAllValid report "input ceased to be valid" severity failure;
				for i in vLane'range loop
					vLane(i).data(vLane(i).data'high - 1 downto 0) := vLane(i).data(vLane(i).data'high downto 1);
					vLane(i).data(vLane(i).data'high) := iInData(i);
					vLane(i).k(vLane(i).k'high - 1 downto 0) := vLane(i).k(vLane(i).k'high downto 1);
					vLane(i).k(vLane(i).k'high) := iInK(i);
					vLane(i).pos2 := fFind(vLane(i).data, vLane(i).k);
					if vLane(i).pos2 = vLane(i).pos then
						vEq(i) := '1';
					else
						vEq(i) := '0';
					end if;
				end loop;
			end if;

			if vState = cStateValid and vEq = not cAllValid then
				vState := cStateBond;
				for i in vLane'range loop
					vLane(i).pos := vLane(i).pos2;
				end loop;
			end if;

			if vState = cStateBond then
				oOutValid <= '1';
				for i in vLane'range loop
					oOutK(i) <= vLane(i).k(vLane(i).pos);
					oOutData(i) <= vLane(i).data(vLane(i).pos);
				end loop;
			end if;
		end if;
	end process;
end architecture;
