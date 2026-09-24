# Trailer Fingerprint Software (TFS)

TFS explores persistent identity for heavy-duty towed equipment
using observations of its electronic components. Controllers can be replaced or
moved; a controller serial alone does not establish permanent trailer identity.

**The current tool inspects recorded J1708/J1587 traffic and reports component
observations.** Physical-equipment matching is a separate synthetic experiment.
Neither is field-validated trailer identification. Shared history remains a design.

## Run

Use **Zig 0.16.0** from the repository root. No hardware is needed for the fixtures.

```sh
zig build test
zig build run
zig build run -- path/to/capture.j1708log
zig build synthetic
```

The default run includes fictional identity fixtures, public telemetry and an
attributed authentic request-only excerpt. `.tfc` files use the project's strict
interchange format; external logs pass through a record audit. Output separates
source MIDs, request destinations, opaque records and decoded observations.
No command transmits diagnostic requests. SocketCAN input is rejected.

Start with the [protocol and domain guide](docs/PROTOCOL_REPLAY.md), then see
[current scope and completion criteria](docs/PROJECT_STATUS.md).
[Research corpus](docs/RESEARCH_CORPUS.md) records capture provenance and limits;
[replay internals](docs/REPLAY_PIPELINE.md) explains the code boundary.

## Contribute

Useful contributions are small protocol corrections with a reproducer, review of
logger/checksum conventions, and shareable identity-bearing diagnostic captures.
For a capture, include origin, adapter/logger, equipment context, checksum handling
and whether requests were active. Mark unknowns and redactions explicitly; share
only data you have permission to share. A positive identity claim needs observed
bytes and an independently confirmed identifier.

For a bug, provide expected versus observed behavior and the smallest useful input.
Discuss larger features in an issue first. Run tests and affected replays, and
update the existing relevant documentation with code changes.

Parser work starts in [capture_audit.zig](src/capture_audit.zig) and
[j1587.zig](src/j1587.zig). The [experimental matcher](docs/FINGERPRINT_ENGINE.md)
and [shared-history design](docs/NETWORK_MODEL.md) describe longer-term work.
Electrical experiments remain separate under `zig build diagnostics`.

## A note on purpose

TFS is built with the belief that useful knowledge is worth sharing, and that
understanding the equipment we depend on can make everyday work a little easier.

Behind every repair, part number and software tool are people whose time and
livelihoods matter. That is worth remembering as this project grows.

Commercial use and independent forks are welcome. This statement adds no
conditions to the MIT license.

## License

Original project code and documentation are licensed under [MIT](LICENSE).
Third-party material retains its own terms; the MIT grant does not relicense
research captures or their excerpts. See the [research capture record](docs/RESEARCH_CORPUS.md#permissions).
