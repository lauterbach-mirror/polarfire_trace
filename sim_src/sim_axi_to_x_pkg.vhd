library ieee;
use ieee.std_logic_1164.all;

use work.axi4_fic1_from_mss_pkg;

package sim_axi_to_x_pkg is
	type tData is array(natural range <>) of std_logic_vector(7 downto 0);
end package;
