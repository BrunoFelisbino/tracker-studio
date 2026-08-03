# Architecture Overview

## Layers

Tracker Studio is organised into four layers, from the lowest-level primitives to the user-facing application.

### 1. Core (`lib/core/`)

Vendor-neutral contracts, services and utilities shared across all equipment plugins.

| Directory | Responsibility |
|---|---|
| `plugins/` | `TrackerStudioPlugin`, `PluginManifest`, `DeviceIdentity`, `DeviceConnection`, `PluginResult`, `PluginRegistry` — the plugin contract. |
| `drivers/` | Protocol driver entry points (e.g. `TeltonikaDriver`). Each driver exposes a high-level API that the live screen and command service call. |
| `data/` | Persistent storage (JSON file stores for capture logs and CAN mappings) and binary parsers. |
| `diagnostics/` | Event classification, line normalisation and capture analysis. |
| `uce/` | Universal Configuration Engine — IO definition catalogs, config field specs and manufacturer registries. |
| `security/` | Log sanitisation and data-privacy helpers. |
| `bootstrap/` | Application bootstrap and dependency wiring. |

### 2. Equipment features (`lib/features/`)

High-level Flutter features that coordinate a single domain:

- `sessions/` — live capture session, Tracker Studio screens, network command flow.
- `diagnostics/` — event classifier, line normaliser, capture analyser.
- `equipment_lab/` — offline capture analysis and report generation.
- `commands/` — manual command runner.
- `sms/` — SMS command composition.
- `validations/` — installation validation checklist.

Each feature depends on Core and on one or more drivers, but Core never imports a feature directly.

### 3. UI (`lib/features/*/presentation/`)

Screen, widget and provider layer. Screens consume driver APIs and feature services; they never parse raw protocol bytes directly.

### 4. Application shell (`lib/app.dart`, `lib/main.dart`)

Root material app, router (`go_router`), theme and bootstrap orchestrator.

## Data flow (Teltonika live capture)

```
Serial / USB transport
        │
        ▼
TeltonikaDriver.receiveRawLines(...)
        │
        ├──► TeltonikaLineNormalizer.normalize()
        │       │
        │       ├── READ  / SEND  ──► parameter set / response lines
        │       └── READ_ASCII      ──► AVL codec-0x03 IO records
        │       └── READ_HEX        ──► AVL codec-0x08 binary frames
        │
        ▼
TeltonikaAvlCodec.decode() ──► TeltonikaDecodeResult
        │                    (Success → records, Failure → structured error)
        │
        ▼
TeltonikaCaptureAnalyzer.analyze() ──► TeltonikaSessionSnapshot
        │
        ▼
TrackerStudioController (Riverpod) ──► UI state
```

## Key types

| Type | Location | Purpose |
|---|---|---|
| `TeltonikaGeneratedAvlRecord` | `teltonika_usb_models.dart` | A single AVL/codec-0x03 record with timestamp, GPS, IO elements and metadata. |
| `TeltonikaDecodeResult` | `teltonika_avl_binary_codec.dart` | Sealed result: `TeltonikaDecodeSuccess` / `TeltonikaDecodeFailure` with a `TeltonikaDecodeError` enum. |
| `AvlDefinition` | `uce_interfaces.dart` | Catalog definition for an AVL IO ID, with source/confidence metadata. |
| `TeltonikaSessionSnapshot` | `teltonika_capture_analysis.dart` | Aggregated result of parsing a capture log: device info, parameters, IOs, warnings. |

## Plugin isolation rule

> **Core must never import manufacturer-specific code.**

All manufacturer logic lives in `lib/core/drivers/teltonika/` and `lib/core/data/parsers/teltonika_usb/`. The rest of the application imports a driver only through its public class (`TeltonikaDriver`). See `docs/plugin-architecture.md` for the migration plan and plugin contract.
