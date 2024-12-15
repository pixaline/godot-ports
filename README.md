# Godot 3.6+ for unsupported PPC/Intel Mac OS X

This is a tweaked Godot 3.6 branch that is intended to compile for the Mac OS X 10.4/10.5/10.6 on both PPC and Intel. The project is tested mainly using the OSXCross project and GCC. Several changes were made:
- GLES3/OpenGL 3.0/GLAD is disabled and not compiled. GLES2 is thus using Apple's OpenGL framework directly.
- Certain C++11 code (such as thread_local, etc) are replaced/removed to play along with older GCC (5.5.0+).
- Certain OSX code (that Apple marks "depreceated") is wrapped in specific defines for selective compilation.
  - Very modern OSX code (targeting 10.14) is removed.
- Removed tests, translations, docs translations, and documentation to reduce final binary size.
  - If needed, simply uncomment the .gen.h import.

## Building
To compile for the PPC, type: `scons platform=osx osx_version=10.4 arch=ppc tools=no target=release_debug debug_symbols=no modules_enabled_by_default=no`. This builds a release target which is meant to be bundled with a .pck file (can be placed in Resources/ folder with same name as executable, if bundling in an .app). To compile the stand-alone editor, type: `tools=yes`. Note that this build might cause problems on the PPC, read below.

To compile with all the default modules, just type `modules_enabled_by_default=yes`. Be aware that some modules still have C++11 code, such as the raycast, xatlas_unwrap, etc and camera module. You can disable/enable specific modules by typing `module_..._enabled=no` or `=yes`.

To compile builds targeting Intel, I use the same command with `arch=i386` or `arch=x86_64`. To further learn the compilation process, read the file `platform/osx/detect.py`.

### OSXCross
To compile using OSXCross, first install it and follow its readme, and then type: `OSXCROSS_ROOT="/opt/osxcross-ppc" scons osxcross_sdk=darwin9 [...]`. You would first need to build a newer GCC version in the OSXCross directory first, as the early Mac OS X SDK c++ compilers are outdated. This can be accomplished with the command `./build_gcc.sh` in the OSXCross repository. Note that the PPC build of GCC need a special building process, [read more here](https://github.com/tpoechtrager/osxcross?tab=readme-ov-file). Furthermore, if you install multiple Mac OS X SDKs, you can use different ones for PPC and Intel. For me, the best SDKs were: `osxcross_sdk=darwin9` (10.4 SDK) for building PPC and `osxcross_sdk=darwin14` (10.10 SDK) for building Intel.

## Issues
- The tools version is too big to compile for the PowerPC:
	`ld: bl PPC branch out of range (33006356 max is +/-16MB): from __start (0x000024B4) to _main (0x01F7CAB0) in '__start'`.
	It might be something with my setup, but I'm not sure.
- Building for OS X 10.4 PowerPC isn't worth it, as it only supports OpenGL 1.5 across all video cards ([reference here](http://web.archive.org/web/20090823045343/http://homepage.mac.com/arekkusu/bugs/GLInfo_10411Intel.html)). The shaders would need to be re-written for earlier GLSL versions.
