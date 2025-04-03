library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4_fic1_from_mss_pkg;

package sim_axi_to_x_pkg is
	type tData is array(natural range <>) of std_logic_vector(7 downto 0);

	-- Parameters that match the .bfm $RAND algorithm
	constant cLfsrInit: std_logic_vector(31 downto 0) := x"12345678";
	constant cLfsrPoly: std_logic_vector(31 downto 0) := x"04C11DB7";

	type tGeneratorState is record
		lfsr: std_logic_vector(31 downto 0);
		pos:  natural;
	end record;

	constant cGeneratorStateInitial: tGeneratorState := (
		lfsr => cLfsrInit,
		pos  => 0
	);

	type tAccParams is record
		addr: natural;
		size: positive;
		len: positive;
	end record;

	procedure fGenData(vState: inout tGeneratorState; vOut: out std_logic_vector(7 downto 0));
	procedure fMakeAccParams(vAccState: inout tGeneratorState; vAccParams: inout tAccParams; cSequenceLength: positive);
	function fSize(cSize: positive) return std_logic_vector;
	procedure fStimulateAxi(signal iClk: in std_logic; signal oMosi: out axi4_fic1_from_mss_pkg.tMOSI; signal iMiso: in axi4_fic1_from_mss_pkg.tMISO; cSequenceLength: positive);
end package;

package body sim_axi_to_x_pkg is
	procedure fGenData(vState: inout tGeneratorState; vOut: out std_logic_vector(7 downto 0)) is
	begin
		if vState.pos = 0 then
			if vState.lfsr(31) = '0' then
				vState.lfsr := (vState.lfsr(30 downto 0) & '0') xor cLfsrPoly;
			else
				vState.lfsr := vState.lfsr(30 downto 0) & '0';
			end if;
		end if;

		vOut := vState.lfsr((vState.pos + 1) * 8 - 1 downto vState.pos * 8);
		vState.pos := (vState.pos + 1) mod 4;
	end procedure;

	procedure fMakeAccParams(vAccState: inout tGeneratorState; vAccParams: inout tAccParams; cSequenceLength: positive) is
		variable vRand: std_logic_vector(7 downto 0);
		variable vMax: natural;

	begin
		fGenData(vAccState, vRand);
		vAccParams.len := to_integer(unsigned(vRand)) + 1;

		fGenData(vAccState, vRand);
		vAccParams.size := 2 ** to_integer(unsigned(vRand(1 downto 0)));

		while vAccParams.addr mod vAccParams.size /= 0 loop
			vAccParams.size := vAccParams.size / 2;
		end loop;

		-- don't cross 4 KiB burst boundary or exceed total number of Bytes we want to write
		vMax := 4096 - (vAccParams.addr mod 4096);
		if vMax > cSequenceLength - vAccParams.addr then
			vMax := cSequenceLength - vAccParams.addr;
		end if;

		if vMax < vAccParams.size then
			-- not even one transfer would fit, just use a byte burst to finish it.
			vAccParams.size := 1;
			vAccParams.len := vMax;
		end if;

		if vMax < vAccParams.size * vAccParams.len then
			vAccParams.len := vMax / vAccParams.size;
		end if;
	end procedure;

	function fSize(cSize: positive) return std_logic_vector is
	begin
		case cSize is
			when 1 =>
				return "00";

			when 2 =>
				return "01";

			when 4 =>
				return "10";

			when others =>
				return "11";
		end case;
	end function;

	procedure fStimulateAxi(signal iClk: in std_logic; signal oMosi: out axi4_fic1_from_mss_pkg.tMOSI; signal iMiso: in axi4_fic1_from_mss_pkg.tMISO; cSequenceLength: positive) is
		procedure fAccess(vDataState: inout tGeneratorState; vAccParams: inout tAccParams) is
			variable vRand: std_logic_vector(7 downto 0);

		begin
			oMosi.aw.valid <= '1';
			oMosi.aw.size  <= fSize(vAccParams.size);
			oMosi.aw.id    <= "100000011";
			oMosi.aw.len   <= std_logic_vector(to_unsigned(vAccParams.len - 1, oMosi.aw.len'length));
			oMosi.aw.addr  <= std_logic_vector(to_unsigned(vAccParams.addr, oMosi.aw.addr'length));
			wait until rising_edge(iClk) and iMiso.awready = '1';
			oMosi.aw.valid <= '0';

			oMosi.w.valid <= '1';
			oMosi.w.last  <= '0';
			for i in 0 to vAccParams.len - 1 loop
				if i = vAccParams.len - 1 then
					oMosi.w.last  <= '1';
				end if;
				oMosi.w.data  <= (others => '0');
				oMosi.w.strb  <= (others => '0');
				for j in 0 to vAccParams.size - 1 loop
					fGenData(vDataState, vRand);
					oMosi.w.strb(vAccParams.addr mod 8) <= '1';
					oMosi.w.data((vAccParams.addr mod 8 + 1) * 8 - 1 downto vAccParams.addr mod 8 * 8) <= vRand;
					vAccParams.addr := vAccParams.addr + 1;
				end loop;
				wait until rising_edge(iClk) and iMiso.wready = '1';
			end loop;
			oMosi.w.valid <= '0';

			wait until rising_edge(iClk) and iMiso.b.valid = '1';
			oMosi.bready <= '1';
			wait until rising_edge(iClk);
			oMosi.bready <= '0';
		end procedure;

		variable vAccState: tGeneratorState := cGeneratorStateInitial;
		variable vDataState: tGeneratorState := cGeneratorStateInitial;
		variable vAccParams: tAccParams := (
			addr => 0,
			size => 1,
			len  => 1
		);

	begin
		wait until rising_edge(iClk);

		-- Write a long sequence of pseudo-random data to the AXI slave using a
		-- random mixture of access types. The unit essentially ignores the
		-- address, but any Byte that is written to a 1024-Byte address will
		-- cause an additional 32 0x00 Bytes to be inserted before that Byte.
		while vAccParams.addr < cSequenceLength loop
			fMakeAccParams(vAccState, vAccParams, cSequenceLength);
			fAccess(vDataState, vAccParams);
		end loop;
	end procedure;
end package body;
