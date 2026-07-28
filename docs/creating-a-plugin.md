# Creating a Plugin

Plugins implement the public Tracker Studio plugin interfaces and must declare
their capabilities and permissions. Keep manufacturer-specific protocol logic
inside the plugin; the core must remain usable without any external service.

Plugins must use synthetic fixtures and request network or credential access
explicitly. They never access the secure credential store directly.
