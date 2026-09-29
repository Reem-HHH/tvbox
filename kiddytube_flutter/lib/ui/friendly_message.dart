import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;

import '../cloud/cloud_client.dart';

const kKidCatalogLoadMessage =
    "Couldn't load shows. Check Wi-Fi and try again.";
const kKidPlaybackMessage = "This video couldn't play. Try another one.";
const kKidRefreshMessage = "Couldn't refresh. Check Wi-Fi.";

/// Maps thrown errors to a short parent-facing sentence (no raw types/stacks).
String friendlyParentError(Object error) {
  if (error is CloudException) {
    final message = error.message.trim();
    return message.isEmpty ? 'Cloud request failed. Try again.' : message;
  }
  if (error is TimeoutException) {
    return 'That took too long. Try again.';
  }
  if (error is SocketException || error is ClientException) {
    return 'Check Wi-Fi and try again.';
  }
  if (error is ArgumentError) {
    final message = error.message;
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  if (error is FormatException) {
    return "That didn't look right. Try again.";
  }
  if (error is StateError) {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return 'Something went wrong. Try again.';
}
