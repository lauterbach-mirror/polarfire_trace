library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.util_pkg.minbits;
use work.util_pkg.is_defined;
use work.tpiu_packer_pkg.fInLanes;
use work.tpiu_packer_pkg.fMidLanes;

-- see tpiu_packer.vhd for documentation
entity tpiu_packer_scheduler is
	generic (
		gBits:           positive;
		gFlushBits:      positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		iFlushInterval:  in  unsigned(gFlushBits - 1 downto 0);
		iFlushSource:    in  std_logic_vector(6 downto 0);
		iSyncSource:     in  std_logic_vector(6 downto 0);

		iSync:           in  std_logic;
		iData:           in  std_logic_vector(fInLanes(gBits) * 9 - 1 downto 0);
		iValid:          in  unsigned(minbits(fInLanes(gBits) + 1) - 1 downto 0);
		iSource:         in  std_logic_vector(6 downto 0);
		iForceSource:    in  std_logic;
		oReady:          out std_logic;

		oData:           out std_logic_vector(fInLanes(gBits) * 9 - 1 downto 0);
		oSource:         out std_logic_vector(6 downto 0);
		oOldValid:       out unsigned(minbits(fMidLanes(gBits) + 1) - 1 downto 0);
		oNewShort:       out std_logic;
		oForceSource:    out std_logic;
		oValid:          out std_logic;
		oFlag:           out std_logic;

		iReady:          in  std_logic
	);
end entity;

architecture behavioral of tpiu_packer_scheduler is
	constant cLanes: positive := fInLanes(gBits);
	constant cMidLanes: positive := fMidLanes(gBits);
	constant cWordsPerFrame: positive := 128 / gBits;
	constant cFlushBits: positive := gFlushBits + minbits(cWordsPerFrame); -- extend flush counter so it's in units of packets instead of words
	function fAlwaysShort return std_logic is
	begin
		if cWordsPerFrame = 1 then
			return '1';
		else
			return '0';
		end if;
	end function;

	type tGeneralBus is array(natural range <>) of std_logic_vector(8 downto 0);

	subtype tBusCount is unsigned(minbits(cLanes + 1) - 1 downto 0);
	subtype tBusIndex is unsigned(minbits(cLanes) - 1 downto 0);
	subtype tBusSwizzle is unsigned(minbits(cLanes + 1) - 1 downto 0);
	subtype tBus is tGeneralBus(cLanes - 1 downto 0);

	subtype tMidBusCount is unsigned(minbits(cMidLanes + 1) - 1 downto 0);

	type tSource is ( cSourceData, cSourceFlush, cSourceSync );

	type tState is record
		-- state machine registers
		out_short:                      std_logic;
		new_word_count:                 unsigned(minbits(cWordsPerFrame) - 1 downto 0);
		new_short:                      std_logic;
		flush_counter:                  unsigned(cFlushBits - 1 downto 0);
		sync:                           std_logic;
		source:                         tSource;
		-- precomputed stuff, intended to make the oReady logic as fast as possible
		new_size_e1:                    tBusCount;
		out_short_e1:                   std_logic;
		new_short_e1:                   std_logic;
		out_valid_e1:                   std_logic;
		out_flag_e1:                    std_logic;
		out_old_valid_e1:               tMidBusCount;
		-- output control registers
		out_valid:                      std_logic;
		out_flag:                       std_logic;
		out_old_valid:                  tMidBusCount;
		out_force_source:               std_logic;
		-- output data registers
		out_data:                       tBus;
		out_source:                     std_logic_vector(6 downto 0);
	end record;

	constant cStateRst: tState := (
		out_short                       => fAlwaysShort,
		new_word_count                  => to_unsigned(1 mod cWordsPerFrame, minbits(cWordsPerFrame)),
		new_short                       => fAlwaysShort,
		flush_counter                   => (others => '0'),
		sync                            => '0',
		source                          => cSourceFlush,
		new_size_e1                     => to_unsigned(cLanes, minbits(cLanes + 1)),
		out_short_e1                    => '1',
		new_short_e1                    => fAlwaysShort,
		out_valid_e1                    => '0',
		out_flag_e1                     => '0',
		out_valid                       => '0',
		out_old_valid_e1                => (others => '0'),
		out_flag                        => '0',
		out_old_valid                   => (others => '0'),
		out_force_source                => '0',
		out_data                        => (others => (others => 'U')),
		out_source                      => (others => 'U')
	);

	signal wState:                     tState;
	signal rState:                     tState := cStateRst;

	signal wInData:                    tBus;
	signal wOutData:                   tBus;

begin

	pComb: process(rState, iReady, iFlushInterval, iFlushSource, iSyncSource, iSync, wInData, iValid, iSource, iForceSource)
		variable vState:                tState;
		variable vFlushSize:            tMidBusCount;
		variable vFlush:                std_logic;

	begin
		vState                          := rState;
		vFlushSize                      := (others => 'U');
		vFlush                          := 'U';

		if iReady = '0' then
			oReady                       <= '0';
			wOutData                     <= (others => (others => 'U'));
			oSource                      <= (others => 'U');
			oValid                       <= 'U';
			oFlag                        <= 'U';
			oOldValid                    <= (others => 'U');
			oNewShort                    <= 'U';
			oForceSource                 <= 'U';
		else
			if rState.out_old_valid_e1 >= rState.new_size_e1 or rState.sync = '1' then
				oReady                    <= '0';
			else
				oReady                    <= '1';
			end if;

			if rState.out_short_e1 = '1' and (rState.out_valid_e1 = '1' or rState.out_old_valid_e1 = 0 or rState.source /= cSourceData) then
				-- the flush counter is reset if any of the following is true
				--  - we have just output the last word of a frame
				--  - the last valid word finished a frame and we have no pending data
				--  - the last valid word finished a frame and we only have padding zeros left to output
				vState.flush_counter      := iFlushInterval & not to_unsigned(0, cFlushBits - gFlushBits);
				vFlush                    := '0';
			elsif rState.flush_counter = 0 then
				vFlush                    := '1';
			else
				vState.flush_counter      := rState.flush_counter - 1;
				vFlush                    := '0';
			end if;

			if rState.out_old_valid_e1 >= rState.new_size_e1 then
				vFlushSize                := (others => 'U');
			elsif rState.out_old_valid_e1 = rState.new_size_e1 - 1 then
				vFlushSize                := to_unsigned(1, vFlushSize'length);
			else
				vFlushSize                := to_unsigned(0, vFlushSize'length);
			end if;

			if rState.out_old_valid_e1 >= rState.new_size_e1 then
				-- we already have enough data for a new output word, so no new data is required
				vState.out_old_valid_e1   := rState.out_old_valid_e1 - rState.new_size_e1;
				vState.out_valid_e1       := '1';
				vState.out_data           := (others => (others => 'U'));
				vState.out_source         := (others => 'U');
				vState.out_force_source   := 'U';
			elsif rState.sync = '1' then
				-- respond to an external synchronization signal
				vState.out_force_source   := '1';
				vState.out_data           := (others => (others => '0'));
				vState.out_source         := iSyncSource;
				vState.source             := cSourceSync;
				vState.sync               := '0';
				vState.out_old_valid_e1   := vFlushSize;
				vState.out_valid_e1       := '1';
			elsif iValid /= 0 then
				-- use input data
				vState.out_data           := wInData;
				vState.out_source         := iSource;
				vState.source             := cSourceData;

				-- hack: if we're on the flush channel, make sure we don't send all
				-- zero bytes. This is done to avoid ever outputting a frame
				-- consisting only of zero bytes on the zero channel, because this
				-- confuses the decoder. It assumes that after such a sequence, the
				-- first non-zero byte marks the start of a new frame, which is
				-- apparently correct for some trace hardware. Note that if the
				-- first lane is a source change, the LSB is going to get ignored,
				-- so it doesn't matter that we change it here.
				if unsigned(iSource) = 0 then
					vState.out_data(0)(0)  := '1';
				end if;

				if (iForceSource = '1' or rState.source /= cSourceData) and wInData(0)(8) = '0' then
					vState.out_old_valid_e1 := rState.out_old_valid_e1 + iValid + 1;
					vState.out_force_source := '1';
				else
					vState.out_old_valid_e1 := rState.out_old_valid_e1 + iValid;
					vState.out_force_source := '0';
				end if;

				if vState.out_old_valid_e1 >= rState.new_size_e1 then
					vState.out_valid_e1    := '1';
					vState.out_old_valid_e1 := vState.out_old_valid_e1 - rState.new_size_e1;
				else
					vState.out_valid_e1    := '0';
				end if;
			elsif vFlush = '1' then
				vState.out_data           := (others => (others => '0'));
				vState.out_source         := iFlushSource;
				vState.source             := cSourceFlush;
				vState.out_valid_e1       := '1';

				if rState.source /= cSourceFlush then
					vState.out_force_source := '1';
					vState.out_old_valid_e1 := vFlushSize;
				else
					vState.out_force_source := '0';
					vState.out_old_valid_e1 := (others => '0');
				end if;
			else
				vState.out_valid_e1       := '0';
				vState.out_data           := (others => (others => 'U'));
				vState.out_source         := (others => '0');
				vState.out_force_source   := '0';
			end if;

			if vState.out_valid_e1 = '1' then
				vState.out_flag_e1        := rState.new_short_e1;
				vState.out_short_e1       := rState.new_short_e1;
				if ('0' & rState.new_word_count) = cWordsPerFrame - 1 then
					vState.new_word_count  := (others => '0');
					vState.new_short_e1    := '1';
				else
					vState.new_word_count  := rState.new_word_count + 1;
					vState.new_short_e1    := '0';
				end if;
			else
				vState.out_flag_e1        := not rState.out_short_e1;
			end if;

			if vState.new_short_e1 = '1' and fAlwaysShort = '0' then
				vState.new_size_e1        := to_unsigned(cLanes - 1, vState.new_size_e1'length);
			else
				vState.new_size_e1        := to_unsigned(cLanes, vState.new_size_e1'length);
			end if;

			vState.out_short             := rState.out_short_e1;
			vState.new_short             := rState.new_short_e1;
			vState.out_valid             := rState.out_valid_e1;
			vState.out_flag              := rState.out_flag_e1;
			vState.out_old_valid         := rState.out_old_valid_e1;

			wOutData                     <= rState.out_data;
			oSource                      <= rState.out_source;
			oValid                       <= rState.out_valid;
			oFlag                        <= rState.out_flag;
			oOldValid                    <= rState.out_old_valid;
			oNewShort                    <= rState.new_short;
			oForceSource                 <= rState.out_force_source;
		end if;

		if iSync = '1' then
			vState.sync                  := '1';
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
		wInData(i) <= iData((i + 1) * 9 - 1 downto i * 9) when is_defined(iValid) and i < iValid else (others => 'U');
	end generate;
end architecture;
