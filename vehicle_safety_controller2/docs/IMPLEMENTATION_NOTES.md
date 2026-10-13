# Implementation contract v0.2

This file clarifies the architecture proposal and takes precedence for the delivered RTL.

- RTL is Verilog-2001 style; testbenches use SystemVerilog. No UVM or vendor IP is required.
- Configuration is by elaboration parameters, not a software register interface. The synthesis default is variant B (deterministic controller plus monitor veto). `USE_MONITOR=0, USE_MLP=0` selects variant A. C/D require a trained ROM before they are useful.
- Input and output logic is integrated into the top/FSM modules rather than adding a trivial separate output module. The separation of responsibilities is preserved.
- `can_frame_valid` is an observation, not a ready/valid handshake. There is no FIFO. Busy arrivals are monitored and diagnosed but not queued. Valid clearance is recognized even while busy.
- Single emergency-ID slot; no multiple-vehicle arbitration or route planning. Sequence bytes are not cryptographic anti-replay counters.
- Timers count global sampled tick enables. From a non-tick event, N ticks occur after between approximately (N-1) and N tick periods. Stability specifications are consecutive samples, not a guaranteed minimum wall-clock delay of N ms. Tight real-world deadline requirements need phase-aware timing or clock-cycle timers.
- A captured clearance is not itself a cancelled active job; its completion normally reports no active request (code 0). A subsequent clearance during a captured active job reports cancellation (code 5).
- A new clearance on the terminal recovery tick resets recovery counting; it cannot complete recovery on the same edge.
- Runtime fault wins over clearance, lease expiry wins over a same-edge renewal, and clearance wins over a same-edge successful classification. Reset wins over everything.
- Valid active observations during clearance reset clearance stability even if their eventual classification is denied. They may delay recovery; total recovery timeout bounds this to HOLD.
- `fault_status` reflects HOLD. Suspicious, uncertain and overrun status latch until reset or healthy acknowledged idle. Requests and monitors continue to be observed during HOLD; new classification jobs do not start there.
- While the shipped ROM is invalid, enabling MLP puts the controller in HOLD. Generated arithmetic fixtures are never loaded as the production ROM. The adapter test uses explicitly identified hierarchical force/release to test otherwise unreachable classifier outcomes.
- The engine's ROM is combinational. Replacing it with synchronous memory changes latency and requires an RTL change, not merely a new file.
- Feature values must be 0..127. Exported weights are signed -128..127. Exported bias magnitude is limited to 2^20. These are enforced in the Python reference/exporter and guaranteed by the top-level feature extractor, not by arbitrary external inputs to a standalone core.
- `MARGIN_MIN` uses raw accumulator-score units (1/16384). It is not a probability. Ties are uncertain regardless of the threshold.
- Parameter restrictions: TICK_CYCLES and WINDOW_TICKS >=1; timer values LEASE/CLEAR/RECOVERY/RECOVERY_TIMEOUT and WATCHDOG 1..65535; RATE_LIMIT 0..254; DUP_LIMIT 1..255; DUP_GAP_TICKS 1..255. Use meaningful timeout > CLEAR+RECOVERY. RTL assumes legal elaboration parameters; no dynamic configuration validation hardware is added.
- Global tick frequency must be updated if the implementation clock target changes. Synthesis timing closure and changing a clock constraint do not automatically change TICK_CYCLES.
- Structural-check output counts represent generic Yosys operations, not ASIC standard-cell area or gate equivalents. Do not use them as 45/90 nm PPA.

## Known limitations

A tumbling rate window can miss bursts straddling a window boundary. Identical legitimate retransmissions can trigger duplicate veto. Observationally identical spoofing cannot be distinguished by the MLP. Flooding can cause request loss/denial of service. No FIFO, complete CAN protocol, sensor processing, authenticated gateway, fault-tolerant cells, scan/ATPG or automotive certification is implemented. Physical implementation and trained-model evaluation remain future stages.
