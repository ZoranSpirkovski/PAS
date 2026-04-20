[STA-01]
Target: skill:change-validation
Strength: OBSERVED
Behavior: Checking every modified file against the plan and reading actual content rather than trusting agent claims caught the nuance that hub-and-spoke's "Completion Gate" subsection is pattern-specific (intra-phase dispatch) and correctly retained, not a lifecycle duplication violation.
Context: The plan's verification criterion 6 says "No pattern file contains ... completion gate block ... inline" which could have been falsely flagged without reading the actual content at line 99 of hub-and-spoke.md.
