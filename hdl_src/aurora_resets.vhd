library ieee;
use ieee.std_logic_1164.all;

entity aurora_resets is
	port (
		iRst:           in  std_logic;
		iClkAxi:        in  std_logic;
		iClkUser:       in  std_logic;

		iPllLock:       in  std_logic;
		iClkUserStable: in  std_logic;

		oRstUser:       out std_logic;
		oPcsRstN:       out std_logic;
		oPmaRstN:       out std_logic
	);
end entity;

architecture behavioral of aurora_resets is
	signal wRstAxi:  std_logic;
	signal rRstAxi:  std_logic_vector(3 downto 0) := (others => '0');

	signal wRstUser: std_logic;
	signal rRstUser: std_logic_vector(3 downto 0) := (others => '0');

begin
	wRstAxi <= iRst or not iPllLock;
	pRstAxi: process(wRstAxi, iClkAxi)
	begin
		if wRstAxi = '1' then
			rRstAxi <= (others => '0');
		elsif rising_edge(iClkAxi) then
			rRstAxi <= '1' & rRstAxi(rRstAxi'high downto 1);
		end if;
	end process;

	-- These are supposedly synchronized inside the receiver, so it should be ok
	-- to drive them with an unrelated clock. Don't use iClkUser or
	-- iClkUserStable here because I'm not sure whether these are affected by
	-- one of the resets. iPllLock should definitely not be affected because
	-- that PLL isa separate primitive from the transceiver itself.
	oPcsRstN <= rRstAxi(0);
	oPmaRstN <= rRstAxi(0);

	wRstUser <= not rRstAxi(0) or not iClkUserStable;
	pRstUser: process(wRstUser, iClkUser)
	begin
		if wRstUser = '1' then
			rRstUser <= (others => '0');
		elsif rising_edge(iClkUser) then
			rRstUser <= '1' & rRstUser(rRstUser'high downto 1);
		end if;
	end process;

	-- oRstUser deasserts synchronously to iClkUser after that clock is
	-- supposedly stable.
	oRstUser <= not rRstUser(0);
end architecture;
