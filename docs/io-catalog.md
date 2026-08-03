# IO Definition Catalog

The Universal Configuration Engine (UCE) maintains a catalog of AVL IO definitions that maps Teltonika IO IDs to human-readable names, units and categories.

## Core types

Defined in `lib/core/uce/uce_interfaces.dart`:

### AvlDefinition

```dart
class AvlDefinition {
  final int avlId;
  final String name;
  final String normalizedKey;
  final AvlCategory category;
  final IoDefinitionSource source;
  final IoDefinitionConfidence confidence;
  final String manufacturer;
  final String? model;
  final String? family;
  final String? firmware;
  final String? codec;
  final String? documentationSource;
}
```

### IoDefinitionSource

| Value | Meaning |
|---|---|
| `officialDocumentation` | IO is documented in the official Teltonika protocol specification. |
| `deviceObservation` | IO was observed in real device captures but is not in official docs. |
| `communityContribution` | IO definition contributed by the Tracker Studio community. |
| `userMapping` | IO mapping created by the user in the CAN mapping UI. |
| `unknown` | Source has not been determined. |

### IoDefinitionConfidence

| Value | Meaning |
|---|---|
| `confirmed` | IO behavior verified against multiple captures or official documentation. |
| `probable` | IO is likely correct but not yet fully verified. |
| `experimental` | IO mapping is a hypothesis under investigation. |
| `unknown` | Confidence level has not been assigned. |

## Catalog access

`TeltonikaDriver.knownAvlDefinitions` returns the current catalog. The `AvlDefinition` list is extensible: user-created CAN mappings are merged at runtime from `lib/core/data/can_mapping/can_mapping_store.dart`.

## Adding a new IO definition

1. Add an entry to the `knownAvlDefinitions` list in `teltonika_driver.dart`.
2. Set `source: IoDefinitionSource.officialDocumentation` for documented IOs.
3. Use `IoDefinitionConfidence.confirmed` only when verified.
4. Include `manufacturer`, `model` and `family` when the IO is device-specific.
5. Add a test case in `teltonika_classifier_test.dart` or `teltonika_avl_binary_codec_test.dart`.

## Persistence

User-created mappings are persisted to a JSON file via `CanMappingStore`, which enforces a `kMaxCanMappings` limit (500 entries) and uses atomic writes (temp file + rename) to prevent corruption.
