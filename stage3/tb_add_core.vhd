-- tb_add_core.vhd -- rea-unary
-- Copyright (C) 2026 Ahmad Ali Parr
-- SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
--
-- Licensed under the GNU Affero General Public License v3 with an
-- additional no-AI-training term (see LICENSE). This code may not be
-- used to train machine-learning models.
-- Provenance: stage3 (worker3), v1. Testbench for add_core (Worker 3 reference RTL).
-- Drives the 10 canonical test vectors, dumps cycle-by-cycle traces to traces.csv
-- via std.textio. The `state` column is tracked by a shadow FSM in this testbench
-- that implements the DUT's exact transition function (FETCH -start-> DECODE ->
-- EXECUTE -> WRITEBACK -> FETCH); it is cross-checked by the DUT's own `done`
-- output (SQL check: done=1 exactly on WRITEBACK rows). Full hashes in PROVENANCE.json.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_add_core is
end entity tb_add_core;

architecture sim of tb_add_core is
  signal clk    : std_logic := '0';
  signal reset  : std_logic := '1';
  signal start  : std_logic := '0';
  signal a_in   : std_logic_vector(31 downto 0) := (others => '0');
  signal b_in   : std_logic_vector(31 downto 0) := (others => '0');
  signal result : std_logic_vector(31 downto 0);
  signal cf, pf, af, zf, sf, \of\, done : std_logic; -- \of\: `of` is reserved in VHDL

  type vec_t is record
    a : std_logic_vector(31 downto 0);
    b : std_logic_vector(31 downto 0);
  end record;
  type vec_arr is array (natural range <>) of vec_t;
  constant VECTORS : vec_arr := (
    (x"00000000", x"00000000"), -- 0: zero + zero (ZF)
    (x"FFFFFFFF", x"00000001"), -- 1: wraparound (CF)
    (x"7FFFFFFF", x"00000001"), -- 2: signed overflow (OF); counterexample vector
    (x"00000008", x"00000008"), -- 3: half-carry (AF)
    (x"00000003", x"00000000"), -- 4: even parity (PF=1)
    (x"00000001", x"00000000"), -- 5: odd parity (PF=0)
    (x"80000000", x"80000000"), -- 6: CF=1, OF=0
    (x"7FFFFFFF", x"7FFFFFFF"), -- 7: OF=1, CF=0
    (x"80000000", x"FFFFFFFF"), -- 8: CF=1, OF=1
    (x"FFFFFFFF", x"FFFFFFFF")  -- 9: CF=1, OF=0, max+max
  );

  function sl_to_char(s : std_logic) return character is
  begin
    if s = '1' then return '1'; else return '0'; end if;
  end function;

  type state_t_tb is (FETCH, DECODE, EXECUTE, WRITEBACK);
  function state_name(s : state_t_tb) return string is
  begin
    case s is
      when FETCH     => return "FETCH";
      when DECODE    => return "DECODE";
      when EXECUTE   => return "EXECUTE";
      when WRITEBACK => return "WRITEBACK";
    end case;
  end function;

  file trace_f : text;
begin

  dut : entity work.add_core(rtl)
    port map (clk, reset, start, a_in, b_in, result, cf, pf, af, zf, sf, \of\, done);

  clk <= not clk after 5 ns; -- 100 MHz single clock

  -- cycle-by-cycle trace writer. Samples the DUT's post-edge outputs 1 ns after
  -- each rising edge and advances a shadow FSM with the DUT's exact transition
  -- function, so the recorded state is the DUT's state for that cycle.
  writer : process
    variable line_v  : line;
    variable cyc     : integer := 0;
    variable shadow  : state_t_tb := FETCH;
    variable start_s : std_logic;
  begin
    wait until rising_edge(clk);
    loop
      -- Sample `start` in the edge's own simulation cycle, exactly as the DUT's
      -- clocked process does. (Sampling it after `wait for 1 ns` would see a
      -- value the DUT never saw, because stim (de)asserts start in deltas of
      -- the edge cycle -- this caused a one-state skew in an earlier revision.)
      start_s := start;
      wait for 1 ns; -- let the DUT's registered updates settle
      if reset = '1' then
        shadow := FETCH;
      else
        -- write FIRST with the pre-edge shadow: this is the state whose actions
        -- the DUT performed at this edge, so the sampled outputs belong to it.
        write(line_v, cyc);                       write(line_v, ',');
        write(line_v, state_name(shadow));        write(line_v, ',');
        write(line_v, to_hstring(a_in));           write(line_v, ',');
        write(line_v, to_hstring(b_in));           write(line_v, ',');
        write(line_v, to_hstring(result));         write(line_v, ',');
        write(line_v, sl_to_char(cf));             write(line_v, ',');
        write(line_v, sl_to_char(pf));             write(line_v, ',');
        write(line_v, sl_to_char(af));             write(line_v, ',');
        write(line_v, sl_to_char(zf));             write(line_v, ',');
        write(line_v, sl_to_char(sf));             write(line_v, ',');
        write(line_v, sl_to_char(\of\));           write(line_v, ',');
        write(line_v, sl_to_char(done));
        writeline(trace_f, line_v);
        cyc := cyc + 1;
        case shadow is                       -- DUT transition function, mirrored
          when FETCH =>
            if start_s = '1' then shadow := DECODE; end if;
          when DECODE    => shadow := EXECUTE;
          when EXECUTE   => shadow := WRITEBACK;
          when WRITEBACK => shadow := FETCH;
        end case;
      end if;
      wait until rising_edge(clk);
    end loop;
  end process writer;

  stim : process
    variable line_v : line;
  begin
    file_open(trace_f, "traces.csv", write_mode);
    write(line_v, string'("cycle,state,a_in,b_in,result,cf,pf,af,zf,sf,of,done"));
    writeline(trace_f, line_v);

    reset <= '1';
    wait for 25 ns;
    reset <= '0';
    wait until rising_edge(clk);

    for i in VECTORS'range loop
      a_in <= VECTORS(i).a;
      b_in <= VECTORS(i).b;
      wait until rising_edge(clk);   -- settle inputs while in FETCH
      start <= '1';
      wait until rising_edge(clk);   -- DUT samples start -> DECODE
      wait for 2 ns;                 -- hold start past the edge+1ns trace sample
      start <= '0';                  -- (writer samples start at edge+1ns)
      wait until done = '1';         -- WRITEBACK asserted done
      wait until rising_edge(clk);   -- back to FETCH, done deasserts
    end loop;

    wait for 30 ns;
    file_close(trace_f);
    report "tb_add_core: all vectors done, traces.csv written";
    finish;
  end process stim;

end architecture sim;
