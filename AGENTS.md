# Trailer Fingerprint working conventions

- Batch related edits and validate locally. Commit or push only when explicitly
  requested.
- Keep Markdown documentation current in the same change as implementation or
  research findings. Update README.md for user-visible behavior and
  docs/PROJECT_STATUS.md for current evidence, limits, validation and next steps.
  Update the relevant technical document; mark old version descriptions historical.
- Preserve the distinction between verified observations, interpretations,
  synthetic fixtures and researcher-supplied captures with incomplete context.
- A request destination is not an observed source. A component serial is not by
  itself permanent physical-equipment identity. Never manufacture an identity
  from telemetry, opaque vendor data or missing responses.
- Preserve original research captures byte-for-byte under captures/private/
  (ignored). Document hashes, provenance and extraction for checked-in excerpts.
- Run zig build test and appropriate replay checks for parser/ingest changes.
  Record material limitations and keep changes local unless publishing is requested.
- Keep contributor guidance concise in README.md. Link to existing authoritative
  documents instead of adding duplicate guides, templates or speculative roadmaps.
- Project documentation must be self-contained and technical. Exclude chat
  summaries, personal correspondence status, assistant activity reports and
  conversational workflow notes. Retain necessary source attribution, reproducible
  evidence, implementation limits and contributor instructions. Keep operational
  agent instructions in this file rather than product/research documentation.
