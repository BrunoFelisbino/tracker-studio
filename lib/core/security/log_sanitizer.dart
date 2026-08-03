const _sensitiveHeaderNames = {
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'api-key',
};

Map<String, String> sanitizeHeaders(Map<String, String> headers) => {
      for (final entry in headers.entries)
        entry.key: _sensitiveHeaderNames.contains(entry.key.toLowerCase())
            ? '***REDACTED***'
            : entry.value,
    };

/// Masks sensitive identifiers (IMEI, ICCID, full phone numbers, bearer tokens,
/// API keys, passwords, private IPs) before they are logged, displayed to the
/// user, or exported as part of a capture/report.
///
/// Examples:
///   IMEI: 869842050383122            -> IMEI: ***REDACTED***
///   ICCID: 8955000000000000000       -> ICCID: ***REDACTED***
///   Bearer abc123.def456.ghi789      -> Bearer ***REDACTED***
///   password=secret123               -> password=***REDACTED***
///   api_key=abcdef123456             -> api_key=***REDACTED***
///   45.58.36.225                     -> ***.***.***.***
///   +5511912345678                  -> +**-*********-****
String sanitizeSensitiveData(String value) {
  var sanitized = value;

  // Bearer tokens e auth headers
  sanitized = sanitized.replaceAll(
    RegExp(r'(Bearer\s+)([A-Za-z0-9._-]{8,})'),
    r'$1***REDACTED***',
  );

  // Key=value pairs for passwords, tokens, secrets, API keys
  sanitized = sanitized.replaceAll(
    RegExp(
        r'(password|passwd|secret|api[_-]?key|token|authorization)\s*[=:]\s*([^\s&;#]+)',
        caseSensitive: false),
    r'\1=***REDACTED***',
  );

  // IMEI (15 digits, optionally prefixed)
  sanitized = sanitized.replaceAll(
    RegExp(r'IMEI[=:]\s*(\d{15})', caseSensitive: false),
    r'IMEI: ***REDACTED***',
  );

  // ICCID (19-20 digits starting with 89)
  sanitized = sanitized.replaceAll(
    RegExp(r'ICCID[=:]\s*(89\d{17,19})', caseSensitive: false),
    r'ICCID: ***REDACTED***',
  );

  // Phone numbers in international format (+XX followed by 9-11 digits)
  sanitized = sanitized.replaceAll(
    RegExp(r'(\+)(\d{2})(\d{8,10})'),
    r'+\2***REDACTED***',
  );

  // Private/internal IPs (not in documentation ranges 192.0.2.x, 198.51.100.x, 203.0.113.x)
  sanitized = sanitized.replaceAllMapped(
    RegExp(r'(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})'),
    (m) {
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final c = int.parse(m.group(3)!);
      final d = int.parse(m.group(4)!);
      // Keep documentation ranges (192.0.2.x, 198.51.100.x, 203.0.113.x) and localhost
      if ((a == 192 && b == 0 && c == 2) ||
          (a == 198 && b == 51 && c == 100) ||
          (a == 203 && b == 0 && c == 113) ||
          (a == 127) ||
          (a == 10) ||
          (a == 192 && b == 168) ||
          (a == 172 && b >= 16 && b <= 31)) {
        return '${m.group(1)}.${m.group(2)}.${m.group(3)}.$d';
      }
      return '***.***.***.***';
    },
  );

  return sanitized;
}

String sanitizeText(String value) => value.replaceAll(
      RegExp(
        r'(authorization|token|password|secret|api[_-]?key)=([^&\s]+)',
        caseSensitive: false,
      ),
      r'\1=***REDACTED***',
    );
