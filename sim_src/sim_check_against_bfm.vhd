library ieee;
use ieee.std_logic_1164.all;

use work.sim_axi_to_x_pkg;

entity sim_check_against_bfm is
	generic (
		gSequenceLength:   positive := 64 * (16 + 8)
	);
	port (
		iClkByte:          in  std_logic;
		iValid:            in  std_logic;
		iData:             in  std_logic_vector(7 downto 0);
		oDone:             out std_logic
	);
end entity;

architecture behavioral of sim_check_against_bfm is
begin
	pCheck: process
		variable vAddr: natural := 0;
		variable vData: std_logic_vector(7 downto 0);
		variable vDataState: sim_axi_to_x_pkg.tGeneratorState := sim_axi_to_x_pkg.cGeneratorStateInitial;

	begin
		oDone <= '0';

		-- Verify that we get the same data by using the same random generator.
		-- Note that the access types (size, burst length) completely do not
		-- matter here.
		while vAddr < gSequenceLength loop
			if vAddr mod 1024 = 0 then
				for i in 31 downto 0 loop
					wait until rising_edge(iClkByte) and iValid = '1';
					assert iData = x"00" report "sync pattern error" severity failure;
				end loop;
			end if;

			sim_axi_to_x_pkg.fGenData(vDataState, vData);
			wait until rising_edge(iClkByte) and iValid = '1';
			assert iData = vData report "data error" severity failure;

			vAddr := vAddr + 1;
		end loop;

		oDone <= '1';

		loop
			wait until rising_edge(iClkByte);
			assert iValid = '0' report "unexpected extra data" severity failure;
		end loop;
	end process;
end architecture;
