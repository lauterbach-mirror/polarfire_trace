library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.graycnt_pkg.fGrayNext;
use work.graycnt_pkg.fGrayAdd;

-- Device-agnostic small **asynchronous** streaming FIFO.
--
-- FifoDcReg stands for FIFO Dual Clock Register-based.
--
-- The register-based dual clock FIFO uses a small register file and two
-- Gray counters for implementation.
-- The write Gray counter is incremented on every write while the read Gray
-- counter is incremented on every read access.
-- The read and write pointers are synchronized into the respective other
-- clock domain.
-- There, they are compared to the local Gray counter in order to avoid
-- pointer overrun or underrun.
--
-- Generics
-- --------
-- gBits:
-- Data width in number of bits
--
-- gLdDepth:
-- Requires to be ld(depth) (logarithmus to the basis 2) of the actual
-- FIFO depth.

entity FifoDcReg is
	generic (
		gBits:   natural;
		gLdDepth: natural
	);
	port (
		iRst   : in  STD_LOGIC;

		iWrClk : in  STD_LOGIC;
		oReady : out STD_LOGIC;
		iValid : in  STD_LOGIC;
		iData  : in  STD_LOGIC_VECTOR(gBits - 1 downto 0);

		iRdClk : in  STD_LOGIC;
		iReady : in  STD_LOGIC;
		oValid : out STD_LOGIC;
		oData  : out STD_LOGIC_VECTOR(gBits - 1 downto 0)
	);
end entity;

architecture behavioral of FifoDcReg is
	constant cDepth: natural := 2 ** gLdDepth;
	subtype tAddr is STD_LOGIC_VECTOR(gLdDepth - 1 downto 0);

	type tFifo is array(cDepth - 1 downto 0) of STD_LOGIC_VECTOR(gBits - 1 downto 0);

	signal rFifo : tFifo;

	signal rRdGraySync : tAddr;
	signal rWrGray     : tAddr;
	signal rWrFull     : STD_LOGIC;

	signal rWrGraySync : tAddr;
	signal rRdGray     : tAddr;
	signal rRdData     : STD_LOGIC_VECTOR(gBits    - 1 downto 0);
	signal rRdEmpty    : STD_LOGIC;

	attribute altera_attribute : string;
	attribute altera_attribute of rRdGraySync : signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED""";
	attribute altera_attribute of rWrGraySync : signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED""";
	attribute altera_attribute of rRdData     : signal is "-name SYNCHRONIZER_IDENTIFICATION ""FORCED""";
begin
	process(iRst,iWrClk)
	begin
		if iRst='1' then
			rRdGraySync <= (others => '0');
			rWrGray <= (others => '0');
			rWrFull <= '0';
			rFifo <= (others => (others => '0'));
		elsif rising_edge(iWrClk) then
			rRdGraySync <= rRdGray;
			if iValid='1' and rWrFull='0' then
				rWrGray <= fGrayNext(rWrGray);
			end if;
			for i in rFifo'range loop
				if unsigned(rWrGray) = i then
					rFifo(i)<=iData;
				end if;
			end loop;
			if rWrFull='0' then
				if iValid = '1' and rRdGraySync = fGrayAdd(rWrGray, 2) then
					rWrFull<='1';
				else
					rWrFull<='0';
				end if;
			else
				if rRdGraySync/=fGrayNext(rWrGray) then
					rWrFull<='0';
				else
					rWrFull<='1';
				end if;
			end if;
		end if;
	end process;
	oReady <= not rWrFull;

	process(iRst,iRdClk)
		variable vNextRdGray : tAddr;
		variable vRdPtr : tAddr;

	begin
		if iRst='1' then
			rWrGraySync <= (others => '0');
			rRdGray <= (others => '0');
			rRdEmpty <= '1';
			rRdData<=(others => '0');
		elsif rising_edge(iRdClk) then
			vNextRdGray := fGrayNext(rRdGray);
			if rRdEmpty='1' then
				vRdPtr := rRdGray;
			else
				vRdPtr := vNextRdGray;
			end if;

			rWrGraySync<=rWrGray;
			if iReady='1' and rRdEmpty='0' then
				rRdGray <= vNextRdGray;
			end if;
			if rRdEmpty='1' or (rRdEmpty='0' and iReady='1') then
				rRdData<=rFifo(to_integer(UNSIGNED(vRdPtr)));
			end if;
			if rRdEmpty='1' then
				if rWrGraySync/=rRdGray then
					rRdEmpty<='0';
				else
					rRdEmpty<='1';
				end if;
			else
				if iReady='1' and rWrGraySync=vNextRdGray then
					rRdEmpty<='1';
				else
					rRdEmpty<='0';
				end if;
			end if;
		end if;
	end process;
	oValid <= not rRdEmpty;
	oData  <= rRdData;
end architecture;
