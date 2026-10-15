# TuringCore

A deterministic, single-tape Turing machine: `(Q, Σ, Γ, δ, q₀, q_accept, q_reject)` with a distinguished blank in Γ. The tape is indexed by signed coordinates and has a blank default in both directions. A sparse dictionary stores only nonblank cells. Symbols are atomic strings, including user-defined multi-character tokens.

`δ : (Q \ {q_accept, q_reject}) × Γ ⇀ Q × Γ × {L, R}` is a partial function. Each successful step reads the current cell, writes one symbol, moves exactly one cell, and enters the destination state as one atomic operation. Missing δ means **stuck**, an outcome distinct from entering **reject**. No operation executes once a terminal state is reached. Undo can reverse a transition into a terminal state.

The model has no arbitrary execution limit. Finite memory and signed `Int` coordinates/step counts are the implementation limits; overflow is detected before mutation and yields an explicit stuck diagnostic. A simulator cannot decide whether every arbitrary program eventually halts.

Initial input occupies cells `0...` and uses Σ, with optional blank gaps. Restored configurations and manual tape edits may use all of Γ. Editing a symbol or moving the head preserves state, tape, and successful-step count, clears the undo trace and last-step display, and recomputes status. `reset()` restores the program's original input. Restore validates and canonicalizes the sparse tape.

The history is a bounded circular buffer of 4,096 reversible deltas; it stores overwritten symbols, prior state/head/status, and the prior last-step record, rather than complete tape snapshots. Undo depth is independent of the full execution step count.

Presets include binary increment, unary doubling, binary-palindrome recognition, bit inversion, a provably nonhalting two-state clockwork loop, and both three-state/two-symbol busy beaver champions: maximum steps (21 transitions, five 1s) and maximum marks (14 transitions, six 1s). These are different machines. Exact tables and outcomes are checked against Shawn Ligocki's [complete enumeration of halting three-state/two-symbol machines](https://github.com/sligocki/busy-beaver/blob/main/Machines/bb/3x2.txt), with the [Busy Beaver Challenge's domain page](https://wiki.bbchallenge.org/wiki/BB(3)) providing notation and context. The classical result is Lin and Radó, [Computer Studies of Turing Machine Problems, JACM 12(2), 1965](https://doi.org/10.1145/321264.321270).

Run verification with:

```sh
swift test --scratch-path /tmp/TuringCore-build
```

In a filesystem sandbox, direct module and package caches to the temporary directory:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/TuringCore-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/TuringCore-swift-cache swift test --disable-sandbox --scratch-path /tmp/TuringCore-build --cache-path /tmp/TuringCore-cache --config-path /tmp/TuringCore-config --security-path /tmp/TuringCore-security
```
