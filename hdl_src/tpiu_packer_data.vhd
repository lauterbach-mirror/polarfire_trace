library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.util_pkg.minbits;
use work.util_pkg.is_defined;
use work.tpiu_packer_pkg.fInLanes;
use work.tpiu_packer_pkg.fOutLanes;
use work.tpiu_packer_pkg.fMidLanes;

-- see tpiu_packer.vhd for documentation
entity tpiu_packer_data is
	generic (
		gBits:           positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		iData:           in  std_logic_vector(fInLanes(gBits) * 9 - 1 downto 0);
		iSource:         in  std_logic_vector(6 downto 0);
		iEnable:         in  std_logic_vector(fMidLanes(gBits) - 1 downto 0);
		iMux:            in  std_logic_vector(fMidLanes(gBits) - 1 downto 0);
		iSwizzleLow:     in  unsigned(minbits(fInLanes(gBits) + 1) - 1 downto 0);
		iSwizzleHigh:    in  unsigned(minbits(fInLanes(gBits) + 1) - 1 downto 0);
		iValid:          in  std_logic;
		iFlag:           in  std_logic;
		oReady:          out std_logic;

		oData:           out std_logic_vector(fOutLanes(gBits) * 9 - 1 downto 0);
		oValid:          out std_logic;
		oFlag:           out std_logic;
		iReady:          in  std_logic
	);
end entity;

architecture behavioral of tpiu_packer_data is
	constant cInLanes: positive := fInLanes(gBits);
	constant cOutLanes: positive := fOutLanes(gBits);
	constant cMidLanes: positive := fMidLanes(gBits);
	constant cWordsPerFrame: positive := 128 / gBits;

	type tGeneralBus is array(natural range <>) of std_logic_vector(8 downto 0);

	subtype tInBus is tGeneralBus(cInLanes - 1 downto 0);
	subtype tOutBus is tGeneralBus(cOutLanes - 1 downto 0);

	subtype tMidBusCount is unsigned(minbits(cMidLanes + 1) - 1 downto 0);
	subtype tMidBus is tGeneralBus(cMidLanes - 1 downto 0);

	type tInDataSwizzled is array(2 ** iSwizzleHigh'length - 1 downto 0) of tMidBus;
	signal wInDataSwizzled: tInDataSwizzled;

	type tState is record
		out_data:                       tMidBus;
	end record;

	constant cStateRst: tState := (
		out_data                        => (others => (others => 'U'))
	);

	signal wState:                     tState;
	signal rState:                     tState := cStateRst;

	signal wInData:                    tInBus;
	signal wOutData:                   tOutBus;

begin
	eInDataSwizzled: for i in wInDataSwizzled(0)'range generate
		eInDataSwizzled: for j in wInDataSwizzled'range generate
			eInData: if i - j >= 0 and i - j < cInLanes generate
				wInDataSwizzled(j)(i) <= wInData(i - j);
			end generate;

			eInSource: if i - j = -1 generate
				wInDataSwizzled(j)(i) <= '1' & iSource & '0';
			end generate;

			eUndefined: if i - j < -1 or i - j >= cInLanes generate
				wInDataSwizzled(j)(i) <= (others => 'U');
			end generate;
		end generate;
	end generate;

	pComb: process(rState, iReady, wInDataSwizzled, iEnable, iMux, iSwizzleLow, iSwizzleHigh, iValid, iFlag)
		variable vState:                tState;

	begin
		vState                          := rState;

		if iReady = '0' then
			oReady                       <= '0';
			wOutData                     <= (others => (others => 'U'));
			oValid                       <= 'U';
			oFlag                        <= 'U';
		else
			oReady                       <= '1';

			for i in cMidLanes - 1 downto 0 loop
				vState.out_data(i)        := (others => 'U');
				if not is_defined(iEnable(i)) then
				elsif iEnable(i) = '0' then
					-- keep data unchanged
					vState.out_data(i)     := rState.out_data(i);
				elsif i < cOutLanes and iMux(i) = '0' then
					-- shift, normal case
					vState.out_data(i)     := rState.out_data(i + cOutLanes);
				elsif i = cOutLanes and iMux(i) = '0' and gBits /= 128 then
					-- shift, special case
					vState.out_data(i)     := rState.out_data(cMidLanes - 1);
				elsif iMux(i) = '0' then
					-- this should not happen!
					report "invalid shift operation at index " & integer'image(i) & "!" severity error;
				elsif i < cOutLanes then
					-- load swizzled input into lower half of output register
					vState.out_data(i)     := wInDataSwizzled(to_integer(iSwizzleLow))(i);
				else
					-- load swizzled input into upper half of output register
					vState.out_data(i)     := wInDataSwizzled(to_integer(iSwizzleHigh))(i);
				end if;
			end loop;

			if iValid = '1' then
				wOutData                  <= rState.out_data(wOutData'range);
			else
				wOutData                  <= (others => (others => 'U'));
			end if;
			oValid                       <= iValid;
			oFlag                        <= iFlag;
		end if;

		wState                          <= vState;
	end process;

	pReg: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState           <= cStateRst;
		elsif rising_edge(iClk) then
			rState           <= wState;
		end if;
	end process;

	eSerializeIn: for i in 0 to cInLanes - 1 generate
		wInData(i) <= iData((i + 1) * 9 - 1 downto i * 9);
	end generate;

	eSerializeOut: for i in 0 to cOutLanes - 1 generate
		oData((i + 1) * 9 - 1 downto i * 9) <= wOutData(i);
	end generate;
end architecture;
