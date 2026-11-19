# Dart EEPROM recovery mock

A small, dependency-free Dart prototype for testing recovery from a lost write
acknowledgement. The mock device keeps its EEPROM contents when the connection
drops, so the client has to reread device state before continuing.

## Run

With Dart 3.14.1 installed:

```sh
dart analyze dropped_ack_test.dart
dart run dropped_ack_test.dart
```

No Flutter installation, hardware, or external packages are required.
Checks throw exceptions on failure, so they remain active without enabling Dart
assertions. A failing check exits with a nonzero status.

## What the test does

1. Writes the first page-bounded chunk to a simulated EEPROM.
2. Drops the connection after that write has taken effect, before the ACK arrives.
3. Checks that the client stops without sending the next chunk.
4. Reconnects the same mock device with its memory intact.
5. Rereads memory, skips the chunk already written, and writes the remaining chunk.
6. Verifies the requested bytes and checks that the calibration region is unchanged.
7. Attempts a write crossing into calibration and verifies it is rejected before
   any device write occurs.

The mock intentionally has no calibration guard of its own. The client must
enforce that boundary; the test verifies both memory contents and write history.

Expected output:

```text
PASS: dropped ACK stops writes; reconnect rereads and skips them
PASS: calibration unchanged; boundary-crossing write rejected
```

## Scope

The 64-byte EEPROM, 8-byte page size, and calibration boundary at address 48 are
**toy values**, not a memory map for any Quansheng radio.

This is a synchronous model of one completed-write/lost-ACK scenario and a
protected-memory boundary check. It does not implement a serial frame parser,
BLE/USB transport, arbitrary torn-write injection, or a full fuzz harness.

It demonstrates client recovery decisions against simulated state. It does not
make stock EEPROM writes atomic or establish that physical hardware cannot be
bricked. Actual radio support needs a verified model/firmware memory map and
hardware testing.

GitHub Actions runs static analysis and the same executable test on each push
and pull request.
