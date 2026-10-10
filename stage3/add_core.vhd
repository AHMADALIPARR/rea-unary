-- add_core.vhd -- rea-unary
-- Copyright (C) 2026 Ahmad Ali Parr
-- SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
--
-- Licensed under the GNU Affero General Public License v3 with an
-- additional no-AI-training term (see LICENSE). This code may not be
-- used to train machine-learning models.
-- Author's rights notice (Ahmad Ali Parr):
-- Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
-- Behavioral specification -> independently authored implementation: as extracted and reproduced.
-- Provenance: stage3 (worker3), v1. Parents: stage1/sample.md (983584eaf...), mandated
--   interface (D). Full hashes in stage3/PROVENANCE.json.
-- add_core: 32-bit ADD unit recovering the semantics of x86 `01 D8` (ADD EAX, EBX).
-- Canonical IR: %result = add.i32 %a, %b / store.i32 %result, %destination
-- Formal: result = \addmod{a}{b}{2^{32}} (wraparound, no carry beyond bit 31).
-- Flags per documented Intel ADD semantics: CF=carry-out bit31; PF=even parity of
-- result[7:0]; AF=carry-out of bit3; ZF=(result==0); SF=result[31];
-- OF=(carry into bit31) XOR (carry out of bit31).
-- Written to the synthesizable RTL subset (single clock, synchronous reset, no
-- latches, no tri-states). Synthesis NOT executed here (no toolchain) -- see README.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity add_core is
  port (
    clk    : in  std_logic;
    reset  : in  std_logic; -- synchronous, active high
    start  : in  std_logic;
    a_in   : in  std_logic_vector(31 downto 0);
    b_in   : in  std_logic_vector(31 downto 0);
    result : out std_logic_vector(31 downto 0);
    cf     : out std_logic;
    pf     : out std_logic;
    af     : out std_logic;
    zf     : out std_logic;
    sf     : out std_logic;
    \of\    : out std_logic; -- escaped: `of` is a VHDL reserved keyword
    done   : out std_logic
  );
end entity add_core;

architecture rtl of add_core is
  type state_t is (FETCH, DECODE, EXECUTE, WRITEBACK);
  signal state : state_t;
  signal a_reg : std_logic_vector(31 downto 0);
  signal b_reg : std_logic_vector(31 downto 0);

  -- '1' when the 8-bit vector holds an even number of 1-bits (x86 PF semantics).
  function parity_even8(x : std_logic_vector(7 downto 0)) return std_logic is
    variable p : std_logic := '0';
  begin
    for i in x'range loop
      p := p xor x(i);
    end loop;
    return not p;
  end function parity_even8;
begin

  seq : process (clk)
    variable sum33 : unsigned(32 downto 0); -- 33-bit: captures carry-out of bit31
    variable sum5  : unsigned(4 downto 0);  -- 5-bit: captures carry-out of bit3
    variable r     : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state  <= FETCH;
        a_reg  <= (others => '0');
        b_reg  <= (others => '0');
        result <= (others => '0');
        cf <= '0'; pf <= '0'; af <= '0';
        zf <= '0'; sf <= '0'; \of\ <= '0';
        done <= '0';
      else
        case state is
          when FETCH =>
            done <= '0';
            if start = '1' then
              a_reg <= a_in;
              b_reg <= b_in;
              state <= DECODE;
            end if;
          when DECODE =>
            -- decode of 01 D8: ADD r/m32, r32 -> computes a_reg + b_reg
            state <= EXECUTE;
          when EXECUTE =>
            -- \addmod{a}{b}{2^{32}} : 32-bit wraparound addition
            sum33 := ('0' & unsigned(a_reg)) + ('0' & unsigned(b_reg));
            r     := std_logic_vector(sum33(31 downto 0));
            result <= r;
            cf <= sum33(32); -- carry-out of bit31
            sum5 := ('0' & unsigned(a_reg(3 downto 0)))
                  + ('0' & unsigned(b_reg(3 downto 0)));
            af <= sum5(4);   -- carry-out of bit3
            zf <= '1' when r = x"00000000" else '0';
            sf <= r(31);
            pf <= parity_even8(r(7 downto 0));
            \of\ <= (a_reg(31) and b_reg(31) and (not r(31))) or
                  ((not a_reg(31)) and (not b_reg(31)) and r(31));
            state <= WRITEBACK;
          when WRITEBACK =>
            done  <= '1';
            state <= FETCH;
        end case;
      end if;
    end if;
  end process seq;

end architecture rtl;
