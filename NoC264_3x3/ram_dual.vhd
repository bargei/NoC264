--source code below originally from:
-- http://quartushelp.altera.com/14.1/mergedprojects/hdl/vhdl/vhdl_pro_ram_inferred.htm
-- 
-- modified to use generics
-- should produce infered ram

library ieee;
use ieee.std_logic_1164.all;
--package ram_package is
--   constant ram_width : integer := 4;
--   constant ram_depth : integer := 1024;
--   
--   type word is array(0 to ram_width - 1) of std_logic;
--   type ram is array(0 to ram_depth - 1) of word;
--   subtype address_vector is integer range 0 to ram_depth - 1;
--   
--end ram_package;


library ieee;
use ieee.std_logic_1164.all;
--use work.ram_package.all;
entity ram_dual is
    generic
    (
        ram_width : integer := 24;
        ram_depth : integer := 65536
    );
    port
    (
        clock1        : in   std_logic;
        clock2        : in   std_logic;
        data          : in   std_logic_vector(ram_width-1 downto 0);
        write_address : in   integer;
        read_address  : in   integer;
        we            : in   std_logic;
        q             : out  std_logic_vector(ram_width-1 downto 0)
    );
end ram_dual;
architecture rtl of ram_dual is

    type   ram is array(0 to ram_depth - 1) of std_logic_vector(ram_width-1 downto 0);
    signal ram_block : ram;
 
begin
    process (clock1)
    begin
        if (clock1'event and clock1 = '1') then
            if (we = '1') then
                ram_block(write_address) <= data;
            end if;
        end if;
    end process;
    process (clock2)
    begin
        if (clock2'event and clock2 = '1') then
            q <= ram_block(read_address);
        end if;
    end process;
   
end rtl;