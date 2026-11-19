# Physical radio: read-only serial session

[Captured session, 2026-11-19](2026-11-19-readonly-session.log)

This record was captured from a physical radio connected to an Apple Silicon
Mac through a Prolific USB serial adapter. It is separate from the simulated
EEPROM test in the repository root.

## Observed in this session

- Serial port: `/dev/cu.usbserial-110`, 38400 baud, 8N1.
- USB adapter: Prolific USB-Serial Controller D, VID `067B`, PID `2303`.
- A firmware-identification request (`0x0514`) received a framed `0x0515` reply.
- The radio reported firmware identifier **`OURUVK6X`**.
- Two `0x051B` reads of 16 bytes at address `0x0000` received matching `0x051C`
  responses. Returned address and length were validated by the existing reader.
- Both returned blocks had SHA-256
  `882df16045847bc0ae568dbd714b57cbc8ca8a8fa26e7651f91f06c067265e13`.
- No EEPROM-write, firmware-write, erase, or reset commands were sent.

## Capture method

The owner's existing Python read-only client was run locally through a logging
wrapper. Before forwarding serial bytes, the wrapper checked the outgoing
frame and CRC and allowed only the exact firmware query and the specific
16-byte read above. Other opcodes and read arguments were rejected before
reaching the serial port. The allowlist was checked against a known hello frame,
an EEPROM-write request, and an out-of-scope read before opening the hardware.

The transcript retains timestamps, outgoing frames, response opcodes/lengths,
firmware identification, and the repeated-read digest. Raw EEPROM/channel data,
USB serial numbers, device-specific response fields, and local source paths are
not included.

## Limits of the evidence

The reply integrity fields used a `0xFFFF` sentinel, not a verified CRC. The log
states that explicitly; valid framing is not presented as checksum verification.

The USB adapter does not identify the chassis model. The firmware string alone
does not establish the physical model or that the firmware is stock. This is a
successful physical read-only session, not an interrupted-write test or evidence
of atomic writes, calibration preservation across a write, or unbrickability.

The existing application source is private. Publishing this transcript does not
publish that application or represent it as an implemented Flutter application.
