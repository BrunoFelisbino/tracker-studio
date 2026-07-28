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

String sanitizeText(String value) => value.replaceAll(
      RegExp(
        r'(authorization|token|password|secret|api[_-]?key)=([^&\s]+)',
        caseSensitive: false,
      ),
      r'\1=***REDACTED***',
    );
