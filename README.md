# Godot 3.6 for unsupported Windows XP+

This is a tweaked Godot 3.6 branch that is intended to compile and run on Windows XP and up. The project is built using [x64devkit](https://github.com/skeeto/w64devkit)'s 32-bit MinGW toolkit. Several changes were made:

- Several Godot features (OS specific code, locale etc) were placed in conditionals or alternative codes.
- Several string functions were placed in conditionals for their unsafe counterparts to not depend on too new msvcrt.dll.

## Building

To compile on Windows host, first install [x64devkit](https://github.com/skeeto/w64devkit). Building from the source is recommended because of virus warnings with the pre-built release. Clone the repository. We want to build the x86 version, so issue the command `./multibuild.sh -4` to build it. Then the 32-bit w64devkit self extracting package will be done. Install/Extract it and start `w64devkit.exe`.

Clone this repository and branch outside of the devkit as it doesn't have git.

Navigate to the directory in the devkit console and type `python -m SCons platform=windows use_mingw=yes bits=32 optimize=size tools=no target=release_debug verbose=yes`. This builds a debug export target which is meant to run with a .pck file. To compile it as a stand-alone editor, type `tools=yes`. To build for 64-bit mode, `bits=64` can be used.

## Issues

- The audio driver needs to be re-written for XP.
