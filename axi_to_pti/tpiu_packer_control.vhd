library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.util_pkg.minbits;
use work.util_pkg.is_defined;
use work.tpiu_packer_pkg.fInLanes;
use work.tpiu_packer_pkg.fMidLanes;

-- see tpiu_packer.vhd for documentation
entity tpiu_packer_control is
	generic (
		gBits:           positive;
		gSyncBits:       positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		iSyncInterval:   in  unsigned(gSyncBits - 1 downto 0);

		iData:           in  std_logic_vector(fInLanes(gBits) * 9 - 1 downto 0);
		iSource:         in  std_logic_vector(6 downto 0);
		iOldValid:       in  unsigned(minbits(fMidLanes(gBits) + 1) - 1 downto 0);
		iNewShort:       in  std_logic;
		iForceSource:    in  std_logic;
		iValid:          in  std_logic;
		iFlag:           in  std_logic;
		oReady:          out std_logic;

		oData:           out std_logic_vector(fInLanes(gBits) * 9 - 1 downto 0);
		oSource:         out std_logic_vector(6 downto 0);
		oEnable:         out std_logic_vector(fMidLanes(gBits) - 1 downto 0);
		oMux:            out std_logic_vector(fMidLanes(gBits) - 1 downto 0);
		oSwizzleLow:     out unsigned(minbits(fInLanes(gBits) + 1) - 1 downto 0);
		oSwizzleHigh:    out unsigned(minbits(fInLanes(gBits) + 1) - 1 downto 0);
		oValid:          out std_logic;
		oFlag:           out std_logic;
		iReady:          in  std_logic
	);
end entity;

architecture behavioral of tpiu_packer_control is
	constant cLanes: positive := fInLanes(gBits);
	constant cMidLanes: positive := fMidLanes(gBits);
	constant cWordsPerFrame: positive := 128 / gBits;

	type tGeneralBus is array(natural range <>) of std_logic_vector(8 downto 0);

	subtype tBusCount is unsigned(minbits(cLanes + 1) - 1 downto 0);
	subtype tBusIndex is unsigned(minbits(cLanes) - 1 downto 0);
	subtype tBus is tGeneralBus(cLanes - 1 downto 0);

	subtype tMidBusCount is unsigned(minbits(cMidLanes + 1) - 1 downto 0);
	subtype tMidBus is tGeneralBus(cMidLanes - 1 downto 0);

	type tState is record
		sync_counter:                   unsigned(gSyncBits - 1 downto 0);
		sync:                           std_logic;
		out_data:                       tBus;
		out_source:                     std_logic_vector(6 downto 0);
		out_enable:                     std_logic_vector(cMidLanes - 1 downto 0);
		out_mux:                        std_logic_vector(cMidLanes - 1 downto 0);
		out_swizzle_low:                tBusCount;
		out_swizzle_high:               tBusCount;
		out_valid:                      std_logic;
		out_flag:                       std_logic;
	end record;

	constant cStateRst: tState := (
		sync_counter                    => (others => '0'),
		sync                            => '0',
		out_data                        => (others => (others => 'U')),
		out_source                      => (others => 'U'),
		out_enable                      => (others => '0'),
		out_mux                         => (others => 'U'),
		out_swizzle_low                 => (others => 'U'),
		out_swizzle_high                => (others => 'U'),
		out_valid                       => '0',
		out_flag                        => '0'
	);

	signal wState:                     tState;
	signal rState:                     tState := cStateRst;

	signal wInData:                    tBus;
	signal wOutData:                   tBus;

begin

	pComb: process(rState, iReady, iSyncInterval, wInData, iSource, iOldValid, iNewShort, iForceSource, iValid, iFlag)
		variable vState:                tState;

	begin
		vState                          := rState;

		if iReady = '0' then
			oReady                       <= '0';
			wOutData                     <= (others => (others => 'U'));
			oSource                      <= (others => 'U');
			oEnable                      <= (others => 'U');
			oMux                         <= (others => 'U');
			oSwizzleLow                  <= (others => 'U');
			oSwizzleHigh                 <= (others => 'U');
			oValid                       <= 'U';
			oFlag                        <= 'U';
		else
			oReady                       <= not rState.sync;

			for i in cMidLanes - 1 downto 0 loop
				vState.out_enable(i)      := '0';
				vState.out_mux(i)         := 'U';
				if rState.sync = '1' then
					-- no change if a sync word has been forced
				elsif i < cLanes and iValid = '0' and i < iOldValid then
					-- no change if we already have valid output data and are waiting for more
				elsif i < cLanes and iValid = '1' and i < iOldValid then
					-- shift in data, regular case
					vState.out_enable(i)   := '1';
					vState.out_mux(i)      := '0';
				elsif i = cLanes and iValid = '1' and iOldValid = cLanes and gBits /= 128 then
					-- shift in data, special case
					vState.out_enable(i)   := '1';
					vState.out_mux(i)      := '0';
				else
					-- get new swizzled data
					vState.out_enable(i)   := '1';
					vState.out_mux(i)      := '1';
				end if;
			end loop;

			if rState.sync = '1' then
				oReady                    <= '0';
				vState.out_valid          := '0';
				vState.out_swizzle_low    := (others => 'U');
				vState.out_swizzle_high   := (others => 'U');
				vState.out_data           := (others => (others => 'U'));
				vState.out_source         := (others => 'U');
				if gBits = 16 then
					vState.out_flag        := not rState.out_flag;
				else
					vState.out_flag        := '0';
				end if;
			else
				oReady                    <= '1';
				vState.out_valid          := iValid;
				vState.out_flag           := iFlag;
				vState.out_data           := wInData;
				vState.out_source         := iSource;
				vState.out_swizzle_low    := resize(iOldValid, vState.out_swizzle_low'length);
				if iForceSource = '1' then
					vState.out_swizzle_low := vState.out_swizzle_low + 1;
				end if;
				vState.out_swizzle_high   := vState.out_swizzle_low;
				if iNewShort = '1' and gBits /= 128 then
					vState.out_swizzle_high:= vState.out_swizzle_high + 1;
				end if;
			end if;

			vState.sync                  := '0';
			if rState.sync_counter /= 0 then
				vState.sync_counter       := rState.sync_counter - 1;
			elsif vState.out_valid = '1' and vState.out_flag = '1' then
				-- start sync when we've output the auxiliary word
				vState.sync               := '1';
			end if;

			if vState.out_valid = '0' and vState.out_flag = '0' then
				if gBits = 16 then
					-- in 16 bit mode, after a full sync has been started, we always need another half sync word
					vState.sync            := '1';
				end if;

				vState.sync_counter       := iSyncInterval;
			end if;

			wOutData                     <= rState.out_data;
			oSource                      <= rState.out_source;
			oEnable                      <= rState.out_enable;
			oMux                         <= rState.out_mux;
			oSwizzleLow                  <= rState.out_swizzle_low;
			oSwizzleHigh                 <= rState.out_swizzle_high;
			oValid                       <= rState.out_valid;
			oFlag                        <= rState.out_flag;
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

	eSerialize: for i in 0 to cLanes - 1 generate
		oData((i + 1) * 9 - 1 downto i * 9) <= wOutData(i);
		wInData(i) <= iData((i + 1) * 9 - 1 downto i * 9);
	end generate;
end architecture;
