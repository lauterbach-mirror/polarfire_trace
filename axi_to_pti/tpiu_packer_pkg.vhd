library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package tpiu_packer_pkg is
	function fInLanes(cInBits: positive) return positive;
	function fOutLanes(cInBits: positive) return positive;
	function fMidLanes(cInBits: positive) return positive;
end package;

package body tpiu_packer_pkg is
	function fInLanes(cInBits: positive) return positive is
	begin
		if cInBits /= 128 then
			return cInBits / 8;
		else
			return 15;
		end if;
	end function;

	function fOutLanes(cInBits: positive) return positive is
	begin
		if cInBits /= 128 then
			return cInBits / 8;
		else
			return 15;
		end if;
	end function;

	function fMidLanes(cInBits: positive) return positive is
	begin
		return fInLanes(cInBits) + fOutLanes(cInBits);
	end function;
end package body;
