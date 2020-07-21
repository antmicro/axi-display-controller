--------------------------------------------------------------------------------
--
--  File:
--      vdma_to_vga.vhd
--
--  Module:
--      AXIS Display Controller
--
--  Author:
--      Sam Bobrowicz
--
--  Description:
--      AXI Display Controller
--
--  Copyright notice:
--      Copyright (C) 2014 Digilent Inc.
--
--  License:
--      This program is free software; distributed under the terms of 
--      BSD 3-clause license ("Revised BSD License", "New BSD License", or "Modified BSD License")
--
--      Redistribution and use in source and binary forms, with or without modification,
--      are permitted provided that the following conditions are met:
--
--      1.    Redistributions of source code must retain the above copyright notice, this
--             list of conditions and the following disclaimer.
--      2.    Redistributions in binary form must reproduce the above copyright notice,
--             this list of conditions and the following disclaimer in the documentation
--             and/or other materials provided with the distribution.
--      3.    Neither the name(s) of the above-listed copyright holder(s) nor the names
--             of its contributors may be used to endorse or promote products derived
--             from this software without specific prior written permission.
--
--      THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--      ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--      WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
--      IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
--      INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
--      BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
--      DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
--      LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
--      OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
--      OF THE POSSIBILITY OF SUCH DAMAGE.
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vdma_to_vga is
	generic (
		C_S_AXIS_TDATA_WIDTH : integer := 32
	);
	Port (
		LOCKED_I : in  STD_LOGIC;
		ENABLE_I : in  STD_LOGIC;
		RUNNING_O : out  STD_LOGIC;
		FSYNC_O : out  STD_LOGIC;

		S_AXIS_ACLK : in  STD_LOGIC;
		S_AXIS_TDATA : in  STD_LOGIC_VECTOR (C_S_AXIS_TDATA_WIDTH-1 downto 0);
		S_AXIS_TVALID : in  STD_LOGIC;
		S_AXIS_TLAST : in std_logic;
		S_AXIS_TREADY : out  STD_LOGIC;

		DEBUG_O : out STD_LOGIC_VECTOR (31 downto 0);

		HSYNC_O : out  STD_LOGIC;
		VSYNC_O : out  STD_LOGIC;
		DE_O : out  STD_LOGIC;
		DATA_O : out STD_LOGIC_VECTOR (C_S_AXIS_TDATA_WIDTH-1 downto 0);
		CTL_O : out STD_LOGIC_VECTOR (3 downto 0);
		VGUARD_O : out STD_LOGIC;
		DGUARD_O : out STD_LOGIC;
		DIEN_O : out STD_LOGIC;
		DIH_O : out STD_LOGIC;

		USR_HPS_I : in  STD_LOGIC_VECTOR (11 downto 0);
		USR_HPE_I : in  STD_LOGIC_VECTOR (11 downto 0);
		USR_HPOL_I : in  STD_LOGIC;
		USR_HPREAMS_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_HPREAME_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_VGUARDS_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_VGUARDE_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_HDATAENS_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_HDATAENE_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_VDATAENS_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_VDATAENE_I : in STD_LOGIC_VECTOR (11 downto 0);
		USR_DATAENPOL_I : in STD_LOGIC;
		USR_HMAX_I : in  STD_LOGIC_VECTOR (11 downto 0);
		USR_VPS_I : in  STD_LOGIC_VECTOR (11 downto 0);
		USR_VPE_I : in  STD_LOGIC_VECTOR (11 downto 0);
		USR_VPOL_I : in  STD_LOGIC;
		USR_VMAX_I : in  STD_LOGIC_VECTOR (11 downto 0);
		USR_FSYNC_I : in STD_LOGIC_VECTOR (11 downto 0));
end vdma_to_vga;

architecture Behavioral of vdma_to_vga is


	type VGA_STATE_TYPE is (VGA_RESET, VGA_WAIT_EN, VGA_LATCH, VGA_INIT, VGA_WAIT_VLD, VGA_RUN);

	signal pxl_clk : std_logic;
	signal locked : std_logic;
	signal vga_running : std_logic;
	signal frame_edge : std_logic;

	signal running_reg : std_logic := '0';
	signal vga_en : std_logic := '0';

	signal h_ps : std_logic_vector(11 downto 0) := (others =>'0');
	signal h_pe : std_logic_vector(11 downto 0) := (others =>'0');
	signal h_preams : std_logic_vector(11 downto 0) := (others =>'0');
	signal h_preame : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_guards : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_guarde : std_logic_vector(11 downto 0) := (others =>'0');
	signal d_guards : std_logic_vector(11 downto 0) := (others =>'0');
	signal d_guarde : std_logic_vector(11 downto 0) := (others =>'0');
	signal h_dataens : std_logic_vector(11 downto 0) := (others =>'0');
	signal h_dataene : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_dataens : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_dataene : std_logic_vector(11 downto 0) := (others =>'0');
	signal de_pol : std_logic := '0';
	signal h_max : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_ps : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_pe : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_max : std_logic_vector(11 downto 0) := (others =>'0');
	signal h_pol : std_logic := '0';
	signal v_pol : std_logic := '0';
	signal v_fsync : std_logic_vector(11 downto 0) := (others =>'0');

	signal h_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
	signal v_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');

	signal h_sync_reg : std_logic := '0';
	signal v_sync_reg : std_logic := '0';
	signal h_sync_dly : std_logic := '0';
	signal v_sync_dly : std_logic := '0';
	signal h_sync_dd : std_logic := '0';
	signal v_sync_dd : std_logic := '0';

	signal h_ctl_reg : std_logic_vector(3 downto 0) := (others =>'0');
	signal h_ctl_dly : std_logic_vector(3 downto 0) := (others =>'0');
	signal h_ctl_dd : std_logic_vector(3 downto 0) := (others =>'0');

	signal v_guard_reg : std_logic := '0';
	signal v_guard_dly : std_logic := '0';
	signal v_guard_dd : std_logic := '0';

	signal d_guard_reg : std_logic := '0';
	signal d_guard_dly : std_logic := '0';
	signal d_guard_dd : std_logic := '0';

	signal d_island_en_reg : std_logic := '0';
	signal d_island_en_dly : std_logic := '0';
	signal d_island_en_dd : std_logic := '0';

	signal d_island_header_reg : std_logic := '0';
	signal d_island_header_dly : std_logic := '0';
	signal d_island_header_dd : std_logic := '0';

	signal d_island_end : std_logic_vector(11 downto 0) := (others =>'0');
	signal d_guard_trailing_s : std_logic_vector(11 downto 0) := (others =>'0');
	signal d_guard_trailing_e : std_logic_vector(11 downto 0) := (others =>'0');

	signal fsync_reg : std_logic := '0';

	signal video_dv : std_logic := '0';
	signal video_dv_d : std_logic := '0';
	signal video_dv_dd : std_logic := '0';

	signal data_reg : std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0) := (others =>'0');

	signal vga_state : VGA_STATE_TYPE := VGA_RESET;

    attribute ASYNC_REG : string;
    signal vga_en_sync : std_logic_vector(2 downto 0) := (others => '0');
    attribute ASYNC_REG of vga_en_sync: signal is "TRUE";
begin

	locked <= LOCKED_I;
	pxl_clk <= S_AXIS_ACLK;

	d_island_end <= std_logic_vector(unsigned(v_guarde)+32);
	d_guard_trailing_s <= std_logic_vector(unsigned(v_guarde)+32);
	d_guard_trailing_e <= std_logic_vector(unsigned(v_guarde)+34);

	DEBUG_O(11 downto 0) <= h_cntr_reg;
	DEBUG_O(23 downto 12) <= v_cntr_reg;
	DEBUG_O(24) <= vga_running;
	DEBUG_O(25) <= frame_edge;
	DEBUG_O(26) <= fsync_reg;
	DEBUG_O(27) <= h_sync_dly;
	DEBUG_O(28) <= v_sync_dly;
	DEBUG_O(29) <= video_dv_d;
	DEBUG_O(30) <= video_dv;
	DEBUG_O(31) <= S_AXIS_TVALID;

------------------------------------------------------------------
------                 CONTROL STATE MACHINE               -------
------------------------------------------------------------------

--Synchronize ENABLE_I signal from axi_lite domain to pixel clock
--domain
	process (pxl_clk, locked)
	begin
		if (locked = '0') then
		  vga_en <= '0';
		  vga_en_sync <= (others => '0');
		elsif (rising_edge(pxl_clk)) then
		  vga_en_sync <= vga_en_sync(vga_en_sync'high - 1 downto vga_en_sync'low) & ENABLE_I;
		  vga_en <= vga_en_sync(vga_en_sync'high);
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			vga_state <= VGA_RESET;
		elsif (rising_edge(pxl_clk)) then
			case vga_state is
				when VGA_RESET =>
					vga_state <= VGA_WAIT_EN;
				when VGA_WAIT_EN =>
					if (vga_en = '1') then
						vga_state <= VGA_LATCH;
					end if;
				when VGA_LATCH =>
					vga_state <= VGA_INIT;
				when VGA_INIT =>
					vga_state <= VGA_WAIT_VLD;
				when VGA_WAIT_VLD =>
					--It seems the first frame requires a bit of time for the linebuffer to fill. This
					--State ensures we do not begin requesting data before the VDMA reports it is valid
					if (S_AXIS_TVALID = '1') then
						vga_state <= VGA_RUN;
					end if;
				when VGA_RUN =>
					if (vga_en = '0' and frame_edge = '1') then
						vga_state <= VGA_WAIT_EN;
					end if;
				when others => --Never reached
					vga_state <= VGA_RESET;
			end case;
		end if;
	end process;

	--This component treats the first pixel of the first non-visible line as the beginning
	--of the frame.
	frame_edge <= '1' when ((v_cntr_reg = v_dataene) and (h_cntr_reg = 0)) else
			'0';

	vga_running <= '1' when vga_state = VGA_RUN else
			'0'; 

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			running_reg <= '0';
		elsif (rising_edge(pxl_clk)) then
			running_reg <= vga_running;
		end if;
	end process;

	RUNNING_O <= running_reg;

------------------------------------------------------------------
------                  USER REGISTER LATCH                -------
------------------------------------------------------------------
--Note that the USR_ inputs are crossing from the axi_lite clock domain
--to the pixel clock domain


	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			h_ps <= (others => '0');
			h_pe <= (others => '0');
			h_preams <= (others => '0');
			h_preame <= (others => '0');
			v_guards <= (others => '0');
			v_guarde <= (others => '0');
			h_dataens <= (others => '0');
			h_dataene <= (others => '0');
			v_dataens <= (others => '0');
			v_dataene <= (others => '0');
			h_pol <= '0';
			h_max <= (others => '0');
			v_ps <= (others => '0');
			v_pe <= (others => '0');
			v_pol <= '0';
			v_max <= (others => '0');
			de_pol <= '0';
			v_fsync <= (others => '0');
		elsif (rising_edge(pxl_clk)) then
			if (vga_state = VGA_LATCH) then
				h_ps <= USR_HPS_I;
				h_pe <= USR_HPE_I;
				h_preams <= USR_HPREAMS_I;
				h_preame <= USR_HPREAME_I;
				v_guards <= USR_VGUARDS_I;
				v_guarde <= USR_VGUARDE_I;
				h_dataens <= USR_HDATAENS_I;
				h_dataene <= USR_HDATAENE_I;
				v_dataens <= USR_VDATAENS_I;
				v_dataene <= USR_VDATAENE_I;
				h_pol <= USR_HPOL_I;
				h_max <= USR_HMAX_I;
				v_ps <= USR_VPS_I;
				v_pe <= USR_VPE_I;
				v_pol <= USR_VPOL_I;
				v_max <= USR_VMAX_I;
				de_pol <= USR_DATAENPOL_I;
				v_fsync <= USR_FSYNC_I;
			end if;
		end if;
	end process;


------------------------------------------------------------------
------              PIXEL ADDRESS COUNTERS                 -------
------------------------------------------------------------------


	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			h_cntr_reg <= (others => '0');
		elsif (rising_edge(pxl_clk)) then
			if (vga_state = VGA_WAIT_VLD) then
				h_cntr_reg <= (others =>'0'); --Note that the first frame starts on the second non-visible line, right after when FSYNC would pulse
			elsif (vga_running = '1') then
				if (h_cntr_reg = h_max) then
					h_cntr_reg <= (others => '0');
				else
					h_cntr_reg <= h_cntr_reg + 1;
				end if;
			else
				h_cntr_reg <= (others =>'0');
			end if;
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			v_cntr_reg <= (others => '0');
		elsif (rising_edge(pxl_clk)) then
			if (vga_state = VGA_WAIT_VLD) then
				v_cntr_reg <= v_dataene + 1; --Note that the first frame starts on the second non-visible line, right after when FSYNC would pulse
			elsif (vga_running = '1') then
				if ((h_cntr_reg = h_max) and (v_cntr_reg = v_max))then
					v_cntr_reg <= (others => '0');
				elsif (h_cntr_reg = h_max) then
					v_cntr_reg <= v_cntr_reg + 1;
				end if;
			else
				v_cntr_reg <= (others =>'0');
			end if;
		end if;
	end process;

------------------------------------------------------------------
------               GUARD GENERATION                      -------
------------------------------------------------------------------


	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			v_guard_reg <= '0';
			d_guard_reg <= '0';
		elsif (rising_edge(pxl_clk)) then
			if (vga_running = '1') then
				-- Video guard band
				if (h_cntr_reg >= v_guards and h_cntr_reg < v_guarde) and (v_cntr_reg >= v_dataens and v_cntr_reg < v_dataene) then
					v_guard_reg <= '1';
				else
					v_guard_reg <= '0';
				end if;
				-- Data island guard bands
				if ((h_cntr_reg >= v_guards and h_cntr_reg < v_guarde) or (h_cntr_reg >= d_guard_trailing_s and h_cntr_reg < d_guard_trailing_e)) and (v_cntr_reg >= v_ps and v_cntr_reg < v_pe) then
					d_guard_reg <= '1';
				else
					d_guard_reg <= '0';
				end if;
			else
				v_guard_reg <= '0';
				d_guard_reg <= '0';
			end if;
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			v_guard_dly <= '0';
			d_guard_dly <= '0';
			v_guard_dd <= '0';
			d_guard_dd <= '0';
		elsif (rising_edge(pxl_clk)) then
			v_guard_dly <= v_guard_reg;
			d_guard_dly <= d_guard_reg;
			v_guard_dd <= v_guard_dly;
			d_guard_dd <= d_guard_dly;
		end if;
	end process;

	VGUARD_O <= v_guard_dd;
	DGUARD_O <= d_guard_dd;

------------------------------------------------------------------
------             DATA ISLAND CONTROL                     -------
------------------------------------------------------------------


	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			d_island_en_reg <= '0';
			d_island_header_reg <= '0';
		elsif (rising_edge(pxl_clk)) then
			if (vga_running = '1') then
				-- Data island enable
				if (h_cntr_reg >= v_guarde and h_cntr_reg < d_island_end) and (v_cntr_reg >= v_ps and v_cntr_reg < v_pe) then
					d_island_en_reg <= '1';
				else
					d_island_en_reg <= '0';
				end if;
				-- Data island header
				if (h_cntr_reg = v_guarde) and (v_cntr_reg >= v_ps and v_cntr_reg < v_pe) then
					d_island_header_reg <= '1';
				else
					d_island_header_reg <= '0';
				end if;
			else
				d_island_header_reg <= '0';
			end if;
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			d_island_en_dly <= '0';
			d_island_header_dly <= '0';
			d_island_en_dd <= '0';
			d_island_header_dd <= '0';
		elsif (rising_edge(pxl_clk)) then
			d_island_en_dly <= d_island_en_reg;
			d_island_header_dly <= d_island_header_reg;
			d_island_en_dd <= d_island_en_dly;
			d_island_header_dd <= d_island_header_dly;
		end if;
	end process;

	DIEN_O <= d_island_en_dd;
	DIH_O <= d_island_header_dd;

------------------------------------------------------------------
------             PREAMBLE GENERATION                     -------
------------------------------------------------------------------


	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			h_ctl_reg <= (others =>'0');
		elsif (rising_edge(pxl_clk)) then
			if (vga_running = '1') then
				if ((h_cntr_reg >= h_preams and h_cntr_reg < h_preame) and (v_cntr_reg >= v_dataens and v_cntr_reg < v_dataene)) then
					h_ctl_reg <= "0001";
				elsif ((h_cntr_reg >= h_preams and h_cntr_reg < h_preame) and (v_cntr_reg >= v_ps and v_cntr_reg < v_pe)) then
					h_ctl_reg <= "0101";
				else
				  h_ctl_reg <= (others =>'0');
				end if;
			else
				h_ctl_reg <= (others =>'0');
			end if;
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			h_ctl_dly <= (others =>'0');
			h_ctl_dd <= (others =>'0');
		elsif (rising_edge(pxl_clk)) then
			h_ctl_dly <= h_ctl_reg;
			h_ctl_dd <= h_ctl_dly;
		end if;
	end process;

	CTL_O <= h_ctl_dd;

------------------------------------------------------------------
------               SYNC GENERATION                       -------
------------------------------------------------------------------


	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			h_sync_reg <= '0';
		elsif (rising_edge(pxl_clk)) then
			if (vga_running = '1') then
				if ((h_cntr_reg >= h_ps) and (h_cntr_reg < h_pe)) then
					h_sync_reg <= h_pol;
				else
					h_sync_reg <= not(h_pol);
				end if;
			else
				h_sync_reg <= '0';
			end if;
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			v_sync_reg <= '0';
		elsif (rising_edge(pxl_clk)) then
			if (vga_running = '1') then
				if ((v_cntr_reg >= v_ps) and (v_cntr_reg < v_pe)) then
					v_sync_reg <= v_pol;
				else
					v_sync_reg <= not(v_pol);
				end if;
			else
				v_sync_reg <= '0';
			end if;
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			v_sync_dly <= '0';
			h_sync_dly <= '0';
			v_sync_dd <= '0';
			h_sync_dd <= '0';
		elsif (rising_edge(pxl_clk)) then
			v_sync_dly <= v_sync_reg;
			h_sync_dly <= h_sync_reg;
			v_sync_dd <= v_sync_dly;
			h_sync_dd <= h_sync_dly;
		end if;
	end process;

	HSYNC_O <= h_sync_dd;
	VSYNC_O <= v_sync_dd;


--Signal a new frame to the VDMA at the end of the first non-visible line. This
--should allow plenty of time for the line buffer to fill between frames, before 
--data is required. The first fsync pulse is signaled during the VGA_INIT state.
	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			fsync_reg <= '0';
		elsif (rising_edge(pxl_clk)) then
			if ((((v_cntr_reg = v_fsync) and (h_cntr_reg = h_max)) and (vga_running = '1')) or (vga_state = VGA_INIT)) then
				fsync_reg <= '1';
			else
				fsync_reg <= '0';
			end if;
		end if;
	end process;

	FSYNC_O <= fsync_reg;

------------------------------------------------------------------
------                  DATA CAPTURE                       -------
------------------------------------------------------------------

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			video_dv <= not de_pol;
			video_dv_d <= not de_pol;
			video_dv_dd <= not de_pol;
		elsif (rising_edge(pxl_clk)) then
			video_dv_d <= video_dv;
			video_dv_dd <= video_dv_d;
			if ((vga_running = '1') and (v_cntr_reg >= v_dataens and v_cntr_reg < v_dataene) and (h_cntr_reg >= h_dataens and h_cntr_reg < h_dataene)) then
				video_dv <= de_pol;
			else
				video_dv <= not de_pol;
			end if;
		end if;
	end process;

	process (pxl_clk, locked)
	begin
		if (locked = '0') then
			data_reg <= (others => '0');
		elsif (rising_edge(pxl_clk)) then
			if (video_dv_d = de_pol) then
				data_reg <= S_AXIS_TDATA;
			else
				data_reg <= (others => '0');
			end if;
		end if;
	end process;

	S_AXIS_TREADY <= video_dv_d;
	DE_O <= video_dv_dd;

	DATA_O <= data_reg;

end Behavioral;

