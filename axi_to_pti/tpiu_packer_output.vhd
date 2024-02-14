library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.util_pkg.minbits;
use work.util_pkg.is_defined;
use work.tpiu_packer_pkg.fOutLanes;

-- see tpiu_packer.vhd for documentation
entity tpiu_packer_output is
	generic (
		gBits:           positive
	);
	port (
		iClk:            in  std_logic;
		iRst:            in  std_logic;

		iData:           in  std_logic_vector(fOutLanes(gBits) * 9 - 1 downto 0);
		iValid:          in  std_logic;
		iFlag:           in  std_logic;
		oReady:          out std_logic;

		oData:           out std_logic_vector(gBits - 1 downto 0);
		iReady:          in  std_logic
	);
end entity;

architecture behavioral of tpiu_packer_output is
	constant cLanes: positive := fOutLanes(gBits);

	type tInBus is array(cLanes - 1 downto 0) of std_logic_vector(8 downto 0);
	type tOutBus is array(gBits / 8 - 1 downto 0) of std_logic_vector(7 downto 0);

	function fSync(vLength: positive) return tOutBus is
		variable vRet: tOutBus;

	begin
		vRet := (others => (others => '1'));
		for i in 0 to vRet'length / vLength - 1 loop
			vRet((i + 1) * vLength - 1)(7) := '0';
		end loop;
		return vRet;
	end function;

	constant cFullSync: tOutBus := fSync(4);
	constant cHalfSync: tOutBus := fSync(2);

	type tState is record
		out_data:                       tOutBus;
		aux:                            std_logic_vector(7 - (gBits / 16) downto 0);
	end record;
	constant cStateRst: tState := (
		out_data         => cFullSync,
		aux              => (others => 'U')
	);

	signal wState: tState;
	signal rState: tState := cStateRst;

	signal wInData:                    tInBus;
	signal wOutData:                   tOutBus;

begin
	pComb: process(rState, wInData, iValid, iFlag, iReady)
		variable vState:                tState;
		variable vAux:                  std_logic_vector(gBits / 16 - 1 downto 0);
		variable vFlag:                 boolean;

	begin
		vState                          := rState;

		oReady                          <= iReady;

		vFlag                           := iFlag = '1' or gBits = 128;

		if iReady = '1' then
			wOutData                     <= rState.out_data;
			if iValid = '0' then
				if not vFlag then
					vState.out_data        := cFullSync;
				else
					vState.out_data        := cHalfSync;
				end if;
			else
				for i in 0 to gBits / 16 - 1 loop -- looping forward is important to ensure that vAux is set correctly!
					if i = gBits / 16 - 1 and vFlag then
						-- special case: auxiliary byte
						if wInData(i * 2 + 0)(8) = '0' then
							vState.out_data(i * 2 + 0) := wInData(i * 2 + 0)(7 downto 1) & '0';
							vAux(i)          := wInData(i * 2 + 0)(0);
						else
							vState.out_data(i * 2 + 0) := wInData(i * 2 + 0)(7 downto 1) & '1';
							vAux(i)          := '0'; -- '1' is reserved in this case
						end if;
						vState.out_data(i * 2 + 1) := vAux & rState.aux;
					elsif wInData(i * 2 + 0)(8) = '0' and wInData(i * 2 + 1)(8) = '0' then
						-- even: data, odd: data
						vState.out_data(i * 2 + 0) := wInData(i * 2 + 0)(7 downto 1) & '0';
						vState.out_data(i * 2 + 1) := wInData(i * 2 + 1)(7 downto 0);
						vAux(i)             := wInData(i * 2 + 0)(0);
					elsif wInData(i * 2 + 0)(8) = '1' and wInData(i * 2 + 1)(8) = '0' then
						-- even: ID, odd: data
						vState.out_data(i * 2 + 0) := wInData(i * 2 + 0)(7 downto 1) & '1';
						vState.out_data(i * 2 + 1) := wInData(i * 2 + 1)(7 downto 0);
						vAux(i)             := '0';
					elsif wInData(i * 2 + 0)(8) = '0' and wInData(i * 2 + 1)(8) = '1' then
						-- even: data, odd: ID
						vState.out_data(i * 2 + 0) := wInData(i * 2 + 1)(7 downto 1) & '1';
						vState.out_data(i * 2 + 1) := wInData(i * 2 + 0)(7 downto 0);
						vAux(i)             := '1';
					else
						-- even: ID, odd: ID; invalid!
						vState.out_data(i * 2 + 0) := (others => 'U');
						vState.out_data(i * 2 + 1) := (others => 'U');
						vAux(i)             := 'U';
					end if;
				end loop;

				if vFlag then
					vState.aux := (others => 'U');
				else
					if vAux'length /= vState.aux'length then
						vState.aux := vAux & vState.aux(vState.aux'high downto vAux'length);
					else
						vState.aux := vAux;
					end if;
				end if;
			end if;
		else
			wOutData                     <= (others => (others => 'U'));
		end if;

		wState           <= vState;
	end process;

	pReg: process(iRst, iClk)
	begin
		if iRst = '1' then
			rState        <= cStateRst;
		elsif rising_edge(iClk) then
			rState        <= wState;
		end if;
	end process;

	eSerializeIn: for i in 0 to cLanes - 1 generate
		wInData(i) <= iData((i + 1) * 9 - 1 downto i * 9);
	end generate;

	eSerializeOut: for i in 0 to gBits / 8 - 1 generate
		oData((i + 1) * 8 - 1 downto i * 8) <= wOutData(i);
	end generate;
end architecture;
