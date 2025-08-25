# Out-of-Order RISC-V Processor (RV32IM)

This project implements an educational **out-of-order RISC-V processor** supporting the **RV32IM** instruction set. The core is **single-issue, single-commit**, focusing on clarity of design while demonstrating modern CPU concepts.

## Features
- **ISA:** RV32I + M (multiply/divide)
- **Pipeline:** Fetch → Decode/Rename → Dispatch → Issue/Execute → Writeback → Commit
- **Out-of-Order Machinery:** Register renaming, Reorder Buffer (ROB), Reservation Stations (RS), Physical Register File (PRF), Load/Store Queue (LSQ)
- **Branch Prediction:** GShare predictor with BTB + RAS
- **Memory System:** 4-way set-associative caches (write-back, write-allocate)
- **Exceptions:** Precise exceptions handled at commit

## Microarchitecture
- **Rename:** RAT + free list for register renaming; speculative map tables with rollback on mispredicts  
- **Issue/Execute:** RS-based scheduling, tag broadcast/wakeup, per-FU issue  
- **Memory:** LSQ for ordering; store→load forwarding; cache-backed memory subsystem  
- **Branching:** GShare predictor with history-based updates; mispredict recovery via RAT checkpointing  
- **Commit:** In-order retirement via ROB
