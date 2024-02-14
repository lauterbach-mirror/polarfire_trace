library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4_fic1_from_mss_pkg;

entity axi_to_pti is
	port (
		iRst:       in  std_logic;
		iClk:       in  std_logic;

		iMosi:      in  axi4_fic1_from_mss_pkg.tMOSI;
		oMiso:      out axi4_fic1_from_mss_pkg.tMISO;

		oTraceClk:  out std_logic;
		oTraceData: out std_logic_vector(15 downto 0)
	);
end entity;

architecture behavioral of axi_to_pti is
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

	signal wPackedData:         std_logic_vector(63 downto 0);
	signal wPackedReady:        std_logic;

	signal wReadData:           std_logic_vector(15 downto 0);

begin
	-- Convert AXI memory-mapped write channel to stream with individual data
	-- beats. Mark beats that are aligned to a 1-KiB boundary and should
	-- therefore be guaranteed to be the start of an UltraSoc message. Assumes
	-- that SMB writes data strictly in order.
	sAxiToFifo: entity work.axi4_fic1_from_mss_to_stream port map (
		iRst            => iRst,
		iClk            => iClk,

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
		iClk            => iClk,

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
		iClk            => iClk,

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
		iClk            => iClk,
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

	-- If we want an async clock crossing, this would be the logical place to
	-- insert it; Make sure the bandwidth on the write side is at least as high
	-- as the bandwidth on the read side because there's no "valid" signal here.

	sReader: entity work.tpiu_output_fifo_reader generic map (
		gInBits         => 64,
		gOutBits        => 16
	) port map (
		iClk            => iClk,
		iRst            => iRst,

		iData           => wPackedData,
		oReady          => wPackedReady,

		oData           => wReadData
	);

	sDdr: entity work.tpiu_ddr_halfspeed generic map (
		gOutBits        => 16
	) port map (
		iClk            => iClk,
		iRst            => iRst,

		iData           => wReadData,

		oData           => oTraceData,
		oClk            => oTraceClk
	);
end architecture;
