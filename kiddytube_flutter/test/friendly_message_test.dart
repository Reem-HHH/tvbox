import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:kiddytube/cloud/cloud_client.dart';
import 'package:kiddytube/ui/friendly_message.dart';

void main() {
  test('friendlyParentError maps known types', () {
    expect(
      friendlyParentError(CloudException('Pairing failed')),
      'Pairing failed',
    );
    expect(
      friendlyParentError(TimeoutException('x')),
      'That took too long. Try again.',
    );
    expect(
      friendlyParentError(const SocketException('Failed host lookup')),
      'Check Wi-Fi and try again.',
    );
    expect(
      friendlyParentError(ClientException('Connection closed')),
      'Check Wi-Fi and try again.',
    );
    expect(
      friendlyParentError(ArgumentError('PIN must be 4–8 digits')),
      'PIN must be 4–8 digits',
    );
    expect(
      friendlyParentError(const FormatException('bad json')),
      "That didn't look right. Try again.",
    );
    expect(
      friendlyParentError(StateError('Change the default PIN first')),
      'Change the default PIN first',
    );
    expect(
      friendlyParentError(Exception('secret stack')),
      'Something went wrong. Try again.',
    );
  });

  test('kid copy is short and has no exception text', () {
    expect(kKidCatalogLoadMessage.contains('Exception'), isFalse);
    expect(kKidPlaybackMessage.contains('Exception'), isFalse);
    expect(kKidRefreshMessage.contains('Exception'), isFalse);
  });
}
