library ieee;
use ieee.std_logic_1164.all;

use work.sim_axi_to_x_pkg;

entity sim_aurora_rx is
	generic (
		gLanes:            positive;
		gBytesPerLane:     positive
	);
	port (
		iRst:              in  std_logic;
		iClkLane:          in  std_logic;
		iClkByte:          in  std_logic;

		-- clock from receiver
		iRxClk:            in  std_logic_vector(gLanes - 1 downto 0);

		-- per-symbol data
		iRxData:           in  std_logic_vector(8 * gLanes * gBytesPerLane - 1 downto 0);
		iRxK:              in  std_logic_vector(gLanes * gBytesPerLane - 1 downto 0);
		iRxCodeViolation:  in  std_logic_vector(gLanes * gBytesPerLane - 1 downto 0);
		iRxDisparityError: in  std_logic_vector(gLanes * gBytesPerLane - 1 downto 0);

		-- sideband signals from receiver
		iRxReady:          in  std_logic_vector(gLanes - 1 downto 0); -- async!
		iRxVal:            in  std_logic_vector(gLanes - 1 downto 0);

		-- decoded payload data, synchronous to iClkByte
		oValid:            out std_logic;
		oData:             out std_logic_vector(7 downto 0)
	);
end entity;

architecture behavioral of sim_aurora_rx is
	signal wRxData:     sim_axi_to_x_pkg.tData(gLanes * gBytesPerLane - 1 downto 0);

	signal wDesValid:   std_logic_vector(gLanes - 1 downto 0);
	signal wDesK:       std_logic_vector(gLanes - 1 downto 0);
	signal wDesData:    sim_axi_to_x_pkg.tData(gLanes - 1 downto 0);

	signal wBondValid:  std_logic;
	signal wBondK:      std_logic_vector(gLanes - 1 downto 0);
	signal wBondData:   sim_axi_to_x_pkg.tData(gLanes - 1 downto 0);

	signal wAlignValid: std_logic;
	signal wAlignData:  std_logic_vector(7 downto 0);

begin
	eBytes: for i in gLanes * gBytesPerLane - 1 downto 0 generate
		wRxData(i) <= iRxData((i + 1) * 8 - 1 downto i * 8);
	end generate;

	eLanes: for i in gLanes - 1 downto 0 generate
		sDeserialize: entity work.sim_rcvr_deserialize generic map (
			gBytesPerLane => gBytesPerLane
		) port map (
			iRst => iRst,

			iRxClk => iRxClk(i),

			iRxData           => wRxData          ((i + 1) * gBytesPerLane - 1 downto i * gBytesPerLane),
			iRxK              => iRxK             ((i + 1) * gBytesPerLane - 1 downto i * gBytesPerLane),
			iRxCodeViolation  => iRxCodeViolation ((i + 1) * gBytesPerLane - 1 downto i * gBytesPerLane),
			iRxDisparityError => iRxDisparityError((i + 1) * gBytesPerLane - 1 downto i * gBytesPerLane),

			iRxReady          => iRxReady(i),
			iRxVal            => iRxVal(i),

			iOutClk           => iClkLane,
			oOutValid         => wDesValid(i),
			oOutK             => wDesK(i),
			oOutData          => wDesData(i)
		);
	end generate;

	sBond: entity work.sim_rcvr_bond generic map (
		gLanes               => gLanes
	) port map (
		iRst                 => iRst,
		iClkLane             => iClkLane,

		iInValid             => wDesValid,
		iInK                 => wDesK,
		iInData              => wDesData,

		oOutValid            => wBondValid,
		oOutK                => wBondK,
		oOutData             => wBondData
	);

	sAlign: entity work.sim_rcvr_align generic map (
		gLanes               => gLanes
	) port map (
		iRst                 => iRst,
		iClkLane             => iClkLane,
		iClkByte             => iClkByte,

		iInValid             => wBondValid,
		iInK                 => wBondK,
		iInData              => wBondData,

		oOutValid            => wAlignValid,
		oOutData             => wAlignData
	);

	sDecode: entity work.sim_tpiu_decode port map (
		iRst                 => iRst,
		iClkByte             => iClkByte,

		iInValid             => wAlignValid,
		iInData              => wAlignData,

		oOutValid            => oValid,
		oOutData             => oData
	);
end architecture;
