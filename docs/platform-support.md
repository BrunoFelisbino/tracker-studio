# Platform Support

Tracker Studio is officially tested on macOS. Windows and Linux have project
scaffolding but require community validation, especially for USB drivers,
serial permissions, device discovery, and packaging.

macOS: install Xcode, run `flutter pub get`, then `flutter run -d macos`.

Windows: install Visual Studio with Desktop C++, enable Windows desktop, then
run `flutter run -d windows`.

Linux: install GTK, clang, CMake and Ninja packages, configure `dialout` for
serial devices, then run `flutter run -d linux`.
