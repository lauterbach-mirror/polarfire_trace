library ieee;
use ieee.std_logic_1164.all;

use work.sim_axi_to_x_pkg;

entity sim_tpiu_decode is
	port (
		iRst:              in  std_logic;
		iClkByte:          in  std_logic;

		iInValid:          in  std_logic;
		iInData:           in  std_logic_vector(7 downto 0);

		oOutValid:         out std_logic;
		oOutData:          out std_logic_vector(7 downto 0)
	);
end entity;

architecture behavioral of sim_tpiu_decode is
begin
	pDecode: process(iRst, iClkByte)
		variable vData: sim_axi_to_x_pkg.tData(0 to 15);
		variable vTid: std_logic_vector(6 downto 0);
		variable vOutData: sim_axi_to_x_pkg.tData(0 to 14);
		variable vOutCnt: natural;
		variable vOutPos: natural;
		procedure fProcessFrame is
		begin
			vOutCnt := 0;
			vOutPos := 0;

			for i in 0 to 6 loop
				if vData(2 * i + 0)(0) = '0' then
					-- data, data
					if vTid = "0000001" then
						vOutData(vOutCnt) := vData(2 * i + 0)(7 downto 1) & vData(15)(i);
						vOutCnt := vOutCnt + 1;
						vOutData(vOutCnt) := vData(2 * i + 1);
						vOutCnt := vOutCnt + 1;
					end if;
				elsif vData(15)(i) = '0' then
					-- TID, data
					vTid := vData(2 * i + 0)(7 downto 1);
					if vTid = "0000001" then
						vOutData(vOutCnt) := vData(2 * i + 1);
						vOutCnt := vOutCnt + 1;
					end if;
				else
					-- data, TID
					if vTid = "0000001" then
						vOutData(vOutCnt) := vData(2 * i + 1);
						vOutCnt := vOutCnt + 1;
					end if;
					vTid := vData(2 * i + 0)(7 downto 1);
				end if;
			end loop;

			if vData(14)(0) = '0' then
				-- data
				if vTid = "0000001" then
					vOutData(vOutCnt) := vData(14)(7 downto 1) & vData(15)(7);
					vOutCnt := vOutCnt + 1;
				end if;
			else
				-- TID
				vTid := vData(14)(7 downto 1);
			end if;
		end procedure;

		variable vSync: std_logic_vector(31 downto 0);
		variable vCnt: integer;

	begin
		if iRst = '1' then
			vSync := (others => '0');
			vData := (others => (others => '0'));
			vOutData := (others => (others => '0'));
			vCnt := -1;
			vTid := (others => '0');
			vOutCnt := 0;
			vOutPos := 0;
			oOutValid <= '0';
			oOutData  <= (others => '0');
		elsif rising_edge(iClkByte) then
			if iInValid = '1' then
				vSync := iInData & vSync(vSync'high downto 8);

				if vCnt /= -1 then
					vData(vCnt) := iInData;
					vCnt := vCnt + 1;
				end if;

				if vSync = x"7FFFFFFF" then
					assert vCnt = -1 or vCnt = 4 report "formatter sync error" severity failure;
					vCnt := 0;
				elsif vSync(31 downto 16) = x"7FFF" and vCnt > 0 and vCnt mod 2 = 0 then
					vCnt := vCnt - 2;
				end if;

				if vCnt = 16 then
					fProcessFrame;
					vCnt := 0;
				end if;

			end if;

			if vOutPos < vOutCnt then
				oOutValid <= '1';
				oOutData  <= vOutData(vOutPos);
				vOutPos   := vOutPos + 1;
			else
				oOutValid <= '0';
				oOutData  <= (others => '0');
			end if;
		end if;
	end process;
end architecture;
