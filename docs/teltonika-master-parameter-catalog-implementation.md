# Teltonika Master Parameter Catalog — Implementation Plan

## Objective

Implement a master Teltonika configuration catalog in Tracker Studio based on the public Teltonika Wiki page:

- `https://wiki.teltonika-gps.com/view/Parameter_list`

The page must be treated as a **master catalog source**, not as proof that every parameter is supported by every Teltonika model or firmware.

The implementation must support:

- parameter discovery;
- parameter reading;
- parameter editing;
- validation by type, range and enum;
- model and firmware compatibility states;
- accessory dependencies;
- grouped configuration screens;
- mandatory Teltonika USB configuration workflow;
- readback confirmation after persistence;
- future catalog updates without rewriting the UI.

---

## Core rule

Never assume that a parameter listed on the Teltonika Wiki is supported by every Teltonika device.

The correct model is:

```text
Teltonika master catalog
+ model compatibility profile
+ firmware compatibility profile
+ accessory dependency profile
+ runtime discovery/readback
```

---

## Mandatory configuration workflow

Every Teltonika configuration change must run through the same ordered workflow:

```text
1. Activate USB Configurator session
2. Send cfg_setparam for each changed parameter
3. Wait for SETPARAM_RESULT after each write
4. Send cfg_save
5. Wait for SAVE_CFG_RESULT
6. Read the changed parameters again
7. Compare readback against requested values
8. Close the Configurator session when applicable
```

Example:

```text
CONNECT
:cfg_setparam:2001:internet
<SETPARAM_RESULT>:1
:cfg_save
<SAVE_CFG_RESULT>:1
READBACK 2001
DISCONNECT
```

A write must not be considered successful only because bytes were written to the serial port.

---

## Catalog schema

Create a catalog entity similar to:

```dart
enum TeltonikaParameterDataType {
  uint8,
  int8,
  uint16,
  int16,
  uint32,
  int32,
  uint64,
  doubleValue,
  char,
  string,
  byte,
  boolean,
  enumValue,
  phone,
  domain,
  ipOrDomain,
  port,
  mac,
  coordinate,
  duration,
}

enum TeltonikaParameterSupport {
  supported,
  unsupported,
  unknown,
  firmwareDependent,
  modelDependent,
  accessoryDependent,
}

enum TeltonikaParameterSource {
  officialWiki,
  modelManual,
  firmwareObservation,
  fieldObservation,
  communityContribution,
}

class TeltonikaParameterDefinition {
  final int id;
  final String name;
  final String category;
  final String group;
  final TeltonikaParameterDataType type;
  final Object? defaultValue;
  final num? minimum;
  final num? maximum;
  final int? maxLength;
  final String? unit;
  final Map<String, String>? enumValues;
  final String? description;
  final bool readable;
  final bool writable;
  final bool requiresSave;
  final bool requiresReboot;
  final TeltonikaParameterSource source;
  final List<String> confirmedModels;
  final List<String> confirmedFirmwares;
  final List<String> requiredAccessories;
  final List<String> compatibilityNotes;
}
```

---

## Source data files

Do not hardcode the complete catalog inside a large Dart driver file.

Create structured source files such as:

```text
assets/catalogs/teltonika/
  master-parameters.json
  generated-groups.json
  compatibility/
    common.json
    fmb140.json
    fmc234.json
    firmware-overrides.json
  README.md
```

The application must load the catalog and convert it into domain entities.

Recommended JSON entry:

```json
{
  "id": 2001,
  "name": "APN",
  "category": "GPRS",
  "group": "Network",
  "type": "char",
  "defaultValue": "",
  "maxLength": 32,
  "readable": true,
  "writable": true,
  "requiresSave": true,
  "requiresReboot": false,
  "source": "officialWiki",
  "confirmedModels": [],
  "confirmedFirmwares": [],
  "requiredAccessories": [],
  "compatibilityNotes": []
}
```

---

## Initial categories to import

Import and organize every parameter from the Teltonika Parameter List into these categories:

1. System
2. Sleep and power management
3. Ignition and movement
4. GNSS and AGPS
5. NTP
6. GPRS
7. Primary server
8. Backup server
9. TLS/DTLS
10. FOTA WEB
11. SMS and calls
12. Authorized numbers
13. GSM operators and blacklist
14. Data acquisition — Home/Stop
15. Data acquisition — Home/Moving
16. Data acquisition — Roaming/Stop
17. Data acquisition — Roaming/Moving
18. Data acquisition — Unknown/Stop
19. Data acquisition — Unknown/Moving
20. Green Driving
21. Overspeeding
22. Jamming
23. Immobilizer
24. DOUT control
25. iButton
26. Trip
27. Odometer
28. Private/Business mode
29. Weekly schedule
30. Daylight saving
31. AutoGeofence
32. Manual Geofence
33. GPS fuel counter
34. Unplug detection
35. Towing detection
36. Crash detection
37. Excessive idling
38. Motorcycle fall detection
39. Bluetooth
40. BLE common settings
41. BLE connections 1–4
42. Beacon list
43. Tracking on demand
44. I/O event parameters
45. OBD II Bluetooth
46. LVCAN / ALL-CAN
47. RS232/RS485
48. CAN adapter flags
49. Security flags
50. Control flags
51. Indicator flags
52. Agricultural flags
53. Utility flags
54. Cistern flags
55. ADAS flags

---

## Known parameter examples

The first implementation must include and validate at least these commonly used parameters:

### Network

```text
2000 — GPRS context
2001 — APN
2002 — APN username
2003 — APN password
2016 — GPRS authentication
2004 — Primary server domain
2005 — Primary server port
2006 — Primary server protocol
2020 — Primary TLS/DTLS
2010 — Backup server mode
2007 — Backup server domain
2008 — Backup server port
2009 — Backup server protocol
2021 — Backup TLS/DTLS
2025 — Auto APN search
```

Enums:

```text
2006 / 2009 protocol
0 = TCP
1 = UDP
3 = MQTT
```

### Ignition and voltage

```text
101 — Ignition source/settings
104 — High voltage threshold
105 — Low voltage threshold
138 — Movement source
133 — Speed source
```

### Sleep and low power

```text
102 — Sleep settings
103 — Sleep timeout
19500 — Low Power Mode
19501 — Minimum period
19502 — GPS search period
19503 — GPS accuracy threshold
19504 — Minimum satellite quantity
19505 — Hold GPS fix timeout
```

### Data acquisition

```text
10000 / 10004 / 10005 — Home network, stopped
10050–10055 — Home network, moving
10100 / 10104 / 10105 — Roaming, stopped
10150–10155 — Roaming, moving
10200 / 10204 / 10205 — Unknown network, stopped
10250–10255 — Unknown network, moving
```

### NTP

```text
901 — NTP resync period
902 — NTP server 1
903 — NTP server 2
```

### Odometer

```text
11806 — Odometer calculation source
11807 — Odometer value
```

### LVCAN

```text
45000 — LVCAN mode
45001 — Send data with ignition off
45002 — Program number
```

---

## Repeated parameter groups

Many catalog sections follow formulas and should be generated programmatically instead of manually duplicating hundreds of definitions.

Examples:

### Manual Geofence

Create a generator for zones 1–50 using the base pattern shown by the source table.

Each zone contains fields such as:

- priority;
- event generation;
- eventual records;
- frame border;
- shape;
- radius;
- coordinates;
- overspeeding;
- maximum speed;
- SMS destination;
- SMS text.

### I/O event definitions

Most I/O event groups contain:

```text
Priority
Operand
High level
Low level
Event only
Average
Send SMS
SMS text
```

Build a reusable descriptor and generate individual groups from a compact mapping table.

### CAN flags

Security, control, indicator, agricultural, utility, cistern and ADAS flags commonly use:

```text
Priority
Operand
High level
Low level
Event only
```

Represent these as generated flag groups instead of thousands of handwritten Dart constructors.

---

## UI generation

The UI must be generated from parameter metadata.

Mapping rules:

```text
integer/unsigned integer -> numeric input
Double -> decimal input
0/1 boolean -> Switch
Enum -> Dropdown/Segmented control
String/Char -> Text input
Password -> Obscured text field
Port -> Numeric field 1–65535
Domain/IP -> Host validation
Phone -> Phone validation
MAC -> MAC validation
Coordinate -> Latitude/longitude validation
Duration -> Numeric input with unit
```

Every field must show:

- parameter name;
- parameter ID;
- description;
- current value when read;
- default value;
- valid range;
- unit;
- compatibility badge;
- risk/impact badge;
- source badge.

---

## Compatibility states in the interface

Display one of:

```text
Confirmed on this device
Common Teltonika parameter
Firmware dependent
Model dependent
Accessory dependent
Not confirmed
Unsupported by readback
```

When support is unknown, allow a safe discovery action:

```text
1. Identify model and firmware
2. Activate Configurator session
3. Request parameter read
4. Interpret response
5. Mark runtime support
6. Allow editing only after support is known or explicitly overridden
```

---

## Write workflow domain model

Create an explicit transaction model:

```dart
enum TeltonikaConfigStepType {
  connect,
  setParameter,
  save,
  readback,
  disconnect,
}

enum TeltonikaConfigStepStatus {
  pending,
  running,
  succeeded,
  failed,
  skipped,
}

class TeltonikaConfigStep {
  final TeltonikaConfigStepType type;
  final int? parameterId;
  final String? requestedValue;
  final String? response;
  final TeltonikaConfigStepStatus status;
  final String? error;
}

class TeltonikaConfigTransaction {
  final String id;
  final DateTime startedAt;
  final List<TeltonikaConfigStep> steps;
  final bool persisted;
  final bool readbackConfirmed;
}
```

The screen must visibly show progress:

```text
✓ USB Configurator activated
✓ Parameter 2001 sent
✓ SETPARAM_RESULT confirmed
✓ cfg_save sent
✓ SAVE_CFG_RESULT confirmed
✓ Readback confirmed
```

---

## Failure handling

Abort and do not send `cfg_save` when any mandatory `cfg_setparam` fails.

Failure examples:

- USB session not activated;
- timeout waiting for SETPARAM_RESULT;
- SETPARAM_RESULT indicates failure;
- unsupported parameter;
- malformed value;
- timeout waiting for SAVE_CFG_RESULT;
- SAVE_CFG_RESULT indicates failure;
- readback differs from requested value;
- serial transport disconnected.

A transaction must produce a structured result rather than only a snackbar message.

---

## Security and privacy

Do not commit:

- real APN credentials;
- real server IP addresses;
- real domains used by customers;
- device IMEIs;
- ICCIDs;
- phone numbers;
- raw captures containing identifiable values.

Tests and examples must use synthetic values:

```text
APN: internet.example
Server: tracker.example.com
IP: 192.0.2.10
Port: 6000
IMEI: 000000000000001
ICCID: 8955000000000000000
```

Passwords must never appear in exported logs or transaction previews.

---

## Open-source requirements

The master catalog must be contribution-friendly.

A community contribution for a parameter confirmation should include:

```text
manufacturer
device model
firmware version
parameter ID
read result
write result, when safe
save result
readback result
source or field evidence
```

Do not publish proprietary firmware, configurator binaries or copied manuals.

Store normalized factual metadata and source references only.

---

## Tests

Add tests for:

- JSON catalog loading;
- duplicate parameter IDs;
- invalid ranges;
- invalid enum values;
- default outside range;
- generated groups;
- model compatibility overrides;
- firmware compatibility overrides;
- unsupported parameter read;
- cfg_setparam encoding;
- ordered multi-parameter writes;
- abort on setparam failure;
- cfg_save only after all writes succeed;
- SAVE_CFG_RESULT handling;
- readback equality;
- password masking;
- UI field generation by data type.

Required workflow examples:

```text
connect -> cfg_setparam -> save -> readback -> disconnect
```

and:

```text
connect -> cfg_setparam A -> cfg_setparam B -> cfg_setparam C -> save -> readback A/B/C -> disconnect
```

---

## Delivery phases

### Phase 1 — Foundation

- create catalog schema;
- move hardcoded definitions out of `teltonika_driver.dart`;
- implement JSON loader;
- implement category browsing;
- preserve existing network/APN features.

### Phase 2 — Core parameters

- System;
- GPRS;
- server primary/backup;
- data acquisition;
- sleep;
- NTP;
- ignition;
- voltage;
- read/write/save/readback flow.

### Phase 3 — Scenarios

- overspeeding;
- green driving;
- towing;
- crash;
- idling;
- immobilizer;
- trip;
- geofences.

### Phase 4 — Accessories and IO

- Bluetooth/BLE;
- OBD;
- LVCAN/ALL-CAN;
- RS232/RS485;
- I/O event groups.

### Phase 5 — Generated CAN flag catalogs

- security;
- control;
- indicator;
- agricultural;
- utility;
- cistern;
- ADAS.

---

## Definition of done

The implementation is complete when:

- the master catalog is stored outside UI code;
- every imported parameter has ID, type, group, default/range or enum where documented;
- the UI is generated from metadata;
- unsupported parameters are not silently treated as supported;
- all writes follow `connect -> cfg_setparam -> cfg_save -> readback`;
- each transaction visibly reports every step;
- model, firmware and accessory compatibility can override the master catalog;
- tests validate the catalog and transaction workflow;
- no sensitive customer or device data is committed.
