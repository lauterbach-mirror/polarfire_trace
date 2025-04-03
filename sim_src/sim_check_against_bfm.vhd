library ieee;
use ieee.std_logic_1164.all;

entity sim_check_against_bfm is
	generic (
		gSequenceLength:   positive := 64 * (16 + 8);
		gLfsrInit:         std_logic_vector := x"12345678";
		gLfsrPoly:         std_logic_vector := x"04C11DB7"
	);
	port (
		iClkByte:          in  std_logic;
		iValid:            in  std_logic;
		iData:             in  std_logic_vector(7 downto 0);
		oDone:             out std_logic
	);
end entity;

architecture behavioral of sim_check_against_bfm is
	type tGeneratorState is record
		lfsr: std_logic_vector(31 downto 0);
		pos:  natural;
	end record;

	constant cGeneratorStateInitial: tGeneratorState := (
		lfsr => gLfsrInit,
		pos  => 0
	);

	procedure fGenData(vState: inout tGeneratorState; vOut: out std_logic_vector(7 downto 0)) is
	begin
		if vState.pos = 0 then
			if vState.lfsr(31) = '0' then
				vState.lfsr := (vState.lfsr(30 downto 0) & '0') xor gLfsrPoly;
			else
				vState.lfsr := vState.lfsr(30 downto 0) & '0';
			end if;
		end if;

		vOut := vState.lfsr((vState.pos + 1) * 8 - 1 downto vState.pos * 8);
		vState.pos := (vState.pos + 1) mod 4;
	end procedure;

begin
	pCheck: process
		variable vAddr: natural := 0;
		variable vData: std_logic_vector(7 downto 0);
		variable vDataState: tGeneratorState := cGeneratorStateInitial;

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

			fGenData(vDataState, vData);
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
