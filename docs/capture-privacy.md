# Capture Privacy

Tracker Studio captures serial debug logs from Teltonika and other devices. These logs may contain sensitive data that must never be committed to version control or distributed in public releases.

## Sanitisation policy

All test fixtures, sample logs, documentation snippets and screenshot captions must use synthetic data only:

| Data type | Synthetic replacement |
|---|---|
| Public IP addresses | `192.0.2.x` (documentation range) |
| Private IP addresses | `198.51.100.x` / `203.0.113.x` |
| IMEI | `000000000000001` (15 zeros + 1) |
| ICCID | `8955000000000000000` |
| Phone numbers | `+5500000000000` |
| GPS coordinates | `0.0, 0.0` |
| APN names | `internet` |
| Domains | `tracker.example.com` / `device1.example.com` |
| APN credentials | `****REDACTED****` |

## Log sanitiser

`lib/core/security/log_sanitizer.dart` provides `sanitizeSensitiveData()` which masks:

- IMEI: 15 consecutive digits → `****REDACTED****`
- ICCID: 20 consecutive digits → `****REDACTED****`
- Bearer tokens: `Bearer <token>` → `Bearer ****REDACTED****`
- Key=value credentials in serial logs
- Private IPv4 addresses (`10.x`, `172.16-31.x`, `192.168.x`)

## Capture log retention

`CaptureLogStore` enforces automatic pruning:

- `kMaxCaptureRecords` (100) — maximum number of capture sessions retained.
- `kMaxCaptureLogBytes` (50 MB) — maximum total size of stored logs.

Old records are removed oldest-first when either limit is exceeded.

## What must never be committed

- `.env` files with real credentials
- Database extracts with customer data
- Screenshots of real device dashboards
- Test fixtures using real IMEI/ICCID/coordinates
- Private network endpoints (`*.goodscare.com.br`, internal API URLs)

See `docs/public-security-audit.md` for the full audit checklist.
