# Plugin API

The plugin API is defined under `lib/core/plugins`. A plugin manifest declares
identity, supported devices, capabilities, and permissions. Credential access
is mediated by the core and scoped to the integration requested by the plugin.
