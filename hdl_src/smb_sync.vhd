library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity smb_sync is
	port (
		iRst:                 in  std_logic;
		iClk:                 in  std_logic;

		oInReady:             out std_logic;
		iInValidCnt:          in  unsigned(3 downto 0);
		iInAligned:           in  std_logic;
		iInData:              in  std_logic_vector(63 downto 0);

		iOutReady:            in  std_logic;
		oOutValidCnt:         out unsigned(3 downto 0);
		oOutForceSource:      out std_logic;
		oOutData:             out std_logic_vector(63 downto 0)
	);
end entity;

architecture behavioral of smb_sync is
	type tState is record
		sync_cnt:     unsigned(2 downto 0);
		valid_cnt:    unsigned(3 downto 0);
		force_source: std_logic;
		data:         std_logic_vector(63 downto 0);
	end record;

	constant cStateInitial: tState := (
		sync_cnt      => (others => '0'),
		valid_cnt     => (others => '0'),
		force_source  => '0',
		data          => (others => '0')
	);

	signal rState: tState := cStateInitial;
	signal wState: tState;

begin
	pCombinatorial: process(rState, iInValidCnt, iInAligned, iInData, iOutReady)

	begin
		wState <= rState;

		if rState.valid_cnt = 0 or iOutReady = '1' then
			if iInValidCnt /= 0 and iInAligned = '1' and rState.sync_cnt < 4 then
				oInReady <= '0';
				wState.sync_cnt <= rState.sync_cnt + 1;
				wState.valid_cnt <= to_unsigned(8, rState.valid_cnt'length);
				if rState.sync_cnt = 0 then
					wState.force_source <= '1';
				else
					wState.force_source <= '0';
				end if;
				wState.data <= (others => '0');
			else
				oInReady <= '1';
				wState.sync_cnt      <= (others => '0');
				wState.valid_cnt     <= iInValidCnt;
				wState.force_source  <= '0';
				wState.data          <= iInData;
			end if;
		else
			oInReady <= '0';
		end if;

		oOutValidCnt    <= rState.valid_cnt;
		oOutForceSource <= rState.force_source;
		oOutData        <= rState.data;
	end process;

	pSequential: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState <= cStateInitial;
		elsif rising_edge(iClk) then
			rState <= wState;
		end if;
	end process;
end architecture;
