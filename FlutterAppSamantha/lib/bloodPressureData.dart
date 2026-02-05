import 'dart:developer' as dev;
import 'package:intl/intl.dart';

class BloodPressureParser {
  /// Parse an IEEE-11073 16-bit SFLOAT from two little-endian bytes.
  /// For BP readings (mmHg), the exponent is typically 0, so the value
  /// is just the mantissa. This handles the common case correctly.
  int _parseSfloat16(int lo, int hi) {
    int raw = (hi << 8) | lo;
    // Mantissa is lower 12 bits (signed), exponent is upper 4 bits (signed)
    int mantissa = raw & 0x0FFF;
    if (mantissa >= 0x0800) mantissa -= 0x1000; // sign extend
    int exponent = (raw >> 12) & 0x0F;
    if (exponent >= 0x08) exponent -= 0x10; // sign extend
    // For BP values the exponent is 0 so this just returns mantissa
    if (exponent == 0) return mantissa;
    // Otherwise compute the actual value
    double value = mantissa * _pow10(exponent);
    return value.round();
  }

  double _pow10(int exp) {
    double result = 1.0;
    if (exp > 0) {
      for (int i = 0; i < exp; i++) result *= 10;
    } else {
      for (int i = 0; i < -exp; i++) result /= 10;
    }
    return result;
  }

  /// Parse Blood Pressure Measurement characteristic (0x2A35) per Bluetooth SIG spec.
  ///
  /// Format:
  ///   Byte 0:      Flags
  ///   Bytes 1-2:   Systolic (SFLOAT, mmHg)
  ///   Bytes 3-4:   Diastolic (SFLOAT, mmHg)
  ///   Bytes 5-6:   MAP (SFLOAT, mmHg)
  ///   Bytes 7-13:  Timestamp (if flags bit 1 set): year(2), month, day, hour, min, sec
  ///   Next 2 bytes: Pulse Rate (SFLOAT, if flags bit 2 set)
  Future<Map<DateTime, List<int>>> parseBloodPressureDataWithTimestamp(List<int> data) async {
    if (data.length < 7) {
      dev.log('BP data too short (${data.length} bytes): $data');
      return {};
    }

    dev.log('Raw BP data (${data.length} bytes): $data');

    int flags = data[0];
    bool hasTimestamp = (flags & 0x02) != 0;
    bool hasPulseRate = (flags & 0x04) != 0;

    int systolic = _parseSfloat16(data[1], data[2]);
    int diastolic = _parseSfloat16(data[3], data[4]);

    dev.log('Parsed: systolic=$systolic, diastolic=$diastolic, flags=0x${flags.toRadixString(16)}');

    // Parse timestamp if present
    DateTime dateTime;
    int nextOffset = 7;
    if (hasTimestamp && data.length >= 14) {
      int year = data[7] | (data[8] << 8);
      int month = data[9];
      int day = data[10];
      int hour = data[11];
      int minute = data[12];
      int second = data[13];
      dateTime = DateTime(year, month, day, hour, minute, second);
      nextOffset = 14;
      dev.log('Timestamp: $dateTime');

      // Sanity check
      final currentYear = DateTime.now().year;
      if (dateTime.year < 2020 || dateTime.year > currentYear + 5) {
        dev.log('Invalid timestamp year (${dateTime.year}), using current time');
        dateTime = DateTime.now();
      }
    } else {
      dateTime = DateTime.now();
      dev.log('No timestamp in data, using current time');
    }

    // Parse pulse rate if present
    int pulse = 0;
    if (hasPulseRate && data.length > nextOffset + 1) {
      pulse = _parseSfloat16(data[nextOffset], data[nextOffset + 1]);
      dev.log('Pulse rate: $pulse');
    }

    DateTime localDateTime = dateTime.toLocal();

    return {
      localDateTime: [systolic, diastolic, pulse],
    };
  }

  // Parse the received data (simple version without timestamp)
  static Future<Map<String, int>> parseBloodPressureData(List<int> data) async {
    if (data.length < 7) return {};

    int flags = data[0];
    bool hasPulseRate = (flags & 0x04) != 0;
    bool hasTimestamp = (flags & 0x02) != 0;

    // SFLOAT values — for typical BP readings, just use the low byte
    int systolic = data[1] | ((data[2] & 0x0F) << 8);
    int diastolic = data[3] | ((data[4] & 0x0F) << 8);
    int mapVal = data[5] | ((data[6] & 0x0F) << 8);

    int pulse = 0;
    int pulseOffset = hasTimestamp ? 14 : 7;
    if (hasPulseRate && data.length > pulseOffset + 1) {
      pulse = data[pulseOffset] | ((data[pulseOffset + 1] & 0x0F) << 8);
    }

    return {
      'systolic': systolic,
      'diastolic': diastolic,
      'map': mapVal,
      'pulse': pulse,
    };
  }

  static List<List<String>> processBloodPressureData(List<Map<DateTime, List<int>>> bloodPressureData,
      String user,
      String deviceId) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return bloodPressureData.expand((entry) {
      return entry.entries.map((e) {
        final formattedTime = '${dateFormat.format(e.key.toUtc())} GMT';
        final values = e.value.isEmpty ? [0, 0, 0] : e.value;

        // Create a row where each value is in its own column
        return [
          formattedTime, // Date and time
          user,          // User information
          deviceId,      // Device ID
          ...values.map((v) => v.toString()) // Expand each integer into its own column
        ];
      }).toList();
    }).toList();
  }
}
