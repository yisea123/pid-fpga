library ieee;
use ieee.std_logic_1164.all;

package log_package is

    function log2ceil( n : natural) return natural;
	 function log2( i : natural) return integer;
end log_package;

package body log_package is

function log2ceil (n : natural) return natural is 
        variable i, j : natural;
     begin
        i := 0;
        j := 1;
        while (j < n) loop
            i := i+1;
            j := 2*j;
        end loop;
        return i;
     end function log2ceil;

	  
function log2( i : natural) return integer is
    variable temp    : integer := i;
    variable ret_val : integer := 0; 
  begin					
    while temp > 1 loop
      ret_val := ret_val + 1;
      temp    := temp / 2;     
    end loop;
  	
    return ret_val;
  end function log2;	  
	  
end log_package;