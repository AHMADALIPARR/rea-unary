<!-- Provenance: stage3 (worker3), v1. Parents: stage3/add_core.vhd,
     stage3/add_core_model.c, stage3/differential-log.txt, stage3/traces.csv.
     Full hashes in stage3/PROVENANCE.json. -->
# Hardware translation record — verified implementation → VHDL/RTL

## Author's rights notice

> The following is the author's notice, reproduced verbatim (attributed to
> Ahmad Ali Parr); it is not a finding or endorsement of the build swarm:
>
> *Author's rights notice (Ahmad Ali Parr):*
> *Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.*
> *Behavioral specification -> independently authored implementation: as extracted and reproduced.*

## Translation map (C11 model → VHDL RTL, no hand-waving)

Source side: `stage3/add_core_model.c` (cycle-accurate model).
Target side: `stage3/add_core.vhd`, entity `add_core`, architecture `rtl`.

| C11 model element | VHDL element | notes |
|---|---|---|
| `typedef enum {FETCH,DECODE,EXECUTE,WRITEBACK} state_t` | `type state_t is (FETCH, DECODE, EXECUTE, WRITEBACK)` in architecture declarative region | identical 4-state encoding intent |
| `core_t.state` | signal `state : state_t` | state register |
| `core_t.a_reg`, `core_t.b_reg` | signals `a_reg`, `b_reg : std_logic_vector(31 downto 0)` | operand registers |
| `core_t.result`, `cf…of`, `done` | ports `result`, `cf`, `pf`, `af`, `zf`, `sf`, `\of\`, `done` | `\of\` is an escaped identifier: `of` is a VHDL reserved keyword and cannot be a plain port name. The port is still named `of`. |
| `core_reset()` | `if reset = '1'` branch of `seq` process | synchronous, active-high reset; clears state to FETCH and all registers |
| `core_clock()` dispatch `switch(c->state)` | `case state is` inside `rising_edge(clk)` | one C call = one clock edge |
| `st_fetch()` | `when FETCH` branch | `done<='0'`; on `start='1'` latch `a_in`/`b_in` → DECODE |
| `st_decode()` | `when DECODE` branch | decode of `01 D8` (fixed ADD datapath) → EXECUTE |
| `st_execute()` | `when EXECUTE` branch | `sum33 := ('0' & unsigned(a_reg)) + ('0' & unsigned(b_reg))`; `result <= sum33(31 downto 0)`; `cf <= sum33(32)`; 5-bit half-adder for `af`; `parity_even8` for `pf`; sign-compare for `\of\` |
| `st_writeback()` | `when WRITEBACK` branch | `done <= '1'` for one cycle → FETCH |
| `addmod32()` in `addmod.c` | EXECUTE-branch arithmetic (33-bit `sum33`, 5-bit `sum5`, `parity_even8` function) | same flag equations; the C `uint64_t` carry model maps to the VHDL 33-bit/5-bit extended sums |
| `main()` vector loop | `tb_add_core.vhd` stimulus process | same 10 vectors, same order |

## Checked behavioral correspondence (executed)

- **C11 model `st_execute()` vs VHDL EXECUTE branch**: 10 shared test vectors;
  result + all six flags compared per vector between `add_core_model` output
  and `traces.csv` EXECUTE rows → **10/10 vectors match, 70/70 registers**.
- **Both vs real x86 silicon** (`diff-oracle`, inline-asm `ADD EAX,EBX` + PUSHF):
  C model vs silicon **70/70**; GHDL sim vs silicon **70/70**;
  total **140/140** (`differential-log.txt`).
- **Contract correspondence**: all 7 `add32.dfy` ensures-clauses evaluated
  against `addmod32` on the 10 shared vectors → **10/10** (`contract-check.log`).
- Artifacts on both sides are named above; the comparison is test-vector
  equivalence between the C11 model and the VHDL intent.

## Equivalence — labeled precisely

**Test-vector equivalence** between the C11 model and the VHDL simulation
(10 vectors, result + 6 flags, 70/70 match, plus 70/70 each vs silicon).
This is **NOT** formal equivalence checking: no combinational/sequential
equivalence tool was run, and no proof relates the RTL to the C model for
all inputs. Netlist-level equivalence: **NOT EXECUTED** (no synthesis
toolchain, no netlist exists).

## Timing — as far as can be stated without synthesis tooling

Timing checks **require synthesis/P&R tooling and are NOT EXECUTED here**.
Design intent, written down for the synthesis stage:

- **Clock intent**: single clock, 100 MHz target (10 ns period, as used in the
  GHDL testbench `clk <= not clk after 5 ns`). All registers update on the
  rising edge; there is exactly one clock domain.
- **Reset discipline**: synchronous, active-high. Every register
  (`state`, `a_reg`, `b_reg`, `result`, all flags, `done`) is assigned in the
  reset branch — no async reset, no uninitialized state.
- **Setup/hold intent**: inputs `a_in`/`b_in`/`start` are captured in
  `a_reg`/`b_reg` in FETCH; downstream logic (EXECUTE) reads only the
  registered copies, giving a full cycle of setup margin by construction.
  Outputs are registered (no combinational paths to pins).
- **Critical-path intent** (unverified): the 33-bit adder + flag logic in
  EXECUTE is the longest combinational chain; actual slack/fmax can only be
  determined by a synthesis tool.

## Synthesis → netlist

**NOT EXECUTED.** No synthesis toolchain is available in this environment
(no yosys, Vivado, Quartus; GHDL's synthesis support was not used).
`add_core.vhd` is written to the synthesizable RTL subset (single clock,
synchronous reset, no latches, no tri-states, no non-synthesizable
constructs) — that is a **design property**, not a claim that synthesis
succeeded. No netlist was produced.
