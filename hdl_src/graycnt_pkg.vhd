library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package graycnt_pkg is
	function fBinToGray( iBinCnt : in STD_LOGIC_VECTOR )
	return STD_LOGIC_VECTOR;

	function fGrayToBin( iGrayCnt : in STD_LOGIC_VECTOR )
	return STD_LOGIC_VECTOR;

	function fGrayAdd( iGrayCnt : in STD_LOGIC_VECTOR; iValue: in integer )
	return STD_LOGIC_VECTOR;

	function fGrayNext( iGrayCnt : in STD_LOGIC_VECTOR )
	return STD_LOGIC_VECTOR;
end graycnt_pkg;

package body graycnt_pkg is
	function fBinToGray( iBinCnt : in STD_LOGIC_VECTOR )
	return STD_LOGIC_VECTOR is
	begin
		-- convert next binary value to gray code
		return iBinCnt xor ('0' & iBinCnt(iBinCnt'high downto (iBinCnt'low + 1)));
	end fBinToGray;

	function fGrayToBin( iGrayCnt : in STD_LOGIC_VECTOR )
	return STD_LOGIC_VECTOR is
		variable vBin : STD_LOGIC_VECTOR(iGrayCnt'range);
	begin
		-- Convert input to binary
		vBin(iGrayCnt'high) := iGrayCnt(iGrayCnt'high);
		for i in iGrayCnt'high-1 downto iGrayCnt'low loop
			vBin(i) := iGrayCnt(i) xor vBin(i+1);
		end loop;
		return vBin;
	end fGrayToBin;

	-- Calculate iGrayCnt + iValue
	--  iGrayCnt : Gray encoded value
	--  iValue   : BINARY number to add
	function fGrayAdd( iGrayCnt : in STD_LOGIC_VECTOR; iValue : in integer)
	return STD_LOGIC_VECTOR is
		variable vBin    : STD_LOGIC_VECTOR(iGrayCnt'range);
		variable vNext   : STD_LOGIC_VECTOR(iGrayCnt'range);
		variable vResult : STD_LOGIC_VECTOR(iGrayCnt'range);
	begin
		-- Convert input to binary
		vBin := fGrayToBin(iGrayCnt);
		-- calculate binary value + iValue
		vNext := STD_LOGIC_VECTOR(UNSIGNED(vBin) + iValue);
		-- convert next binary value to gray code
		vResult := fBinToGray(vNext);
		return vResult;
	end fGrayAdd;

	-- Calculate next value for gray counter.
	function fGrayNext( iGrayCnt : in STD_LOGIC_VECTOR )
	return STD_LOGIC_VECTOR is
		variable vBin    : STD_LOGIC_VECTOR(iGrayCnt'range);
		variable vNext   : STD_LOGIC_VECTOR(iGrayCnt'range);
		variable vResult : STD_LOGIC_VECTOR(iGrayCnt'range);
	begin
		return fGrayAdd(iGrayCnt, 1);
	end fGrayNext;
end graycnt_pkg;
