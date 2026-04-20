[STA-01]
Target: skill:implementation-planning
Strength: OBSERVED
Behavior: Reading all source files before specifying changes prevented incorrect file path references and wrong line numbers. Every path in the plan was verified against the actual codebase.
Context: The discovery phase produced 6 files with many specific claims about file contents and line numbers. Without reading the actual source, I would have propagated unverified claims into the plan (e.g., the DX audit says "crystal clarity" appears in 3 files — I verified it actually appears in 5 files within plugins/pas/ when counting the process.md reference).
