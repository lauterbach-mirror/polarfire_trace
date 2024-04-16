library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package util_pkg is
	-- returns the minimum number of bits required to hold a value ranging from 0 to num - 1
	function minbits(num: positive) return natural;

	-- check whether all bits are '0' or '1'; used to properly propagate undefined values across decisions and arithmetic, avoiding warnings and simulation mismatches
	function is_defined(a: std_logic) return boolean;
	function is_defined(a: std_logic_vector) return boolean;
	function is_defined(a: unsigned) return boolean;
	function is_defined(a: signed) return boolean;
end package;

package body util_pkg is
	function minbits(num: positive) return natural is
		variable i: natural := 1;

	begin
		for j in 0 to 32 loop
			if i >= num then
				return j;
			else
				i := i * 2;
			end if;
		end loop;
		return 32;
	end function;

	function is_defined(a: std_logic) return boolean is
	begin
		if a /= '0' and a /= '1' then
			return false;
		else
			return true;
		end if;
	end function;

	function is_defined(a: std_logic_vector) return boolean is
	begin
		for i in a'range loop
			if not is_defined(a(i)) then
				return false;
			end if;
		end loop;
		return true;
	end function;

	function is_defined(a: unsigned) return boolean is
	begin
		return is_defined(std_logic_vector(a));
	end function;

	function is_defined(a: signed) return boolean is
	begin
		return is_defined(std_logic_vector(a));
	end function;
end package body;
