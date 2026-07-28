# Tracker Studio Plugin Architecture

## Goal

Transform Tracker Studio into an open, vendor-neutral technical platform where equipment manufacturers, protocols and project-specific workflows are delivered as plugins instead of being embedded in the application core.

## Architectural rule

The core must never import manufacturer-specific code. Plugins may import public core contracts, but the core may interact with plugins only through `lib/core/plugins`.

## Proposed layers

### Core

Owns navigation, session lifecycle, permissions, secure storage, transport abstraction, diagnostics timeline, generic reports, plugin discovery and user interface contracts.

### Equipment plugins

Own manufacturer/model detection, parsers, command catalogs, readback, provisioning, alarms, installation steps, manuals and device-specific diagnostics.

Examples:

- `plugins/suntech`
- `plugins/queclink`
- `plugins/teltonika`
- `plugins/calamp`
- `plugins/community/<plugin>`

### Project plugins

Add customer or operation-specific workflows without modifying the equipment parser. Examples include field checklists, approval flows, report templates and external platform integrations.

### Integrations

Backend or platform connectors must be isolated from equipment plugins. Credentials remain in a backend or secure local store and are never bundled as privileged secrets in the Flutter application.

## Initial public API

The first contract is defined by:

- `TrackerStudioPlugin`
- `PluginManifest`
- `DeviceIdentity`
- `DeviceConnection`
- `TrackerPluginSession`
- `PluginCommand`
- `PluginResult`
- `PluginEvent`
- `PluginRegistry`

The API starts at version `1.x`. Breaking changes require a new major API version and a migration guide.

## Migration plan

1. Freeze the existing Suntech behavior with tests.
2. Move Suntech catalog, parser, commands, readback and manuals behind a `SuntechPlugin` adapter.
3. Replace direct Suntech imports in screens/providers with plugin contracts.
4. Make bootstrap register bundled plugins explicitly.
5. Add a generic device-selection and capability-driven UI.
6. Create a plugin template with tests and synthetic fixtures.
7. Add CI checks preventing core-to-vendor imports and secret commits.
8. Publish the repository only after credentials and history are sanitized.

## Plugin safety

Plugins are code and therefore trusted at runtime in the first version. A future marketplace must add package signing, compatibility checks, permission declarations and a review process. Until then, only bundled or source-reviewed plugins should be loaded.

## Definition of done for the Suntech extraction

- Existing Suntech tests continue to pass.
- The application starts with zero manufacturer imports outside `plugins/suntech`.
- Removing the Suntech registration still allows the generic application to start.
- A sample plugin can register, detect a synthetic device and execute a fake command.
- Reports and diagnostics use generic events and results rather than Suntech response types.
