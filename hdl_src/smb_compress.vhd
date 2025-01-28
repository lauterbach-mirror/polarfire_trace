library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity smb_compress is
	port (
		iRst:                 in  std_logic;
		iClk:                 in  std_logic;

		oInReady:             out std_logic;
		iInValid:             in  std_logic;
		iInAligned:           in  std_logic;
		iInStrb:              in  std_logic_vector( 7 downto 0);
		iInData:              in  std_logic_vector(63 downto 0);

		iOutReady:            in  std_logic;
		oOutValidCnt:         out unsigned(3 downto 0);
		oOutAligned:          out std_logic;
		oOutData:             out std_logic_vector(63 downto 0)
	);
end entity;

architecture behavioral of smb_compress is
	type tState is record
		valid_cnt: unsigned(3 downto 0);
		aligned:   std_logic;
		data:      std_logic_vector(63 downto 0);
	end record;

	constant cStateInitial: tState := (
		valid_cnt  => (others => '0'),
		aligned    => '0',
		data       => (others => '0')
	);

	signal rState: tState := cStateInitial;
	signal wState: tState;

begin
	pCombinatorial: process(rState, iInValid, iInAligned, iInStrb, iInData, iOutReady)
		function fCount(cBits: std_logic_vector) return natural is
			variable vRet: natural;

		begin
			vRet := 0;
			for i in cBits'range loop
				if cBits(i) = '1' then
					vRet := vRet + 1;
				end if;
			end loop;
			return vRet;
		end function;

	begin
		wState <= rState;

		if rState.valid_cnt = 0 or iOutReady = '1' then
			oInReady <= '1';
			wState.aligned <= iInAligned;

			if iInValid = '0' then
				wState.valid_cnt <= to_unsigned(0, rState.valid_cnt'length);
			else
				wState.valid_cnt <= to_unsigned(fCount(iInStrb), rState.valid_cnt'length);
			end if;

			wState.data <= iInData;
			if iInStrb(0) = '1' then
			elsif iInStrb(1) = '1' then
				wState.data(7 downto 0)  <= iInData(15 downto 8);
			elsif iInStrb(2) = '1' then
				wState.data(15 downto 0) <= iInData(31 downto 16);
			elsif iInStrb(3) = '1' then
				wState.data(7 downto 0)  <= iInData(31 downto 24);
			elsif iInStrb(4) = '1' then
				wState.data(31 downto 0) <= iInData(63 downto 32);
			elsif iInStrb(5) = '1' then
				wState.data(7 downto 0)  <= iInData(47 downto 40);
			elsif iInStrb(6) = '1' then
				wState.data(15 downto 0) <= iInData(63 downto 48);
			else
				wState.data(7 downto 0)  <= iInData(63 downto 56);
			end if;
		else
			oInReady <= '0';
		end if;

		oOutValidCnt <= rState.valid_cnt;
		oOutAligned  <= rState.aligned;
		oOutData     <= rState.data;
	end process;

	pSequential: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState <= cStateInitial;
		elsif rising_edge(iClk) then
			rState <= wState;
		end if;
	end process;
end architecture;
