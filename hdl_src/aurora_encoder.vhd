library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.util_pkg.all;

entity aurora_encoder is
	generic (
		gLanes:             positive;
		gBytesPerLane:      positive -- must be 2 or 4
	);
	port (
		iClk:               in  std_logic;
		iRst:               in  std_logic;

		iData:              in  std_logic_vector(8 * gBytesPerLane * gLanes - 1 downto 0);
		iValid:             in  std_logic;
		iLast:              in  std_logic;
		iEmpty:             in  std_logic_vector(gBytesPerLane / 2 * gLanes - 1 downto 0);
		oReady:             out std_logic;

		oData:              out std_logic_vector(8 * gBytesPerLane * gLanes - 1 downto 0);
		oDataK:             out std_logic_vector(gBytesPerLane * gLanes - 1 downto 0)
	);
end entity;

architecture behavioral of aurora_encoder is
	constant cBytesPerLaneMustBeEven: positive := 1 - gBytesPerLane mod 2; -- error if gBytesPerLane is odd
	constant cSymbolsPerLane: positive := gBytesPerLane / 2;
	constant cSymbols: positive := gLanes * cSymbolsPerLane;

	type tArray is array(natural range <>) of std_logic_vector(15 downto 0);

	-- There are two data pipeline stages at the input so we can keep the
	-- control logic (especially oReady) as simple as possible.
	--
	-- After an input beat with iLast = '1', the next two cycles always have
	-- oReady set to '0'.

	type tPacketState is (
		cIdle,
		cInside,
		cLast
	);

	type tState is record
		cc_schedule:        unsigned(minbits(10000 / gBytesPerLane) - 1 downto 0);
		cc_remaining:       unsigned(2 downto 0);

		ready:              std_logic;

		data_in:            tArray(cSymbols - 1 downto 0);
		valid_in:           std_logic;
		last_in:            std_logic;
		empty_in:           std_logic_vector(cSymbols - 1 downto 0);

		packet_state:       tPacketState;

		-- data, data_k and data_idle are ordered in "logical" order, i.e. the
		-- order before striping occurs. data_k and data_idle apply to 16-bit
		-- symbols.
		data:               tArray(cSymbols - 1 downto 0);
		data_k:             std_logic_vector(cSymbols - 1 downto 0);
		data_idle:          std_logic_vector(cSymbols - 1 downto 0);

		-- data_out and data_out_k are in striped order, with the lowest indices
		-- corresponding to lane 0, then lane 1 and so on. data_out_k applies to
		-- 8-bit bytes.
		data_out:           std_logic_vector(16 * cSymbols - 1 downto 0);
		data_out_k:         std_logic_vector(2 * cSymbols - 1 downto 0);
	end record;

	constant cStateInit:   tState := (
		cc_schedule         => (others => '0'),
		cc_remaining        => (others => '0'),
		ready               => '1',
		data_in             => (others => (others => 'U')),
		valid_in            => '0',
		last_in             => 'U',
		empty_in            => (others => 'U'),
		packet_state        => cIdle,
		data                => (others => (others => '0')),
		data_k              => (others => '0'),
		data_idle           => (others => '0'),
		data_out            => (others => '0'),
		data_out_k          => (others => '0')
	);

	signal rState:         tState := cStateInit;
	signal wState:         tState;

	signal wInData:        tArray(cSymbols - 1 downto 0);
	signal wIdleDataRaw:   std_logic_vector(8 * gBytesPerLane - 1 downto 0);
	signal wIdleData:      tArray(cSymbolsPerLane - 1 downto 0);

begin
	sIdleGenerator: entity work.aurora_idle_generator generic map (
		gBytesPerLane             => gBytesPerLane
	) port map (
		iClk                      => iClk,
		oData                     => wIdleDataRaw
	);

	eIdleData: for i in cSymbolsPerLane - 1 downto 0 generate
		wIdleData(i)        <= wIdleDataRaw((i + 1) * 16 - 1 downto i * 16);
	end generate;

	pCombinatorial: process(rState, wInData, wIdleData, iData, iValid, iLast, iEmpty)
		variable vIndexA:   natural;
		variable vIndexB:   natural;

	begin
		wState              <= rState;

		wState.data         <= (others => (others => '0'));
		wState.data_k       <= (others => '1');
		wState.data_idle    <= (others => '1');

		if iValid = '1' and rState.ready = '1' then
			wState.valid_in  <= '1';
			wState.data_in   <= wInData;
			wState.last_in   <= iLast;
			wState.empty_in  <= iEmpty;
		else
			wState.valid_in  <= '0';
			wState.data_in   <= (others => (others => 'U'));
			wState.last_in   <= 'U';
			wState.empty_in  <= (others => 'U');
		end if;

		if rState.valid_in = '1' then
			for i in cSymbols - 1 downto 0 loop
				if rState.empty_in(i) = '0' then
					wState.data(i) <= rState.data_in(i);
					wState.data_k(i) <= '0';
					wState.data_idle(i) <= '0';
				else
					wState.data(i) <= (others => 'U');
					wState.data_k(i) <= '1';
					wState.data_idle(i) <= '1';
				end if;
			end loop;

			if rState.last_in = '1' then
				wState.packet_state <= cLast;
			end if;
		elsif rState.packet_state = cLast then
			-- /ECP/ == /K29.7/K30.7/ == 0xFD 0xFE
			wState.data(0)   <= x"FEFD";
			wState.data_idle(0) <= '0';
			wState.packet_state <= cIdle;
		elsif rState.packet_state = cIdle and iValid = '1' and rState.ready = '1' then
			-- /SCP/ == /K28.2/K27.7/ == 0x5C 0xFB
			wState.data(0)   <= x"FB5C";
			wState.data_idle(0) <= '0';
			wState.packet_state <= cInside;
		elsif rState.cc_remaining /= 0 then
			-- /CC/ == /K23.7/K23.7/ == 0xF7 0xF7
			wState.data      <= (others => x"F7F7");
			wState.data_idle <= (others => '0');
			wState.cc_remaining <= rState.cc_remaining - 1;
		else
			-- /IDLE/
		end if;

		if iValid = '1' and rState.ready = '1' and iLast = '1' then
			-- reserve a clock cycle for the /ECP/
			wState.ready     <= '0';
		elsif rState.valid_in = '1' and rState.last_in = '1' then
			-- reserve a clock cycle for the /SCP/
			wState.ready     <= '0';
		elsif rState.cc_remaining > 2 or (rState.packet_state = cIdle and rState.cc_remaining > 1) then
			-- reserve clock cycles for /CC/
			wState.ready     <= '0';
		else
			wState.ready     <= '1';
		end if;

		if rState.cc_schedule = 10000 / gBytesPerLane - 1 then
			wState.cc_schedule <= (others => '0');
			wState.cc_remaining <= to_unsigned(12 / gBytesPerLane, wState.cc_remaining'length);
		else
			wState.cc_schedule <= rState.cc_schedule + 1;
		end if;

		for i in gLanes - 1 downto 0 loop
			for j in cSymbolsPerLane - 1 downto 0 loop
				vIndexA       := i + gLanes * j;
				vIndexB       := j + cSymbolsPerLane * i;

				wState.data_out_k(2 * (vIndexB + 1) - 1 downto 2 * vIndexB) <= (others => rState.data_k(vIndexA));

				if rState.data_idle(vIndexA) = '1' then
					wState.data_out(16 * (vIndexB + 1) - 1 downto 16 * vIndexB) <= wIdleData(j);
				else
					wState.data_out(16 * (vIndexB + 1) - 1 downto 16 * vIndexB) <= rState.data(vIndexA);
				end if;
			end loop;
		end loop;
	end process;

	pSequential: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState           <= cStateInit;
		elsif rising_edge(iClk) then
			rState           <= wState;
		end if;
	end process;

	eIn: for i in cSymbols - 1 downto 0 generate
		wInData(i)          <= iData(16 * (i + 1) - 1 downto 16 * i);
	end generate;

	oReady                 <= rState.ready;
	oData                  <= rState.data_out;
	oDataK                 <= rState.data_out_k;
end architecture;
