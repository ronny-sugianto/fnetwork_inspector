import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// A single in-memory mock rule. When a request matches [method] + [pathPattern],
/// the interceptor short-circuits the network call and returns a synthetic
/// response built from [statusCode], [contentType] and [body].
@immutable
class FMockRule {
  const FMockRule({
    required this.id,
    required this.pathPattern,
    this.method,
    this.statusCode = 200,
    this.contentType = 'application/json',
    this.body = '',
    this.isBase64 = false,
    this.delayMs = 0,
    this.enabled = true,
  });

  /// Rebuilds a rule from [toJson] output. Missing fields fall back to
  /// defaults; a missing `id` gets a fresh one.
  factory FMockRule.fromJson(Map<String, dynamic> json) {
    return FMockRule(
      id: json['id'] as String? ?? const Uuid().v4(),
      pathPattern: json['pathPattern'] as String? ?? '',
      method: json['method'] as String?,
      statusCode: (json['statusCode'] as num?)?.toInt() ?? 200,
      contentType: json['contentType'] as String? ?? 'application/json',
      body: json['body'] as String? ?? '',
      isBase64: json['isBase64'] as bool? ?? false,
      delayMs: (json['delayMs'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Creates a rule with a generated [id].
  factory FMockRule.create({
    required String pathPattern,
    String? method,
    int statusCode = 200,
    String contentType = 'application/json',
    String body = '',
    bool isBase64 = false,
    int delayMs = 0,
    bool enabled = true,
  }) {
    return FMockRule(
      id: const Uuid().v4(),
      pathPattern: pathPattern,
      method: method,
      statusCode: statusCode,
      contentType: contentType,
      body: body,
      isBase64: isBase64,
      delayMs: delayMs,
      enabled: enabled,
    );
  }

  final String id;

  /// Matched against the request path (query string stripped). If it contains
  /// `*` it is treated as a glob (anchored, `*` = any run of characters);
  /// otherwise it is a plain substring match.
  final String pathPattern;

  /// HTTP method to match, case-insensitive. `null` matches any method.
  final String? method;

  final int statusCode;
  final String contentType;

  /// Response body. Plain text (JSON / HTML / XML / …) unless [isBase64] is set,
  /// in which case it is a base64 string decoded to bytes when served.
  final String body;
  final bool isBase64;

  /// Artificial latency before the mocked response resolves.
  final int delayMs;

  final bool enabled;

  FMockRule copyWith({
    String? pathPattern,
    Object? method = _sentinel,
    int? statusCode,
    String? contentType,
    String? body,
    bool? isBase64,
    int? delayMs,
    bool? enabled,
  }) {
    return FMockRule(
      id: id,
      pathPattern: pathPattern ?? this.pathPattern,
      method: identical(method, _sentinel) ? this.method : method as String?,
      statusCode: statusCode ?? this.statusCode,
      contentType: contentType ?? this.contentType,
      body: body ?? this.body,
      isBase64: isBase64 ?? this.isBase64,
      delayMs: delayMs ?? this.delayMs,
      enabled: enabled ?? this.enabled,
    );
  }

  static const Object _sentinel = Object();

  /// The response body as bytes. Text bodies are UTF-8 encoded; base64 bodies
  /// are decoded (returns an empty list if the string is not valid base64).
  List<int> get bodyBytes {
    if (isBase64) {
      try {
        return base64.decode(base64.normalize(body.trim()));
      } catch (_) {
        return const <int>[];
      }
    }
    return utf8.encode(body);
  }

  /// Whether this rule matches the request, honouring [enabled].
  bool matches(String requestMethod, String requestPath) =>
      enabled && patternMatches(requestMethod, requestPath);

  /// Whether the method + path pattern match the request, ignoring [enabled].
  bool patternMatches(String requestMethod, String requestPath) {
    if (method != null &&
        method!.toUpperCase() != requestMethod.toUpperCase()) {
      return false;
    }
    final String path = requestPath.split('?').first;
    final String pattern = pathPattern.trim();
    if (pattern.isEmpty) return false;
    if (pattern.contains('*')) {
      final String regex =
          '^${pattern.split('*').map(RegExp.escape).join('.*')}\$';
      return RegExp(regex).hasMatch(path);
    }
    return path.contains(pattern);
  }

  /// Short human label, e.g. `GET /users/* → 200`.
  String get label => '${method ?? 'ANY'} $pathPattern → $statusCode';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'pathPattern': pathPattern,
        if (method != null) 'method': method,
        'statusCode': statusCode,
        'contentType': contentType,
        'body': body,
        'isBase64': isBase64,
        'delayMs': delayMs,
        'enabled': enabled,
      };
}
