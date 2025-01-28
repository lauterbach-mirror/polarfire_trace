-- constraints on input data to avoid double source changes:
--
--  - no two consectutive source changes are allowed in a single input packet
--  - the last valid lane of a packet may never be a source change
--  - if the first lane is valid and a source change, iForceSource and iSource are ignored

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.util_pkg.minbits;
use work.tpiu_packer_pkg.fInLanes;
use work.tpiu_packer_pkg.fOutLanes;
use work.tpiu_packer_pkg.fMidLanes;

entity tpiu_packer is
	generic (
		gBits:           positive; -- at least 32, at most 128, power of two; TODO: deal with the special cases of 16 or 8 bits, because can be implemented far more efficiently than large port widths
		gSyncBits:       positive;
		gFlushBits:      positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		-- configuration inputs; these are expected to be mostly static;
		-- changing these values while data is processed may produce strange results, but the unit should recover quickly
		iSyncInterval:   in  unsigned(gSyncBits - 1 downto 0);  -- in units of 16 bytes, actual interval is one more than this value: distance between two opportunistic syncs (outputting a sync packet when the end of a packet is reached)
		iFlushInterval:  in  unsigned(gFlushBits - 1 downto 0); -- in units of 16 bytes, actual interval is one more than this value: maximum number of idle cycles before the current packet is filled with zeros for flushing
		iFlushSource:    in  std_logic_vector(6 downto 0);      -- source used for flushing; setting this to non-zero can be useful to distinguish ARM CoreSight TPIU flushes from flushes performed by this implementation
		iSyncSource:     in  std_logic_vector(6 downto 0);      -- source used for indicating external timer sync events

		iSync:           in  std_logic := '0';
		iData:           in  std_logic_vector(fInLanes(gBits) * 9 - 1 downto 0);
		iValid:          in  unsigned(minbits(fInLanes(gBits) + 1) - 1 downto 0);
		iSource:         in  std_logic_vector(6 downto 0); -- source ID of the first data byte
		iForceSource:    in  std_logic; -- whether we must output a source change before the first byte of iData; iSource must be valid even if iForceSource = '0'!
		oReady:          out std_logic;

		oData:           out std_logic_vector(gBits - 1 downto 0);
		iReady:          in  std_logic
	);

begin
	assert gBits >=  16 report "tpiu_packer argument error: gBits = " & integer'image(gBits) severity failure;
	assert gBits <= 128 report "tpiu_packer argument error: gBits = " & integer'image(gBits) severity failure;
end entity;

architecture structural of tpiu_packer is
	constant cInLanes:                 positive := fInLanes(gBits);
	constant cOutLanes:                positive := fOutLanes(gBits);
	constant cMidLanes:                positive := fMidLanes(gBits);

	-- This unit is composed of four stages which operate on the data stream and
	-- are connected in series. Each stage adds one cycle of clock delay.
	--
	-- The scheduler stage maintains the counter that counts the number of valid
	-- words in the internal buffer that is used to assemble the output. It also
	-- handles the insertion of the appropriate number of zero bytes when a
	-- partially complete packet has been in the pipeline for too long.

	-- new data and instructions what to do with it
	signal wSchedulerData:             std_logic_vector(cInLanes * 9 - 1 downto 0);
	signal wSchedulerSource:           std_logic_vector(6 downto 0);
	signal wSchedulerOldValid:         unsigned(minbits(cMidLanes + 1) - 1 downto 0); -- how many lanes are left after outputting the current word
	signal wSchedulerNewShort:         std_logic; -- '1' if the new data is being assembled into a short word (i.e. skip the auxiliary byte)
	signal wSchedulerForceSource:      std_logic;

	-- control what the next stage should do with the data it has already accumulated
	signal wSchedulerValid:            std_logic;
	signal wSchedulerFlag:             std_logic; -- if oValid = '0': '0' outputs a word filled as far as possible with full syncs, '1' outputs half syncs
	                                              -- if oValid = '1': '1' marks the word with the aux packet, '0' is a regular word

	signal wSchedulerReady:            std_logic;

	-- The control stage unpacks the instructions from the scheduler into
	-- signals that control the next stage. It also makes sure that once
	-- in a while a full sync is inserted into the output data stream,
	-- backpressuring the scheduler if necessary. Finally, it handles the
	-- special case that if the data width is 16 bits, a full sync needs
	-- a second data word.

	-- raw data
	signal wControlData:               std_logic_vector(cInLanes * 9 - 1 downto 0);
	signal wControlSource:             std_logic_vector(6 downto 0); -- effectively, the source is attached to the data so it forms index -1

	-- control bits for each lane
	signal wControlEnable:             std_logic_vector(cMidLanes - 1 downto 0);
	signal wControlMux:                std_logic_vector(cMidLanes - 1 downto 0); -- '0': shift, '1': load

	-- common control bits for each lane
	signal wControlSwizzleLow:         unsigned(minbits(cInLanes + 1) - 1 downto 0); -- how much the input data is shifted left before being loaded into the area that holds the word being currently assembled
	signal wControlSwizzleHigh:        unsigned(minbits(cInLanes + 1) - 1 downto 0); -- how much the input data is shifted left before being loaded into the area that holds the next word to be assembled

	-- output control, given directly to the next stage
	signal wControlValid:              std_logic;
	signal wControlFlag:               std_logic;

	signal wControlReady:              std_logic;

	-- The data stage has a register that can hold two words worth of data. Each
	-- input word is latched into this register at the appropriate offset, and
	-- when a complete word has been output, the data is shifted right by a
	-- fixed amount. When the word being assembled contains the auxiliary byte,
	-- which has not yet been computed at this point, its slot is left free,
	-- which avoids having to implement two separate shifters.

	signal wDataData:                  std_logic_vector(cOutLanes * 9 - 1 downto 0);
	signal wDataValid:                 std_logic;
	signal wDataFlag:                  std_logic;

	-- The output stage is responsible for assembling the auxiliary byte and for
	-- interchanging two neighboring lanes so source changes are always in even
	-- lanes.

	signal wDataReady:                 std_logic;

begin
	yScheduler: entity work.tpiu_packer_scheduler generic map (
		gBits                           => gBits,
		gFlushBits                      => gFlushBits
	) port map (
		iClk                            => iClk,
		iRst                            => iRst,
		iFlushInterval                  => iFlushInterval,
		iFlushSource                    => iFlushSource,
		iSyncSource                     => iSyncSource,
		iSync                           => iSync,
		iData                           => iData,
		iValid                          => iValid,
		iSource                         => iSource,
		iForceSource                    => iForceSource,
		oReady                          => oReady,
		oData                           => wSchedulerData,
		oSource                         => wSchedulerSource,
		oOldValid                       => wSchedulerOldValid,
		oNewShort                       => wSchedulerNewShort,
		oForceSource                    => wSchedulerForceSource,
		oValid                          => wSchedulerValid,
		oFlag                           => wSchedulerFlag,
		iReady                          => wSchedulerReady
	);

	yControl: entity work.tpiu_packer_control generic map (
		gBits                           => gBits,
		gSyncBits                       => gSyncBits
	) port map (
		iClk                            => iClk,
		iRst                            => iRst,
		iSyncInterval                   => iSyncInterval,
		iData                           => wSchedulerData,
		iSource                         => wSchedulerSource,
		iOldValid                       => wSchedulerOldValid,
		iNewShort                       => wSchedulerNewShort,
		iForceSource                    => wSchedulerForceSource,
		iValid                          => wSchedulerValid,
		iFlag                           => wSchedulerFlag,
		oReady                          => wSchedulerReady,
		oData                           => wControlData,
		oSource                         => wControlSource,
		oEnable                         => wControlEnable,
		oMux                            => wControlMux,
		oSwizzleLow                     => wControlSwizzleLow,
		oSwizzleHigh                    => wControlSwizzleHigh,
		oValid                          => wControlValid,
		oFlag                           => wControlFlag,
		iReady                          => wControlReady
	);

	yData: entity work.tpiu_packer_data generic map (
		gBits                           => gBits
	) port map (
		iClk                            => iClk,
		iRst                            => iRst,
		iData                           => wControlData,
		iSource                         => wControlSource,
		iEnable                         => wControlEnable,
		iMux                            => wControlMux,
		iSwizzleLow                     => wControlSwizzleLow,
		iSwizzleHigh                    => wControlSwizzleHigh,
		iValid                          => wControlValid,
		iFlag                           => wControlFlag,
		oReady                          => wControlReady,
		oData                           => wDataData,
		oValid                          => wDataValid,
		oFlag                           => wDataFlag,
		iReady                          => wDataReady
	);

	yOutput: entity work.tpiu_packer_output generic map (
		gBits                           => gBits
	) port map (
		iClk                            => iClk,
		iRst                            => iRst,
		iData                           => wDataData,
		iValid                          => wDataValid,
		iFlag                           => wDataFlag,
		oReady                          => wDataReady,
		oData                           => oData,
		iReady                          => iReady
	);
end architecture;
