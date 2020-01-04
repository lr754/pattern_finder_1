-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
-- File Name     : system_rtl.vhd
-- Date Created  : 03/05/2019
--
-- Description of Functionality : system
--      Takes input on SLOW clock. Sends exact same data to output on FAST clock.
--      Adds in additional 8 bit buffer value if correct PACKET_TYPE, and one of 4 valid
--      matching patterns found. Zeros otherwise.
--      
--      Circular buffer used to cross clock domains - metastability achieved on buffer read.
--      Cannot use metastability registers with valid bit edge detection as Valid Packet 
--      Cycles can arrive on consecutive SLOW clock edges.
--
--      Length input determines length of final byte. Used when checking patterns. 
--      Input beyond specified length NOT sanitised, value to sanitise to might be part of the
--      pattern. Complex length checking could be reduced if 4 bit length input used. 
--
--      Misc notes:
--          + Data is Little Endian.
--          + Design can receive Packet Type and Pattern in either order. 
--          + Design assumes ports will remain the same size. Can be parameterised but for
--            scope of test it was deemed un-necessary.
--  
-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.system_package.all;

entity system is
    port (
        -- Asynchronous Reset
        nRESET      : in std_logic;                         -- A-sync reset
        -- Receiver Interface
        CLK_NET     : in std_logic;                         -- Receiver Clock [SLOW]
        IN_VALID    : in std_logic;                         -- '1' when IN_DATA is valid
        IN_SOP      : in std_logic;                         -- '1' on First Valid IN_DATA cycle
        IN_EOP      : in std_logic;                         -- '1' on Final Valid IN_DATA cycle
        IN_LENGTH   : in std_logic_vector( 2 downto 0);     -- 0-7 on Final Valid IN_DATA cycle
        IN_DATA     : in std_logic_vector(63 downto 0);     -- Up to 8 bytes of Little Endian Data
        -- Host Interface
        CLK_HOST    : in std_logic;                         -- Host Clock [FAST]
        OUT_VALID   : out std_logic;                        -- '1' when OUT_DATA is valid
        OUT_SOP     : out std_logic;                        -- '1' on First Valid OUT_DATA cycle
        OUT_EOP     : out std_logic;                        -- '1' on Final Valid OUT_DATA cycle
        OUT_LENGTH  : out std_logic_vector( 2 downto 0);    -- 0-7 on Final Valid OUT_DATA cycle
        OUT_DATA    : out std_logic_vector(63 downto 0);    -- Up to 8 bytes of Little Endian Data
        OUT_BUFFER  : out std_logic_vector( 7 downto 0)     -- One-hot encoded value to represent matching data patterns
    );
end entity system;

architecture rtl of system is

    -- Metastability registers
    signal IN_VALID_R       : std_logic;
    signal IN_VALID_RR      : std_logic;
    signal IN_SOP_R         : std_logic;
    signal IN_SOP_RR        : std_logic;
    signal IN_EOP_R         : std_logic;
    signal IN_EOP_RR        : std_logic;
    signal IN_LENGTH_R      : std_logic_vector( 2 downto 0);
    signal IN_LENGTH_RR     : std_logic_vector( 2 downto 0);
    signal IN_DATA_R        : std_logic_vector(63 downto 0);
    signal IN_DATA_RR       : std_logic_vector(63 downto 0);

    -- Circular buffer and pointers. Size determined by synthesis results. 
    -- Only two locations necessary for functionality to be achieved.
    type CIRCULAR_BUFFER_T  is array (0 to 3) of std_logic_vector(69 downto 0);
    signal INPUT_BUFFER     : CIRCULAR_BUFFER_T;

    signal BUFFER_READ_POINTER  : unsigned(1 downto 0);
    signal BUFFER_WRITE_POINTER : unsigned(1 downto 0);

    -- Packet Cycle Counter (0 to 187)
    signal PACKET_CYCLE_CNT     : unsigned (7 downto 0);

begin

    -- Process to write data to the cicrular buffer on the slow clock
    input_slow_proc: process(CLK_NET, nRESET)
    begin
        if nRESET = '0' then
            BUFFER_WRITE_POINTER <= (others => '0');
        elsif rising_edge(CLK_NET) then
            
            -- If Valid Input
            if IN_VALID = '1' then

                -- Write to Buffer
                INPUT_BUFFER(to_integer(BUFFER_WRITE_POINTER))  <= IN_VALID & IN_SOP & IN_EOP & IN_LENGTH & IN_DATA;

                -- Increment Write Pointer
                BUFFER_WRITE_POINTER    <= BUFFER_WRITE_POINTER + 1;
            end if;

        end if;
    end process;

    -- Process to read data from the circular buffer on the fast clock
    input_fast_proc: process(CLK_HOST, nRESET)
    begin
        if nRESET = '0' then
            BUFFER_READ_POINTER <= (others => '0');
            IN_VALID_R      <= '0';
            IN_SOP_R        <= '0';
            IN_EOP_R        <= '0';
            IN_LENGTH_R     <= (others => '0');
            IN_DATA_R       <= (others => '0');

        elsif rising_edge(CLK_HOST) then
            
            -- Strobe signals low on all other rising edges.
            IN_VALID_R      <= '0';
            IN_SOP_R        <= '0';
            IN_EOP_R        <= '0';
            IN_LENGTH_R     <= (others => '0');
            IN_DATA_R       <= (others => '0');
            
            -- Clock Buffer outputs a second time to avoid metastability
            IN_VALID_RR     <= IN_VALID_R;
            IN_SOP_RR       <= IN_SOP_R;
            IN_EOP_RR       <= IN_EOP_R;
            IN_LENGTH_RR    <= IN_LENGTH_R;
            IN_DATA_RR      <= IN_DATA_R;

            -- If Buffer Pointers are at different locations then there is data to read
            if BUFFER_WRITE_POINTER /= BUFFER_READ_POINTER then
                -- Extract data from buffer
                IN_VALID_R  <= INPUT_BUFFER(to_integer(BUFFER_READ_POINTER))(69);
                IN_SOP_R    <= INPUT_BUFFER(to_integer(BUFFER_READ_POINTER))(68);
                IN_EOP_R    <= INPUT_BUFFER(to_integer(BUFFER_READ_POINTER))(67);
                IN_LENGTH_R <= INPUT_BUFFER(to_integer(BUFFER_READ_POINTER))(66 downto 64);
                IN_DATA_R   <= INPUT_BUFFER(to_integer(BUFFER_READ_POINTER))(63 downto  0);

                -- Increment Read Pointer
                BUFFER_READ_POINTER <= BUFFER_READ_POINTER + 1;
            end if;

        end if;
    end process;

    -- Process counts through packet cycles. 
    -- Checks for matching Packet Type and matching pattern
    --      Process uses a lot of variables. This is in case a valid pattern or packet type is
    --      present in the final packet cycle. Design choice made to not add in extra clock cycle.
    pattern_match_proc: process(CLK_HOST, nRESET)
        variable V_packet_transfer 	    : boolean;   -- TRUE if packet transfer in progress
        variable V_correct_packet_type  : boolean;   -- TRUE if packet has a matching pattern
        variable V_incompatible_len     : boolean;   -- TRUE if packet length too short to include pattern
		variable V_data_to_check	: std_logic_vector(127 downto 0);
        variable V_output_buffer    : std_logic_vector(OUT_BUFFER'range);
    begin
        if nRESET = '0' then
            -- Reset Outputs
            OUT_VALID   <= '0';
            OUT_SOP     <= '0';
            OUT_EOP     <= '0';
            OUT_LENGTH  <= (others => '0');
            OUT_DATA    <= (others => '0');
            OUT_BUFFER  <= (others => '0');

            -- Reset signals/variables
            PACKET_CYCLE_CNT        <= (others => '0');
            V_data_to_check         := (others => '0');
            V_packet_transfer       := FALSE;
			V_correct_packet_type   := FALSE;
            V_incompatible_len      := FALSE;
            V_output_buffer         := (others => '0');

        elsif rising_edge(CLK_HOST) then

            -- Send stable inputs to output
            OUT_VALID       <= IN_VALID_RR;
            OUT_SOP         <= IN_SOP_RR;
            OUT_EOP         <= IN_EOP_RR;
            OUT_LENGTH      <= IN_LENGTH_RR;
            OUT_DATA        <= IN_DATA_RR;
            OUT_BUFFER      <= (others => '0');

			-- If Message start then latch packet transfer to TRUE
			if IN_SOP_RR = '1' then
				V_packet_transfer 	:= TRUE;
			end if;
			
			-- If packet transfer in progress and valid packet cycle arrives
			if (V_packet_transfer = TRUE) and (IN_VALID_RR = '1')  then
				-- Increment Packet Cycle Counter
				PACKET_CYCLE_CNT <= PACKET_CYCLE_CNT + 1;

				-- Check if relevant packet cycle
				case (PACKET_CYCLE_CNT) is
				
                    -- Check for packet type 
					when C_packet_type_offset_word_uns =>
                        -- If Length of this data word is not long enough to include Packet Type. Pattern cannot match
						if ((C_packet_type_limit_hi + 1) > (to_integer(unsigned(IN_LENGTH_RR)) * 8)) and (unsigned(IN_LENGTH_RR) > 0) then
                            V_incompatible_len := TRUE;
                        else
                            --Check for matching packet type
                            if IN_DATA_RR(C_packet_type_limit_hi downto C_packet_type_limit_lo) = C_packet_type then
                                V_correct_packet_type := TRUE;
                            else
                                V_correct_packet_type := FALSE;
                            end if;
                        end if;
						
					-- Collect First half of pattern
					when C_symbol_offset_word_uns =>
                        -- If whole word is pattern and length is non-zero. Pattern cannot match. 
                        --      This is necessary incase missing bytes of pattern are all zeros
                        if (C_symbol_offset_limit_lo = 0) and (unsigned(IN_LENGTH_RR) > 0) then
                            V_incompatible_len := TRUE;
                        else
                            V_data_to_check( 63 downto  0) := IN_DATA_RR;
                        end if;

                    -- Collect Second half of pattern
					when C_symbol_offset_word_uns + 1 =>
                        -- If length of this data word is not long enough to include pattern remainder. Pattern cannot match 
                        --      This is necessary incase missing bytes of pattern are all zeros
                        if ((C_symbol_offset_limit_hi - 63) > (to_integer(unsigned(IN_LENGTH_RR)) * 8)) and (unsigned(IN_LENGTH_RR) > 0)  then
                            V_incompatible_len := TRUE;
                        else
						    V_data_to_check(127 downto 64) := IN_DATA_RR;
                        end if;
							
					when others =>
						null;
				end case;

                -- If pattern location present in packet
                if V_incompatible_len = FALSE then
                    -- If there is a pattern match then set variable and pass to buffer output
                    case (V_data_to_check(C_symbol_offset_limit_hi downto C_symbol_offset_limit_lo)) is 
                        when C_pattern_a =>
                            V_output_buffer := C_detected_a;

                        when C_pattern_b =>
                            V_output_buffer := C_detected_b;

                        when C_pattern_c =>
                            V_output_buffer := C_detected_c;
                            
                        when C_pattern_d =>
                            V_output_buffer := C_detected_d;

                        when others =>
                            V_output_buffer := (others => '0');

                    end case;
                else
                    V_output_buffer := (others => '0');
                end if;
            
                -- If packet cycle is the EOP
                if IN_EOP_RR = '1' then
                    --Set out buffer if packet type correct
                    if V_correct_packet_type = TRUE then
                        OUT_BUFFER		    <= V_output_buffer;
                    else
                        OUT_BUFFER          <= (others => '0');
                    end if;

                    -- Reset Packet Variables
                    PACKET_CYCLE_CNT 	    <= (others => '0');
                    V_packet_transfer 	    := FALSE;
                    V_incompatible_len      := FALSE;
                    V_correct_packet_type   := FALSE;

                end if;	
			end if;
        end if;
    end process pattern_match_proc;


end architecture rtl;
