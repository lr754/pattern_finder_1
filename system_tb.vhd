-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
-- File Name     : system_tb.vhd
-- Date Created  : 03/05/2019
--
-- Description of Functionality : system_tb
--  	Self checking testbench to verify the functionality of system.
--		BFM ommitted as unknown how rest of system will act.
--		A little long but left as is for readability.
--
-- 	Test 1: Valid Packet - Pattern A
-- 	Test 2: Valid Packet - Pattern B
-- 	Test 3: Invalid Packet - Only 1 byte
-- 	Test 4: Valid Packet - Pattern C
-- 	Test 5: Invalid Packet - No Pattern
-- 	Test 6: Invalid Packet - Pattern B but incorrect Packet Type
-- 	Test 7: Invalid Packet - Pattern D, last byte cut off with 2 byte final data word
-- 	Test 8: Invalid Packet - Pattern C, last byte cut off with 2 byte final data word
--
-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.system_package.all;

entity system_tb is
end system_tb;

architecture behavioural of system_tb is

	-- Asynchronous Reset
	signal nRESET      : std_logic;                        -- A-sync reset
	-- Receiver Interface
	signal CLK_NET     : std_logic;                        -- Receiver Clock [SLOW]
	signal IN_VALID    : std_logic;                        -- '1' when IN_DATA is valid
	signal IN_SOP      : std_logic;                        -- '1' on First Valid IN_DATA cycle
	signal IN_EOP      : std_logic;                        -- '1' on Final Valid IN_DATA cycle
	signal IN_LENGTH   : std_logic_vector( 2 downto 0);    -- 0-7 on Final Valid IN_DATA cycle
	signal IN_DATA     : std_logic_vector(63 downto 0);    -- Up to 8 bytes of Little Endian Data
	-- Host Interface
	signal CLK_HOST    : std_logic;                        -- Host Clock [FAST]
	signal OUT_VALID   : std_logic;                        -- '1' when OUT_DATA is valid
	signal OUT_SOP     : std_logic;                        -- '1' on First Valid OUT_DATA cycle
	signal OUT_EOP     : std_logic;                        -- '1' on Final Valid OUT_DATA cycle
	signal OUT_LENGTH  : std_logic_vector( 2 downto 0);    -- 0-7 on Final Valid OUT_DATA cycle
	signal OUT_DATA    : std_logic_vector(63 downto 0);    -- Up to 8 bytes of Little Endian Data
	signal OUT_BUFFER  : std_logic_vector( 7 downto 0);     -- One-hot encoded value to represent matching data patterns

	signal PATTERN_DATA : std_logic_vector(127 downto 0);
	
	constant SLOW_CLK_PERIOD : time := 12 ns;
	constant FAST_CLK_PERIOD : time := 5 ns;
	
	component system is
		port(
			nRESET      : in  std_logic;                        -- A-sync reset
			-- Receiver Interface
			CLK_NET     : in  std_logic;                        -- Receiver Clock [SLOW]
			IN_VALID    : in  std_logic;                        -- '1' when IN_DATA is valid
			IN_SOP      : in  std_logic;                        -- '1' on First Valid IN_DATA cycle
			IN_EOP      : in  std_logic;                        -- '1' on Final Valid IN_DATA cycle
			IN_LENGTH   : in  std_logic_vector( 2 downto 0);    -- 0-7 on Final Valid IN_DATA cycle
			IN_DATA     : in  std_logic_vector(63 downto 0);    -- Up to 8 bytes of Little Endian Data
			-- Host Interface
			CLK_HOST    : in  std_logic;                        -- Host Clock [FAST]
			OUT_VALID   : out std_logic;                        -- '1' when OUT_DATA is valid
			OUT_SOP     : out std_logic;                        -- '1' on First Valid OUT_DATA cycle
			OUT_EOP     : out std_logic;                        -- '1' on Final Valid OUT_DATA cycle
			OUT_LENGTH  : out std_logic_vector( 2 downto 0);    -- 0-7 on Final Valid OUT_DATA cycle
			OUT_DATA    : out std_logic_vector(63 downto 0);    -- Up to 8 bytes of Little Endian Data
			OUT_BUFFER  : out std_logic_vector( 7 downto 0)     -- One-hot encoded value to represent matching data patterns
		);
	end component;
	
begin

	-- Instantiate UUT
	pattern_matcher : system
		port map(	
        nRESET      => nRESET,    
        CLK_NET     => CLK_NET,   
        IN_VALID    => IN_VALID,  
        IN_SOP      => IN_SOP,    
        IN_EOP      => IN_EOP,    
        IN_LENGTH   => IN_LENGTH, 
        IN_DATA     => IN_DATA,   
        CLK_HOST    => CLK_HOST,  
        OUT_VALID   => OUT_VALID, 
        OUT_SOP     => OUT_SOP,   
        OUT_EOP     => OUT_EOP,   
        OUT_LENGTH  => OUT_LENGTH,
        OUT_DATA    => OUT_DATA,  
        OUT_BUFFER  => OUT_BUFFER
    );
	
	slow_clk_gen : process
	begin
		CLK_NET <= '1';
		wait for SLOW_CLK_PERIOD/2;
		CLK_NET <= '0';
		wait for SLOW_CLK_PERIOD/2;
	end process;
	
	fast_clk_gen : process
	begin
		CLK_HOST <= '1';
		wait for FAST_CLK_PERIOD/2;
		CLK_HOST <= '0';
		wait for FAST_CLK_PERIOD/2;
	end process;

	-- Stimulate UUT on Slow Clock
	stim_proc : process
	begin
		-- Set up I/O environment
		IN_VALID  	<= '0';
		IN_DATA	  	<= (others => '0');
		IN_EOP    	<= '0';
		IN_SOP    	<= '0';
		IN_LENGTH 	<= (others => '0');
		nRESET 		<= '1';
		
		wait for SLOW_CLK_PERIOD * 10;
		nRESET <= '0';
		wait for SLOW_CLK_PERIOD * 10 ;
		nRESET <= '1';
		wait for SLOW_CLK_PERIOD;
		
		-- Test 1: Valid Matching Pattern Type A.
		-- 	Packet Cycles on Non-Consecutive Clock Cycles
		
		PATTERN_DATA <= (others => '0');
		PATTERN_DATA(C_symbol_offset_limit_hi downto C_symbol_offset_limit_lo) <= C_pattern_a;

		for i in 0 to 99 loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			if i = 0 then
				IN_SOP <= '1';
			
			-- Packet Cycle with Packet Type in
			elsif i = C_packet_type_offset_word_int then
				IN_DATA(C_packet_type_limit_hi downto C_packet_type_limit_lo) <= C_packet_type;
			
			-- Packet Cycle with PATTERN
			elsif i = C_symbol_offset_word_int then 
				IN_DATA <= PATTERN_DATA(63 downto  0);
			
			-- Packet Cycle with PATTERN second half
			elsif i = (C_symbol_offset_word_int+1) then
				IN_DATA <= PATTERN_DATA(127 downto 64);

			-- Final Packet Cycle = EOP
			elsif i = 99 then
				IN_EOP <= '1';
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID <= '0';
			IN_SOP 	 <= '0';
			IN_EOP   <= '0';
			IN_DATA  <= (others => '0');
			
			wait for SLOW_CLK_PERIOD;
		end loop;
		
		wait for SLOW_CLK_PERIOD * 10; 
		
		-- Test 2: Valid Matching Pattern Type B.
		-- 	Packet Cycles on Consecutive Clock Cycles

		PATTERN_DATA <= (others => '0');
		PATTERN_DATA(C_symbol_offset_limit_hi downto C_symbol_offset_limit_lo) <= C_pattern_b;

		for i in 0 to 99 loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			if i = 0 then
				IN_SOP <= '1';
			
			-- Packet Cycle with Packet Type in
			elsif i = C_packet_type_offset_word_int then
				IN_DATA(C_packet_type_limit_hi downto C_packet_type_limit_lo) <= C_packet_type;
			
			-- Packet Cycle with PATTERN
			elsif i = C_symbol_offset_word_int then 
				IN_DATA <= PATTERN_DATA(63 downto  0);
			
			-- Packet Cycle with PATTERN second half
			elsif i = (C_symbol_offset_word_int+1) then
				IN_DATA <= PATTERN_DATA(127 downto 64);

			-- Final Packet Cycle = EOP
			elsif i = 99 then
				IN_EOP <= '1';
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID <= '0';
			IN_SOP 	 <= '0';
			IN_EOP   <= '0';
			IN_DATA  <= (others => '0');
			
		end loop;
		
		wait for SLOW_CLK_PERIOD * 10;  
		
		-- Test 3: 1 byte Packet
		-- 	Packet Cycles on Consecutive Clock Cycles

		for i in 0 to 0 loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			-- Final Packet Cycle = EOP
			if i = 0 then
				IN_SOP <= '1';
				IN_EOP <= '1';
				IN_LENGTH <= 3x"1";
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID 	<= '0';
			IN_SOP 	 	<= '0';
			IN_EOP   	<= '0';
			IN_DATA  	<= (others => '0');
			IN_LENGTH 	<= (others => '0');
			
		end loop;
		
		wait for SLOW_CLK_PERIOD * 10; 

		-- Test 4: Valid Matching Pattern Type C.
		-- 	Packet Cycles on Consecutive Clock Cycles. All other patterns present in packet.
		
		PATTERN_DATA <= (others => '0');
		PATTERN_DATA(C_symbol_offset_limit_hi downto C_symbol_offset_limit_lo) <= C_pattern_c;

		for i in 0 to 99 loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			if i = 0 then
				IN_SOP <= '1';
			
			-- Packet Cycle with Packet Type in
			elsif i = C_packet_type_offset_word_int then
				IN_DATA(C_packet_type_limit_hi downto C_packet_type_limit_lo) <= C_packet_type;
			
			-- Packet Cycle with PATTERN A
			elsif i = 25 then 
				IN_DATA <= C_pattern_a;
			
			-- Packet Cycle with PATTERN B
			elsif i = 50 then 
				IN_DATA <= C_pattern_b;

			-- Packet Cycle with PATTERN D
			elsif i = 75 then 
				IN_DATA <= C_pattern_d;

			-- Packet Cycle with PATTERN
			elsif i = C_symbol_offset_word_int then 
				IN_DATA <= PATTERN_DATA(63 downto  0);
			
			-- Packet Cycle with PATTERN second half
			elsif i = (C_symbol_offset_word_int+1) then
				IN_DATA <= PATTERN_DATA(127 downto 64);

			-- Final Packet Cycle = EOP
			elsif i = 99 then
				IN_EOP <= '1';
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID <= '0';
			IN_SOP 	 <= '0';
			IN_EOP   <= '0';
			IN_DATA  <= (others => '0');
			
		end loop;
		
		wait for SLOW_CLK_PERIOD * 10; 
		
		-- Test 5: No matching Patterns - correct Packet Type.
		-- 	Packet Cycles on Consecutive Clock Cycles

		for i in 0 to 99 loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			if i = 0 then
				IN_SOP <= '1';
			
			-- Packet Cycle with Packet Type in
			elsif i = C_packet_type_offset_word_int then
				IN_DATA(C_packet_type_limit_hi downto C_packet_type_limit_lo) <= C_packet_type;

			-- Final Packet Cycle = EOP
			elsif i = 99 then
				IN_EOP <= '1';
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID <= '0';
			IN_SOP 	 <= '0';
			IN_EOP   <= '0';
			IN_DATA  <= (others => '0');
			
		end loop;
		
		wait for SLOW_CLK_PERIOD * 10; 
		
		-- Test 6: Valid Matching Pattern Type B - incorrect Packet Type.
		-- 	Packet Cycles on Consecutive Clock Cycles

		PATTERN_DATA <= (others => '0');
		PATTERN_DATA(C_symbol_offset_limit_hi downto C_symbol_offset_limit_lo) <= C_pattern_b;

		for i in 0 to 99 loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			if i = 0 then
				IN_SOP <= '1';
			
			-- Packet Cycle with PATTERN
			elsif i = C_symbol_offset_word_int then 
				IN_DATA <= PATTERN_DATA(63 downto  0);
			
			-- Packet Cycle with PATTERN second half
			elsif i = (C_symbol_offset_word_int+1) then
				IN_DATA <= PATTERN_DATA(127 downto 64);

			-- Final Packet Cycle = EOP
			elsif i = 99 then
				IN_EOP <= '1';
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID <= '0';
			IN_SOP 	 <= '0';
			IN_EOP   <= '0';
			IN_DATA  <= (others => '0');
			
		end loop;
		
		wait for SLOW_CLK_PERIOD * 10; 
		
		-- Test 7: Valid Matching pattern type D. 
		--	Entire packet sent into system, final packet cycle has length set so final byte of pattern is NOT valid.
		-- 	No matching pattern should be detected
		-- 	Packet Cycles on Consecutive Clock Cycles
		
		PATTERN_DATA <= (others => '0');
		PATTERN_DATA(C_symbol_offset_limit_hi downto C_symbol_offset_limit_lo) <= C_pattern_d;

		for i in 0 to (C_symbol_offset_word_int+1) loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			if i = 0 then
				IN_SOP <= '1';
			
			-- Packet Cycle with Packet Type in
			elsif i = C_packet_type_offset_word_int then
				IN_DATA(C_packet_type_limit_hi downto C_packet_type_limit_lo) <= C_packet_type;
			
			-- Packet Cycle with PATTERN
			elsif i = C_symbol_offset_word_int then 
				IN_DATA <= PATTERN_DATA(63 downto  0);
			
			-- Packet Cycle with PATTERN second half
			elsif i = (C_symbol_offset_word_int+1) then
				IN_DATA 	<= PATTERN_DATA(127 downto 64);
				IN_EOP 		<= '1';
				-- System_package constants set 3 bytes of pattern to occur in this word. Make length 2
				IN_LENGTH 	<= 3x"2";
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID <= '0';
			IN_SOP 	 <= '0';
			IN_EOP   <= '0';
			IN_DATA  <= (others => '0');
			IN_DATA  <= (others => '0');
		end loop;
		
		wait for SLOW_CLK_PERIOD * 10; 
		
		-- Test 8: Valid Matching pattern type C. 
		--	Entire packet sent into system, final packet cycle has length set so final byte of pattern is NOT valid.
		-- 	No matching pattern should be detected. Different from Test 7 as pattern C has final byte all zeros. 
		-- 	Packet Cycles on Consecutive Clock Cycles
		
		PATTERN_DATA <= (others => '0');
		PATTERN_DATA(C_symbol_offset_limit_hi downto C_symbol_offset_limit_lo) <= C_pattern_c;

		for i in 0 to (C_symbol_offset_word_int+1) loop
			IN_VALID <= '1';

			-- First packet cycle = SOP
			if i = 0 then
				IN_SOP <= '1';
			
			-- Packet Cycle with Packet Type in
			elsif i = C_packet_type_offset_word_int then
				IN_DATA(C_packet_type_limit_hi downto C_packet_type_limit_lo) <= C_packet_type;
			
			-- Packet Cycle with PATTERN
			elsif i = C_symbol_offset_word_int then 
				IN_DATA <= PATTERN_DATA(63 downto  0);
			
			-- Packet Cycle with PATTERN second half
			elsif i = (C_symbol_offset_word_int+1) then
				IN_DATA 	<= PATTERN_DATA(127 downto 64);
				IN_EOP 		<= '1';
				-- System_package constants set 3 bytes of pattern to occur in this word. Make length 2
				IN_LENGTH 	<= 3x"2";
			end if;
			
			wait for SLOW_CLK_PERIOD;
			
			IN_VALID <= '0';
			IN_SOP 	 <= '0';
			IN_EOP   <= '0';
			IN_DATA  <= (others => '0');
			IN_DATA  <= (others => '0');
		end loop;

		-- End of Tests - wait indefinitely
		wait;
	end process;
	
	mon_proc : process
	begin
		-- Test 1: Pattern A should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= C_detected_a then
			-- Not correctly detected pattern a!
			report "Simulation Failed: Correct pattern (A) not detected" severity failure;
		else
			report "Test 1: PASS - Pattern A detected" severity note;
		end if;
		
		wait for FAST_CLK_PERIOD;

		--Test 2: Pattern B should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= C_detected_b then
			-- Not correctly detected pattern b!
			report "Simulation Failed: Correct pattern (B) not detected" severity failure;
		else
			report "Test 2: PASS - Pattern B detected" severity note;
		end if;
		
		wait for FAST_CLK_PERIOD;

		--Test 3: No pattern should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= std_logic_vector(to_unsigned(0, OUT_BUFFER'length)) then
			-- Incorrectly detected a packet!
			report "Simulation Failed: Incorrect Pattern Detected" severity failure;
		else
			report "Test 3: PASS - No Pattern Detected" severity note;
		end if;
		
		wait for FAST_CLK_PERIOD;

		--Test 4: Pattern C should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= C_detected_c then
			-- Not correctly detected pattern c!
			report "Simulation Failed: Correct pattern (C) not detected" severity failure;
		else
			report "Test 4: PASS - Pattern C detected" severity note;
		end if;

		--Test 5: No pattern should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= std_logic_vector(to_unsigned(0, OUT_BUFFER'length)) then
			-- Incorrectly detected a packet!
			report "Simulation Failed: Incorrect Pattern Detected" severity failure;
		else
			report "Test 5: PASS - No Pattern Detected" severity note;
		end if;

		--Test 6: No pattern should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= std_logic_vector(to_unsigned(0, OUT_BUFFER'length)) then
			-- Incorrectly detected a packet!
			report "Simulation Failed: Incorrect Pattern Detected" severity failure;
		else
			report "Test 6: PASS - No Pattern Detected" severity note;
		end if;

		--Test 7: No pattern should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= std_logic_vector(to_unsigned(0, OUT_BUFFER'length)) then
			-- Incorrectly detected a packet!
			report "Simulation Failed: Incorrect Pattern Detected" severity failure;
		else
			report "Test 7: PASS - No Pattern Detected" severity note;
		end if;

		--Test 8: No pattern should have been detected
		wait until OUT_EOP = '1';
		if OUT_BUFFER /= std_logic_vector(to_unsigned(0, OUT_BUFFER'length)) then
			-- Incorrectly detected a packet!
			report "Simulation Failed: Incorrect Pattern Detected" severity failure;
		else
			report "Test 8: PASS - No Pattern Detected" severity note;
		end if;

		wait for FAST_CLK_PERIOD * 10;

		report "Simulation Completed: Full Pass" severity failure;
		wait;
	end process;
	
end architecture behavioural;

















