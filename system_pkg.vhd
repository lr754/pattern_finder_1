-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
-- File Name     : system_rtl.vhd
-- Date Created  : 03/05/2019
--
-- Description of Functionality : system
--  	Simple package that contains all constants used by the system
-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package system_package is
	-------------------------------------------------------------------------------
	-- User defined Constants -----------------------------------------------------
	-------------------------------------------------------------------------------
    -- Packet Type. Matching patterns will be this package type
    constant C_packet_type          : std_logic_vector(31 downto 0) := 32X"DEADBEEF";

    -- Packet Type Offsets In Bytes
	constant C_packet_type_offset_int  	: integer := 43;
	constant C_symbol_offset_int		: integer := 251;
	
    -- Patterns to check for - Little Endian! [First byte 7 downto 0]
    constant C_pattern_a    : std_logic_vector(63 downto 0) := 64x"0123456789ABCDEF";
    constant C_pattern_b    : std_logic_vector(63 downto 0) := 64x"FEDCBA9876543210";
    constant C_pattern_c    : std_logic_vector(63 downto 0) := 64x"001E2D3C4B5A6978";
    constant C_pattern_d    : std_logic_vector(63 downto 0) := 64x"8796A5B4C3D2E1F0";

    -- Detected pattern Buffer values. One-hot encoded to reduce chance of incorrect value set.
    constant C_detected_a   : std_logic_vector( 7 downto 0) := 8x"01";
    constant C_detected_b   : std_logic_vector( 7 downto 0) := 8x"02";
    constant C_detected_c   : std_logic_vector( 7 downto 0) := 8x"04";
    constant C_detected_d   : std_logic_vector( 7 downto 0) := 8x"08";
	
	-------------------------------------------------------------------------------
	
	-------------------------------------------------------------------------------
	-- Calculated Constants -------------------------------------------------------
	-------------------------------------------------------------------------------
	
	-- Which Packet Cycle to start checking for. [Integer and Unsigned for code readability]
	constant C_packet_type_offset_word_int 		: integer := C_packet_type_offset_int / 8;
	constant C_packet_type_offset_word_uns		: unsigned(7 downto 0) := to_unsigned(C_packet_type_offset_word_int, 8);
	constant C_symbol_offset_word_int 			: integer := C_symbol_offset_int / 8;
	constant C_symbol_offset_word_uns			: unsigned(7 downto 0) := to_unsigned(C_symbol_offset_word_int, 8);
	
	-- Which Byte in the cycle to start checking
	constant C_packet_type_byte_offset_int		: integer := C_packet_type_offset_int mod 8;
	constant C_symbol_offset_byte_offset_int	: integer := C_symbol_offset_int mod 8;
	
	-- Which bits in the packet cycle are the packet type
	constant C_packet_type_limit_lo			: integer range 0 to 63 := ((C_packet_type_byte_offset_int) * 8);
	constant C_packet_type_limit_hi			: integer range 0 to 63 := ((C_packet_type_byte_offset_int + 4) * 8) - 1;
	
	-- Which bits in the TWO packet cycles are the pattern to match. 
	constant C_symbol_offset_limit_lo		: integer range 0 to 63 := ((C_symbol_offset_byte_offset_int) * 8);
	constant C_symbol_offset_limit_hi		: integer range 63 to 127 := C_symbol_offset_limit_lo + 63;

	-------------------------------------------------------------------------------

end package system_package;