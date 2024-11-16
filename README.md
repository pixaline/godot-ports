# Godot 3.6+ for PPC OSX

Here is a build that will compile for OS X 10.4 PPC. Tested mainly using the OSXCross project and GCC 5.5.0. Several changes were made:
- GLES3/OpenGL3/GLAD is disabled and not compiled. GLES2 is thus using Apple's OpenGL framework.
- Certain C++11 features are replaced. (such as std::shared_timed_mutex)
- Certain OSX code (that Apple marks "depreceated") is wrapped in defines for selective compilation.
  - Very modern OSX code (targeting 10.14) is removed.
- Removed tests, translations, docs translations, and documentation to save binary space.
  - If needed, simply uncomment the .gen.h import.

## Building
I use this command to build: `scons platform=osx osx_version=10.4 arch=ppc tools=no target=release_debug debug_symbols=no modules_enabled_by_default=no`

For additional modules I add these: `modules_enabled_by_default=no module_gdscript_enabled=yes module_freetype_enabled=yes module_etc_enabled=yes module_regex_enabled=no`

### OSXCross
In the case of OSXCross, I used this scons command: `OSXCROSS_ROOT="/opt/osxcross-ppc" scons osxcross_sdk=darwin9 [...]`

## Issues
- The tools version is too big to compile: `ld: bl PPC branch out of range (33006356 max is +/-16MB): from __start (0x000024B4) to _main (0x01F7CAB0) in '__start'`. It might be something with my setup, but I'm not sure.
