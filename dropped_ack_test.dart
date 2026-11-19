// Toy EEPROM layout, not a Quansheng memory map. No hardware access.
import 'dart:async';
import 'dart:math';

const pageSize = 8;
const calibrationStart = 48;

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

bool same(List<int> a, List<int> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => i).every((i) => a[i] == b[i]);

class MockRadio {
  final memory = List<int>.generate(64, (i) => i);
  final writeAddresses = <int>[];
  bool connected = true;
  bool dropNextAck = true;

  void requireConnection() {
    if (!connected) throw TimeoutException('Disconnected');
  }

  List<int> read(int address, int length) {
    requireConnection();
    return memory.sublist(address, address + length);
  }

  void write(int address, List<int> bytes) {
    requireConnection();
    check(
      address ~/ pageSize == (address + bytes.length - 1) ~/ pageSize,
      'Write crossed a page boundary',
    );
    // Deliberately no calibration guard here: the client must enforce it.
    memory.setRange(address, address + bytes.length, bytes);
    writeAddresses.add(address);
    if (dropNextAck) {
      dropNextAck = false;
      connected = false;
      throw TimeoutException('EEPROM written, but ACK lost');
    }
  }
}

enum Phase { idle, writing, reconnectRequired, verified, failed }

class Writer {
  Writer(this.radio);
  final MockRadio radio;
  Phase phase = Phase.idle;

  void apply(int start, List<int> target) {
    if (start < 0 || start + target.length > calibrationStart) {
      throw RangeError('Write overlaps protected memory');
    }
    phase = Phase.writing;
    try {
      for (var position = 0; position < target.length;) {
        final address = start + position;
        final count = min(
          pageSize - address % pageSize,
          target.length - position,
        );
        final chunk = target.sublist(position, position + count);
        // Always reread device state, including when resuming after ACK loss.
        if (!same(radio.read(address, count), chunk)) {
          radio.write(address, chunk);
          check(same(radio.read(address, count), chunk), 'Readback mismatch');
        }
        position += count;
      }
      phase = Phase.verified;
    } on TimeoutException {
      phase = Phase.reconnectRequired;
    } catch (_) {
      phase = Phase.failed;
      rethrow;
    }
  }
}

void main() {
  final radio = MockRadio();
  final writer = Writer(radio);
  final before = List<int>.of(radio.memory);
  final target = List<int>.generate(8, (i) => 90 + i);

  writer.apply(6, target); // First chunk fits addresses 6..7.
  check(writer.phase == Phase.reconnectRequired, 'Must stop on lost ACK');
  check(same(radio.writeAddresses, [6]), 'Must not send another write');
  final partial = List<int>.of(before)..setRange(6, 8, target.take(2));
  check(same(radio.memory, partial), 'Simulated EEPROM state is incorrect');

  radio.connected = true; // Same device; EEPROM survives reconnect.
  writer.apply(6, target);
  check(writer.phase == Phase.verified, 'Recovery did not finish');
  check(same(radio.memory.sublist(6, 14), target), 'Target differs');
  check(same(radio.writeAddresses, [6, 8]), 'Already-written chunk replayed');
  check(
    same(
      radio.memory.sublist(calibrationStart),
      before.sublist(calibrationStart),
    ),
    'Calibration changed',
  );

  final snapshot = List<int>.of(radio.memory);
  var refused = false;
  try {
    writer.apply(calibrationStart - 1, [1, 2]);
  } on RangeError {
    refused = true;
  }
  check(refused, 'Boundary-crossing write was accepted');
  check(same(radio.memory, snapshot), 'Rejected write changed EEPROM');
  check(same(radio.writeAddresses, [6, 8]), 'Rejected write reached device');

  print('PASS: dropped ACK stops writes; reconnect rereads and skips them');
  print('PASS: calibration unchanged; boundary-crossing write rejected');
}
