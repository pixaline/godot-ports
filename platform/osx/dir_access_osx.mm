/**************************************************************************/
/*  dir_access_osx.mm                                                     */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#include "dir_access_osx.h"

#if defined(UNIX_ENABLED) || defined(LIBC_FILEIO_ENABLED)

#include <errno.h>

#include <AppKit/NSWorkspace.h>
#include <Foundation/Foundation.h>

String DirAccessOSX::fix_unicode_name(const char *p_name) const {
	String fname;
	// This runs on EditorFileSystem's project-scan thread as well as the
	// main thread. Cocoa only maintains an autorelease pool for you on the
	// main thread's run loop; background threads get none unless one is
	// created explicitly, so without this every NSString created below
	// (one per path component, for every file/dir in the project) leaks
	// instead of being freed -- see ~/godot_output.txt's repeated
	// "_NSAutoreleaseNoPool(): ... just leaking" during project load.
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *nsstr = [[NSString stringWithUTF8String:p_name] precomposedStringWithCanonicalMapping];

	fname.parse_utf8([nsstr UTF8String]);
	[pool release];

	return fname;
}

int DirAccessOSX::get_drive_count() {
	// See fix_unicode_name() above: DirAccess methods aren't guaranteed to
	// run on the main thread (EditorFileSystem's scan thread calls into
	// this class too), so any Cocoa object created here needs an explicit
	// pool rather than relying on the main run loop's.
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int count;
#ifdef MAC_OS_X_10_6_FEATURES
	NSArray *res_keys = [NSArray arrayWithObjects:NSURLVolumeURLKey, NSURLIsSystemImmutableKey, nil];
	NSArray *vols = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:res_keys options:NSVolumeEnumerationSkipHiddenVolumes];
	count = [vols count];
#else
	NSArray *vols = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	count = [vols count];
#endif
	[pool release];
	return count;
}

String DirAccessOSX::get_drive(int p_drive) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	String volname;
#ifdef MAC_OS_X_10_6_FEATURES
	NSArray *res_keys = [NSArray arrayWithObjects:NSURLVolumeURLKey, NSURLIsSystemImmutableKey, nil];
	NSArray *vols = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:res_keys options:NSVolumeEnumerationSkipHiddenVolumes];
	int count = [vols count];

	if (p_drive < 0 || p_drive >= count) {
		[pool release];
		ERR_FAIL_INDEX_V(p_drive, count, "");
	}

	NSString *path = [[vols objectAtIndex:p_drive] path];
	volname.parse_utf8([path UTF8String]);
#else
	NSArray *vols = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	int count = [vols count];

	if (p_drive < 0 || p_drive >= count) {
		[pool release];
		ERR_FAIL_INDEX_V(p_drive, count, "");
	}

	NSString *path = [vols objectAtIndex:p_drive];
	volname.parse_utf8([path UTF8String]);
#endif
	[pool release];
	return volname;
}

bool DirAccessOSX::is_hidden(const String &p_name) {
#ifdef MAC_OS_X_10_6_FEATURES
	String f = get_current_dir().plus_file(p_name);
	NSString * str = [NSString stringWithUTF8String: f.utf8().get_data()];
	NSURL *url = [NSURL fileURLWithPath:str];

	NSNumber *hidden = nil;
	if (![url getResourceValue:&hidden forKey:NSURLIsHiddenKey error:nil]) {
		return DirAccessUnix::is_hidden(p_name);
	}
	return [hidden boolValue];
#else
	return DirAccessUnix::is_hidden(p_name);
#endif
}

#endif // UNIX_ENABLED || LIBC_FILEIO_ENABLED
