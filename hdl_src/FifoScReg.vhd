library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Device-agnostic small streaming FIFO.
--
-- FifoScReg stands for FIFO Single Clock Register-based.
--
-- The idea behind this implementation is to avoid the large output multiplexer
-- needed with a normal FIFO by instead using a shift register approach.
-- Every register stage or tile has an input selector that selects between
-- either the FIFO entity input or the output of the next tile based on the
-- own valid flag and that of the predecessor and successor tiles.
-- The selector and shift register approach has the benefit of an (almost)
-- constant critical logic path, independent of the FIFO depth.
-- The trade-off, however, is that the fan-out of the data input signals
-- increases linearily with the FIFO depth.
--
-- Instead of a read and write counter, we maintain a valid flag for each
-- position ("tile") in the FIFO. Data is always written such that there is no
-- gap in the shift register: If tile i is valid, then tile (i - 1) is also
-- valid.
--
-- This means:
--
--  - All outputs are registered.
--  - If the FIFO is empty, any data on iValid/iData will appear at the output
--    in the next cycle.
--  - Any depth is possible, not just powers of two.
--  - The FIFO does not keep a binary count of its fill level. If needed, this
--    has to be added by monitoring the ready/valid port of both interfaces.

entity FifoScReg is
	generic (
		gBits:      natural;
		gDepth:     natural  -- at least 2
	);
	port (
		iRst:   in  std_logic;
		iClk:   in  std_logic;

		oReady: out std_logic;
		iValid: in  std_logic;
		iData:  in  std_logic_vector(gBits - 1 downto 0);

		iReady: in  std_logic;
		oValid: out std_logic;
		oData:  out std_logic_vector(gBits - 1 downto 0)
	);
end entity;

architecture behavioral of FifoScReg is
	type tTile is record
		valid:  std_logic; -- this tile holds valid data
		data:   std_logic_vector(gBits - 1 downto 0);
	end record;

	constant cTileInitial: tTile := (
		valid   => '0',
		data    => (others => '0')
	);

	type tTileArray is array(gDepth - 1 downto 0) of tTile;

	type tState is record
		tiles:  tTileArray;
	end record;

	constant cStateInitial: tState := (
		tiles   => (others => cTileInitial)
	);

	signal wState: tState;
	signal rState: tState := cStateInitial;

begin
	pCombinatorial: process(rState, iValid, iData, iReady)
	begin
		wState <= rState;

		for i in gDepth - 1 downto 0 loop
			if i = 0 then
				if rState.tiles(i).valid = '0' or (iReady = '1' and rState.tiles(i + 1).valid = '0') then
					wState.tiles(i).valid <= iValid;
					wState.tiles(i).data  <= iData;
				elsif iReady = '1' then
					wState.tiles(i).valid <= rState.tiles(i + 1).valid;
					wState.tiles(i).data  <= rState.tiles(i + 1).data;
				end if;
			elsif i = gDepth - 1 then
				if rState.tiles(i).valid = '0' or iReady = '1' then
					wState.tiles(i).data  <= iData;
				end if;

				if iReady = '0' and rState.tiles(i).valid = '0' then
					wState.tiles(i).valid <= iValid and rState.tiles(i - 1).valid;
				elsif iReady = '1' then
					wState.tiles(i).valid <= '0'; -- NOT iValid: if the FIFO is full, it does not accept data even if it is read in the same cycle
				end if;
			else
				if rState.tiles(i).valid = '0' or (iReady = '1' and rState.tiles(i + 1).valid = '0') then
					wState.tiles(i).data  <= iData;
				elsif iReady = '1' then
					wState.tiles(i).data  <= rState.tiles(i + 1).data;
				end if;

				if iReady = '0' and rState.tiles(i - 1).valid = '1' and rState.tiles(i).valid = '0' then
					wState.tiles(i).valid <= iValid;
				elsif iReady = '1' and rState.tiles(i).valid = '1' and rState.tiles(i + 1).valid = '0' then
					wState.tiles(i).valid <= iValid;
				elsif iReady = '1' then
					wState.tiles(i).valid <= rState.tiles(i + 1).valid;
				end if;
			end if;
		end loop;
	end process;

	oReady <= not rState.tiles(gDepth - 1).valid;
	oValid <= rState.tiles(0).valid;
	oData  <= rState.tiles(0).data;

	pSequential: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState <= cStateInitial;
		elsif rising_edge(iClk) then
			rState <= wState;
		end if;
	end process;
end architecture;
