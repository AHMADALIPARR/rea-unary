-- add_core.vhd -- rea-unary
-- Copyright (C) 2026 Ahmad Ali Parr
-- SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
--
-- Licensed under the GNU Affero General Public License v3 with an
-- additional no-AI-training term (see LICENSE). This code may not be
-- used to train machine-learning models.
-- provenance: producer=stage2/worker2 parents=[state-machine.md:b9223f82b948 recovery-spec.md] version=v1 full-sha256-in=PROVENANCE.json
-- Author's rights notice (Ahmad Ali Parr):
-- Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
-- Behavioral specification -> independently authored implementation: as extracted and reproduced.
-- ============================================================================
-- add_core.vhd — Worker 2 (rea-unary swarm), 2026-10-10
-- Synthesizable-subset VHDL for the recovered 01 D8 ADD EAX, EBX core.
--
-- Implements: EAX <- (EAX + EBX) mod 2^32 with the six x86 flags
--   (CF, PF, AF, ZF, SF, OF) per the standard Intel ADD definitions
--   (recovery-spec.md, hypotheses.jsonl h2 v1 (ALP)).
-- Unary-Boolean mapping: unary-mapping.md D1..D9 (+D13..D16 structural).
-- State machine: state-machine.md (FETCH/DECODE/EXECUTE/WRITEBACK).
--
-- STATUS: written to the synthesizable subset (no vendor primitives, no IP
-- cores, single clock, synchronous reset). Analyzed clean with GHDL 4.1.0
-- (`ghdl -a`, elaboration-level check only). NOT synthesized, NOT placed on
-- any FPGA/ASIC — no synthesis tool was run here.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity add_core is
  port (
    clk    : in  std_logic;
    reset  : in  std_logic;                     -- synchronous, active high
    start  : in  std_logic;                     -- level: latch operands
    a_in   : in  std_logic_vector(31 downto 0); -- EBX
    b_in   : in  std_logic_vector(31 downto 0); -- EAX (old)
    result : out std_logic_vector(31 downto 0); -- EAX (new)
    cf     : out std_logic;
    pf     : out std_logic;
    af     : out std_logic;
    zf     : out std_logic;
    sf     : out std_logic;
    -- NOTE: `of` is a VHDL reserved word, so the mandated port name `of`
    -- is written as the extended identifier `\of\` (same interface name).
    \of\     : out std_logic;
    done   : out std_logic
  );
end entity add_core;

architecture rtl of add_core is

  -- Mandated enumerated state type: exactly FETCH, DECODE, EXECUTE, WRITEBACK.
  type state_type is (FETCH, DECODE, EXECUTE, WRITEBACK);
  signal state : state_type;

  signal a_reg, b_reg : std_logic_vector(31 downto 0);
  signal sum_reg      : std_logic_vector(31 downto 0);
  signal cf_reg, pf_reg, af_reg : std_logic;
  signal zf_reg, sf_reg, of_reg : std_logic;

begin

  process (clk)
    variable carry : std_logic_vector(32 downto 0); -- carry(i) = carry into bit i
    variable s     : std_logic_vector(31 downto 0);
    variable p     : std_logic;                    -- parity accumulator
  begin
    if rising_edge(clk) then
      if reset = '1' then
        -- D16: reset-cleared registers (const-0)
        state    <= FETCH;
        a_reg    <= (others => '0');
        b_reg    <= (others => '0');
        sum_reg  <= (others => '0');
        cf_reg   <= '0'; pf_reg <= '0'; af_reg <= '0';
        zf_reg   <= '0'; sf_reg <= '0'; of_reg <= '0';
        result   <= (others => '0');
        cf <= '0'; pf <= '0'; af <= '0';
        zf <= '0'; sf <= '0'; \of\ <= '0';
        done     <= '0';
      else
        case state is

          when FETCH =>
            done <= '0';                            -- D14: done = 0 outside WRITEBACK
            if start = '1' then
              a_reg <= a_in;
              b_reg <= b_in;
              state <= DECODE;
            end if;

          when DECODE =>
            -- Opcode is fixed to the ADD encoding per A7 (01 D8 verified at
            -- offset 0x00 by od); DECODE is the one-cycle pipeline beat.
            done  <= '0';
            state <= EXECUTE;

          when EXECUTE =>
            -- Ripple-carry adder: the multi-input fan-in interior (A4).
            carry(0) := '0';                        -- D13: carry_0 tied off (const-0)
            for i in 0 to 31 loop
              s(i)       := a_reg(i) xor b_reg(i) xor carry(i);
              carry(i+1) := (a_reg(i) and b_reg(i)) or
                            (a_reg(i) and carry(i)) or
                            (b_reg(i) and carry(i));
            end loop;
            sum_reg <= s;
            cf_reg  <= carry(32);                   -- D6: CF = carry-out of bit 31
            af_reg  <= carry(4);                    -- D7: AF = carry-out of bit 3
            of_reg  <= carry(31) xor carry(32);      -- D8/D9: OF
            sf_reg  <= s(31);                       -- D1: SF = identity(r_31)
            if s = x"00000000" then
              zf_reg <= '1';                        -- D2/D3: ZF = AND of NOT r_i
            else
              zf_reg <= '0';
            end if;
            p := '0';
            for i in 0 to 7 loop
              p := p xor s(i);                      -- D4: identity per low bit
            end loop;
            pf_reg <= not p;                        -- D5: PF = NOT of XOR fan-in
            done   <= '0';
            state  <= WRITEBACK;

          when WRITEBACK =>
            -- D15: commit strobe (const-1 during WRITEBACK)
            result <= sum_reg;
            cf <= cf_reg;
            pf <= pf_reg;
            af <= af_reg;
            zf <= zf_reg;
            sf <= sf_reg;
            \of\ <= of_reg;
            done  <= '1';
            state <= FETCH;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;
