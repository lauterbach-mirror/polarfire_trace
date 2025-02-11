library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4_fic1_from_mss_pkg;

entity axi_to_aurora_impl is
	generic (
		gLanes:         positive := 1 -- must be 1 or 2
	);
	port (
		iRst:           in  std_logic;
		iClkAxi:        in  std_logic;

		iMosi:          in  axi4_fic1_from_mss_pkg.tMOSI;
		oMiso:          out axi4_fic1_from_mss_pkg.tMISO;

		iClkUser:       in  std_logic_vector(gLanes - 1 downto 0);
		iClkUserStable: in  std_logic_vector(gLanes - 1 downto 0);
		iPllLock:       in  std_logic;

		oPhyRstN:       out std_logic;
		oTxData:        out std_logic_vector(31 downto 0);
		oTxK:           out std_logic_vector( 3 downto 0)
	);
end entity;

architecture behavioral of axi_to_aurora_impl is
	constant cBytesPerLane:     positive := 4 / gLanes;

	signal wRstUser:            std_logic;

	signal wAxiStreamReady:     std_logic;
	signal wAxiStreamValid:     std_logic;
	signal wAxiStreamAligned:   std_logic;
	signal wAxiStreamStrb:      std_logic_vector( 7 downto 0);
	signal wAxiStreamData:      std_logic_vector(63 downto 0);

	signal wCompressedReady:    std_logic;
	signal wCompressedValidCnt: unsigned(3 downto 0);
	signal wCompressedAligned:  std_logic;
	signal wCompressedData:     std_logic_vector(63 downto 0);

	signal wSyncedReady:        std_logic;
	signal wSyncedValidCnt:     unsigned(3 downto 0);
	signal wSyncedForceSource:  std_logic;
	signal wSyncedData:         std_logic_vector(63 downto 0);

	signal wSyncedDataFlag:     std_logic_vector(71 downto 0);

	signal wPackedReady:        std_logic;
	signal wPackedData:         std_logic_vector(63 downto 0);

	signal wUserFifoReady:      std_logic;
	signal wUserFifoValid:      std_logic;
	signal wUserFifoData:       std_logic_vector(63 downto 0);

	signal wFramedReady:        std_logic;
	signal wFramedValid:        std_logic;
	signal wFramedLast:         std_logic;
	signal wFramedData:         std_logic_vector(31 downto 0);

	signal wTxData:             std_logic_vector(31 downto 0);
	signal wTxK:                std_logic_vector( 3 downto 0);

begin
	-- Convert AXI memory-mapped write channel to stream with individual data
	-- beats. Mark beats that are aligned to a 1-KiB boundary and should
	-- therefore be guaranteed to be the start of an UltraSoc message. Assumes
	-- that SMB writes data strictly in order.
	sAxiToFifo: entity work.axi4_fic1_from_mss_to_stream port map (
		iRst            => iRst,
		iClk            => iClkAxi,

		iMosi           => iMosi,
		oMiso           => oMiso,

		iStreamReady    => wAxiStreamReady,
		oStreamValid    => wAxiStreamValid,
		oStreamAligned  => wAxiStreamAligned,
		oStreamStrb     => wAxiStreamStrb,
		oStreamData     => wAxiStreamData
	);

	-- Move non-64-bit beats to the least significant lanes.
	sCompress: entity work.smb_compress port map (
		iRst            => iRst,
		iClk            => iClkAxi,

		oInReady        => wAxiStreamReady,
		iInValid        => wAxiStreamValid,
		iInAligned      => wAxiStreamAligned,
		iInStrb         => wAxiStreamStrb,
		iInData         => wAxiStreamData,

		iOutReady       => wCompressedReady,
		oOutValidCnt    => wCompressedValidCnt,
		oOutAligned     => wCompressedAligned,
		oOutData        => wCompressedData
	);

	-- Insert forced ID change and 32 0x00 Bytes before each aligned write.
	sSync: entity work.smb_sync port map (
		iRst            => iRst,
		iClk            => iClkAxi,

		oInReady        => wCompressedReady,
		iInValidCnt     => wCompressedValidCnt,
		iInAligned      => wCompressedAligned,
		iInData         => wCompressedData,

		iOutReady       => wSyncedReady,
		oOutValidCnt    => wSyncedValidCnt,
		oOutForceSource => wSyncedForceSource,
		oOutData        => wSyncedData
	);

	-- Insert fixed marker bits because we never output any ID change.
	wSyncedDataFlag( 8 downto  0) <= '0' & wSyncedData( 7 downto  0);
	wSyncedDataFlag(17 downto  9) <= '0' & wSyncedData(15 downto  8);
	wSyncedDataFlag(26 downto 18) <= '0' & wSyncedData(23 downto 16);
	wSyncedDataFlag(35 downto 27) <= '0' & wSyncedData(31 downto 24);
	wSyncedDataFlag(44 downto 36) <= '0' & wSyncedData(39 downto 32);
	wSyncedDataFlag(53 downto 45) <= '0' & wSyncedData(47 downto 40);
	wSyncedDataFlag(62 downto 54) <= '0' & wSyncedData(55 downto 48);
	wSyncedDataFlag(71 downto 63) <= '0' & wSyncedData(63 downto 56);

	sPacker: entity work.tpiu_packer generic map (
		gBits           => 64,
		gSyncBits       => 8,
		gFlushBits      => 8
	) port map (
		iClk            => iClkAxi,
		iRst            => iRst,

		iSyncInterval   => x"FF",
		iFlushInterval  => x"FF",
		iFlushSource    => "0000000",
		iSyncSource     => "1000000", -- should never be used

		iSync           => '0',
		iData           => wSyncedDataFlag,
		iValid          => wSyncedValidCnt,
		iSource         => "0000001",
		iForceSource    => wSyncedForceSource,
		oReady          => wSyncedReady,

		oData           => wPackedData,
		iReady          => wPackedReady
	);

	sFifo: entity work.FifoDcReg generic map (
		gBits           => 64,
		gLdDepth        => 3
	) port map (
		iRst            => iRst,

		iWrClk          => iClkAxi,
		oReady          => wPackedReady,
		iValid          => '1',
		iData           => wPackedData,

		iRdClk          => iClkUser(0),
		iReady          => wUserFifoReady,
		oValid          => wUserFifoValid,
		oData           => wUserFifoData
	);

	sFrame: entity work.aurora_frame port map (
		iClk            => iClkUser(0),
		iRst            => wRstUser,

		oReady          => wUserFifoReady,
		iValid          => wUserFifoValid,
		iData           => wUserFifoData,

		iReady          => wFramedReady,
		oValid          => wFramedValid,
		oLast           => wFramedLast,
		oData           => wFramedData
	);

	sEncoder: entity work.aurora_encoder generic map (
		gLanes          => gLanes,
		gBytesPerLane   => cBytesPerLane
	) port map (
		iClk            => iClkUser(0),
		iRst            => wRstUser,

		oReady          => wFramedReady,
		iValid          => wFramedValid,
		iLast           => wFramedLast,
		iEmpty          => (others => '0'),
		iData           => wFramedData,

		oData           => wTxData,
		oDataK          => wTxK
	);

	sResets: entity work.aurora_resets generic map (
		gLanes          => gLanes
	) port map (
		iRst            => iRst,
		iClkAxi         => iClkAxi,
		iClkUser        => iClkUser(0),

		iPllLock        => iPllLock,
		iClkUserStable  => iClkUserStable,

		oRstUser        => wRstUser,
		oPhyRstN        => oPhyRstN
	);

	eOneLane: if gLanes = 1 generate
		-- no extra synchronization reqired, just one user clock
		oTxData <= wTxData;
		oTxK    <= wTxK;
	end generate;

	eMoreLanes: if gLanes /= 1 generate
		eLane: for i in gLanes - 1 downto 0 generate
			signal wValid: std_logic;
			signal rReady: std_logic := '0';

		begin
			sFifo: entity work.FifoDcReg generic map (
				gBits               => 18,
				gLdDepth            => 3
			) port map (
				iRst                => wRstUser,

				iWrClk              => iClkUser(0),
				oReady              => open,
				iValid              => '1',
				iData(17 downto 16) => wTxK   ( 2 * (i + 1) - 1 downto  2 * i),
				iData(15 downto  0) => wTxData(16 * (i + 1) - 1 downto 16 * i),

				iRdClk              => iClkUser(i),
				iReady              => rReady,
				oValid              => wValid,
				oData(17 downto 16) => oTxK   ( 2 * (i + 1) - 1 downto  2 * i),
				oData(15 downto  0) => oTxData(16 * (i + 1) - 1 downto 16 * i)
			);

			pReady: process(wRstUser, iClkUser(i))
			begin
				if wRstUser = '1' then
					rReady <= '0';
				elsif rising_edge(iClkUser(i)) then
					-- Start reading from FIFOs one clock after the first data so we
					-- have one extra item in flight to accomodate
					-- drift/metastability races.
					rReady <= rReady or wValid;
				end if;
			end process;
		end generate;
	end generate;
end architecture;
