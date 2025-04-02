library ieee;
use ieee.std_logic_1164.all;

entity aurora_frame is
	port (
		iClk:               in  std_logic;
		iRst:               in  std_logic;

		oReady:             out std_logic;
		iValid:             in  std_logic;
		iData:              in  std_logic_vector(63 downto 0);

		iReady:             in  std_logic;
		oValid:             out std_logic;
		oLast:              out std_logic;
		oData:              out std_logic_vector(31 downto 0)
	);
end entity;

architecture behavioral of aurora_frame is
	type tDataArray is array(natural range <>) of std_logic_vector(31 downto 0);

	type tState is record
		data:               tDataArray(3 downto 0);
		fs:                 std_logic_vector(3 downto 1);
		hs:                 std_logic_vector(3 downto 1);
		valid:              std_logic_vector(3 downto 0);
		last:               std_logic_vector(0 downto 0);
	end record;

	constant cStateInit:   tState := (
		data                => (others => (others => '0')),
		fs                  => (others => '0'),
		hs                  => (others => '0'),
		valid               => (others => '0'),
		last                => (others => '0')
	);

	signal rState:         tState := cStateInit;
	signal wState:         tState;

begin
	pCombinatorial: process(rState, iValid, iData, iReady)
	begin
		wState <= rState;

		oReady <= not rState.valid(3);
		oValid <= rState.valid(0);
		oLast <= rState.last(0);
		oData <= rState.data(0);

		if rState.valid(0) = '1' and iReady = '0' then
			oReady <= '0';
		elsif rState.valid(3) = '0' and iValid = '0' then
			oValid <= '0';
		else
			wState.data(3) <= iData(63 downto 32);
			wState.fs(3) <= '0';
			wState.hs(3) <= '0';
			if iData(63 downto 32) = x"7FFFFFFF" then
				wState.fs(3) <= '1';
			elsif iData(63 downto 32) = x"7FFF7FFF" then
				wState.hs(3) <= '1';
			end if;

			if rState.valid(3) = '0' then
				wState.data(2) <= iData(31 downto  0);
				wState.fs(2) <= '0';
				wState.hs(2) <= '0';
				if iData(31 downto  0) = x"7FFFFFFF" then
					wState.fs(2) <= '1';
				elsif iData(31 downto  0) = x"7FFF7FFF" then
					wState.hs(2) <= '1';
				end if;

				wState.valid(3 downto 2) <= "11";
			else
				wState.data(2)  <= rState.data(3);
				wState.fs(2)    <= rState.fs(3);
				wState.hs(2)    <= rState.hs(3);
				wState.valid(3 downto 2) <= "01";
			end if;

			wState.data(1)  <= rState.data(2);
			wState.fs(1)    <= rState.fs(2);
			wState.hs(1)    <= rState.hs(2);
			wState.valid(1) <= rState.valid(2);

			-- This only works because we know that tpiu_packer does not output
			-- full syncs followed by half syncs or vice versa.
			wState.data(0)  <= rState.data(1);
			wState.valid(0) <= rState.valid(1) and not rState.hs(1);
			wState.last(0)  <= '0';
			case rState.fs(2 downto 1) is
				when "10" =>
					-- sync follows data: mark data as end of frame
					wState.last(0) <= '1';

				when "11" =>
					-- sync follows sync: discard
					wState.valid(0) <= '0';
					wState.last(0)  <= '1'; -- don't care

				when others =>
					-- data follows data: normal case
					-- data follows sync: sync will be the start of frame
			end case;
		end if;
	end process;

	pSequential: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState <= cStateInit;
		elsif rising_edge(iClk) then
			rState <= wState;
		end if;
	end process;
end architecture;
