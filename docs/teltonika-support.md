# Teltonika FMB Support

Tracker Studio provides read-only diagnostics and capture analysis for Teltonika FMB-series trackers (FMB001, FMB003, FMB010, FMB140, FMB150, FMB230, etc.) connected via USB serial.

## Connection

1. Connect the device to USB with a data cable.
2. Launch Tracker Studio on macOS (Windows/Linux unverified).
3. Select the serial port (e.g. `/dev/cu.usbserial-*`).
4. Start capture.

The serial debug log is parsed line-by-line; no binary socket connection is required.

## Protocol layers

### 1. Line normalisation

`TeltonikaLineNormalizer` parses raw serial lines into categorized tokens:

| Prefix | Meaning |
|---|---|
| `[READ]` | Line received from the device. |
| `[SEND]` | Line sent to the device by the configurator/app. |
| `[READ_ASCII]` | AVL codec-0x03 IO record (human-readable). |
| `[READ_HEX]` | AVL codec-0x08 binary frame (hex-encoded). |
| `[SERIAL]` | Free-text serial debug (GPS status, errors, etc.). |

### 2. Binary AVL codec

`TeltonikaAvlCodec` decodes codec-0x08 binary frames from `[READ_HEX]` chunks.

**Frame layout:**

```
CODEC_ID (1 byte)            // 0x08
RECORDS_COUNT (uint32 BE)
<record> ...
RECORDS_COUNT (uint32 BE)
CODEC_ID (1 byte)
```

**Decode result** is a sealed `TeltonikaDecodeResult`:

- `TeltonikaDecodeSuccess` — contains a list of `TeltonikaGeneratedAvlRecord`.
- `TeltonikaDecodeFailure` — contains a `TeltonikaDecodeError` enum value and optional byte offset:
  - `emptyInput`
  - `invalidCodecId`
  - `recordCountMismatch`
  - `truncatedFrame`
  - `trailingCodecMismatch`
  - `recordTooShort`
  - `ioGroupCorrupt`
  - `invalidHex`

### 3. ASCII AVL parsing

`TeltonikaAsciiAvlParser` parses `[READ_ASCII]` lines from the codec-0x03 text protocol.

### 4. Capture analysis

`TeltonikaCaptureAnalyzer.analyze()` aggregates all parsed records into a `TeltonikaSessionSnapshot` containing device model, firmware, IMEI, ICCID, GPS fix, parameters and observed IOs.

## Supported features

| Capability | Source |
|---|---|
| Model detection | `TeltonikaDriver.detectModel()` |
| Firmware version | `[READ] Model` / `[READ_ASCII]` |
| IMEI extraction | `[READ]` handshake response |
| ICCID / SIM status | `[READ_ASCII]` records |
| GPS position, HDOP, satellites | `[READ_ASCII]` AVL records |
| Parameter set/read | `[READ]` / `[SEND]` codec-0x03 |
| Binary AVL decode | `[READ_HEX]` codec-0x08 frames |

## Limitations

- Write/provisioning commands are not sent during capture; analysis is read-only.
- Only codec 0x08 and 0x03 are supported.
- The list of supported devices is derived from firmware strings observed during field captures; see `docs/io-catalog.md` for the IO definition catalog.
