/**************************************************************************/
/*  camera_osx.mm                                                         */
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

///@TODO this is a near duplicate of CameraIOS, we should find a way to combine those to minimize code duplication!!!!
// If you fix something here, make sure you fix it there as well!

#include "camera_osx.h"
#include "servers/camera/camera_feed.h"

#ifdef MAC_OS_X_10_6_FEATURES
#import <AVFoundation/AVFoundation.h>
#else
#import <QTKit/QTKit.h>
#define AVCaptureDevice QTCaptureDevice
#define AVCaptureDeviceInput QTCaptureDeviceInput
#define AVCaptureVideoDataOutput QTCaptureDecompressedVideoOutput
#endif

//////////////////////////////////////////////////////////////////////////
// MyCaptureSession - This is a little helper class so we can capture our frames

#ifdef MAC_OS_X_10_6_FEATURES
@interface MyCaptureSession : AVCaptureSession <AVCaptureVideoDataOutputSampleBufferDelegate> {
#else
@interface MyCaptureSession : NSObject {
#endif
	Ref<CameraFeed> feed;
	size_t width[2];
	size_t height[2];
	PoolVector<uint8_t> img_data[2];

#ifndef MAC_OS_X_10_6_FEATURES
	QTCaptureSession *session;
#endif
	AVCaptureDeviceInput *input;
	AVCaptureVideoDataOutput *output;
}

@end

@implementation MyCaptureSession

- (id)initForFeed:(Ref<CameraFeed>)p_feed andDevice:(AVCaptureDevice *)p_device {
	if (self = [super init]) {
		NSError *error = nil;
		feed = p_feed;
		width[0] = 0;
		height[0] = 0;
		width[1] = 0;
		height[1] = 0;

#ifdef MAC_OS_X_10_6_FEATURES
		[self beginConfiguration];

		input = [AVCaptureDeviceInput deviceInputWithDevice:p_device error:&error];
		if (!input) {
			print_line("Couldn't get input device for camera");
		} else {
			[self addInput:input];
		}

		output = [AVCaptureVideoDataOutput new];
		if (!output) {
			print_line("Couldn't get output device for camera");
		} else {
			NSDictionary *settings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) };
			output.videoSettings = settings;

			// discard if the data output queue is blocked (as we process the still image)
			[output setAlwaysDiscardsLateVideoFrames:YES];

			// now set ourselves as the delegate to receive new frames.
			[output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

			// this takes ownership
			[self addOutput:output];
		}

		[self commitConfiguration];

		// kick off our session..
		[self startRunning];
	};
#else
		// Create capture session
		session = [[QTCaptureSession alloc] init];

		// Create device input
		if ([p_device open:&error]) {
			input = [[QTCaptureDeviceInput alloc] initWithDevice:p_device];
			if ([session addInput:input error:&error]) {
				// Create video output
				output = [[QTCaptureDecompressedVideoOutput alloc] init];
				[output setDelegate:self];

				NSDictionary *pixelBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:k422YpCbCr8CodecType], kCVPixelBufferPixelFormatTypeKey,
					nil];
				[output setPixelBufferAttributes:pixelBufferAttributes];

				if ([session addOutput:output error:&error]) {
					[session startRunning];
				} else {
					print_line("Couldn't add video output");
				}
			} else {
				print_line("Couldn't add device input");
			}
		} else {
			print_line("Couldn't open capture device");
		} 
	};
#endif
	return self;
}

- (void)cleanup {
	// stop running
	[self stopRunning];

	// cleanup
#ifdef MAC_OS_X_10_6_FEATURES
	[self beginConfiguration];
#else
	[session stopRunning];
#endif

	// remove input
	if (input) {
#ifdef MAC_OS_X_10_6_FEATURES
		[self removeInput:input];
#else
		[session removeInput:input];
		[[input device] close];
		[input release];
#endif
		// don't release this
		input = NULL;
	}

	// free up our output
	if (output) {
#ifdef MAC_OS_X_10_6_FEATURES
		[self removeOutput:output];
		[output setSampleBufferDelegate:nil queue:NULL];
#else
		[session removeOutput:output];
#endif
		[output release];
		output = NULL;
	}

#ifdef MAC_OS_X_10_6_FEATURES
	[self commitConfiguration];
#else
	[session release];
	session = nil;
#endif
}

- (void)dealloc {
	[self cleanup];
	[super dealloc];
}

#ifdef MAC_OS_X_10_6_FEATURES
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	// This gets called every time our camera has a new image for us to process.
	// May need to investigate in a way to throttle this if we get more images then we're rendering frames..

	// For now, version 1, we're just doing the bare minimum to make this work...
	CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	// int _width = CVPixelBufferGetWidth(pixelBuffer);
	// int _height = CVPixelBufferGetHeight(pixelBuffer);

	// It says that we need to lock this on the documentation pages but it's not in the samples
	// need to lock our base address so we can access our pixel buffers, better safe then sorry?
	CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

	// get our buffers
	unsigned char *dataY = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
	unsigned char *dataCbCr = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
	if (dataY == NULL) {
		print_line("Couldn't access Y pixel buffer data");
	} else if (dataCbCr == NULL) {
		print_line("Couldn't access CbCr pixel buffer data");
	} else {
		Ref<Image> img[2];

		{
			// do Y
			size_t new_width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
			size_t new_height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);

			if ((width[0] != new_width) || (height[0] != new_height)) {
				width[0] = new_width;
				height[0] = new_height;
				img_data[0].resize(new_width * new_height);
			}

			PoolVector<uint8_t>::Write w = img_data[0].write();
			memcpy(w.ptr(), dataY, new_width * new_height);

			img[0].instance();
			img[0]->create(new_width, new_height, 0, Image::FORMAT_R8, img_data[0]);
		}

		{
			// do CbCr
			size_t new_width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
			size_t new_height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);

			if ((width[1] != new_width) || (height[1] != new_height)) {
				width[1] = new_width;
				height[1] = new_height;
				img_data[1].resize(2 * new_width * new_height);
			}

			PoolVector<uint8_t>::Write w = img_data[1].write();
			memcpy(w.ptr(), dataCbCr, 2 * new_width * new_height);

			///TODO GLES2 doesn't support FORMAT_RG8, need to do some form of conversion
			img[1].instance();
			img[1]->create(new_width, new_height, 0, Image::FORMAT_RG8, img_data[1]);
		}

		// set our texture...
		feed->set_YCbCr_imgs(img[0], img[1]);
	}

	// and unlock
	CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}
#else
- (void)captureOutput:(QTCaptureOutput *)captureOutput didOutputVideoFrame:(CVImageBufferRef)videoFrame withSampleBuffer:(QTSampleBuffer *)sampleBuffer fromConnection:(QTCaptureConnection *) connection {
	CVPixelBufferLockBaseAddress(videoFrame, 0);

	size_t sourceWidth = CVPixelBufferGetWidth(videoFrame);
	size_t sourceHeight = CVPixelBufferGetHeight(videoFrame);
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(videoFrame);
	void *baseAddress = CVPixelBufferGetBaseAddress(videoFrame);

	if (width[0] != sourceWidth || height[0] != sourceHeight) {
		width[0] = sourceWidth;
		height[0] = sourceHeight;
		img_data[0].resize(sourceWidth * sourceHeight * 4);
	}

	PoolVector<uint8_t>::Write w = img_data[0].write();
	memcpy(w.ptr(), baseAddress, sourceWidth * sourceHeight * 4);

	Ref<Image> img;
	img.instance();
	img->create(sourceWidth, sourceHeight, 0, Image::FORMAT_RGBA8, img_data[0]);

	feed->set_RGB_img(img);

	CVPixelBufferUnlockBaseAddress(videoFrame, 0);
}
#endif

@end

//////////////////////////////////////////////////////////////////////////
// CameraFeedOSX - Subclass for camera feeds in OSX

class CameraFeedOSX : public CameraFeed {
private:
	AVCaptureDevice *device;
	MyCaptureSession *capture_session;

public:
	AVCaptureDevice *get_device() const;

	CameraFeedOSX();
	~CameraFeedOSX();

	void set_device(AVCaptureDevice *p_device);

	bool activate_feed();
	void deactivate_feed();
};

AVCaptureDevice *CameraFeedOSX::get_device() const {
	return device;
};

CameraFeedOSX::CameraFeedOSX() {
	device = NULL;
	capture_session = NULL;
};

void CameraFeedOSX::set_device(AVCaptureDevice *p_device) {
	device = p_device;
	[device retain];

	// get some info
#ifdef MAC_OS_X_10_6_FEATURES
	NSString *device_name = p_device.localizedName;
	name = String::utf8(device_name.UTF8String);
#else
	name = String::utf8([[device description] UTF8String]);
#endif

	position = CameraFeed::FEED_UNSPECIFIED;
#ifdef MAC_OS_X_10_6_FEATURES
	if ([p_device position] == AVCaptureDevicePositionBack) {
		position = CameraFeed::FEED_BACK;
	} else if ([p_device position] == AVCaptureDevicePositionFront) {
		position = CameraFeed::FEED_FRONT;
	};
#endif
};

CameraFeedOSX::~CameraFeedOSX() {
	if (capture_session != NULL) {
		[capture_session release];
		capture_session = NULL;
	};

	if (device != NULL) {
		[device release];
		device = NULL;
	};
};

bool CameraFeedOSX::activate_feed() {
	if (capture_session) {
		// Already recording!
	} else {
		// Start camera capture, check permission.
		capture_session = [[MyCaptureSession alloc] initForFeed:this andDevice:device];
	};

	return true;
};

void CameraFeedOSX::deactivate_feed() {
	// end camera capture if we have one
	if (capture_session) {
		[capture_session cleanup];
		[capture_session release];
		capture_session = NULL;
	};
};

//////////////////////////////////////////////////////////////////////////
// MyDeviceNotifications - This is a little helper class gets notifications
// when devices are connected/disconnected

@interface MyDeviceNotifications : NSObject {
	CameraOSX *camera_server;
}

@end

@implementation MyDeviceNotifications

- (void)devices_changed:(NSNotification *)notification {
	camera_server->update_feeds();
}

- (id)initForServer:(CameraOSX *)p_server {
	if (self = [super init]) {
		camera_server = p_server;
#ifdef MAC_OS_X_10_6_FEATURES
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(devices_changed:) name:AVCaptureDeviceWasConnectedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(devices_changed:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];
#else
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(deviceConnected:)
			name:QTCaptureDeviceWasConnectedNotification
			object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(deviceDisconnected:)
			name:QTCaptureDeviceWasDisconnectedNotification
			object:nil];

#endif
	};
	return self;
}

- (void)dealloc {
	// remove notifications
#ifdef MAC_OS_X_10_6_FEATURES
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceWasConnectedNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceWasDisconnectedNotification object:nil];
#else
	[[NSNotificationCenter defaultCenter] removeObserver:self];
#endif

	[super dealloc];
}

@end

MyDeviceNotifications *device_notifications = nil;

//////////////////////////////////////////////////////////////////////////
// CameraOSX - Subclass for our camera server on OSX

void CameraOSX::update_feeds() {
#ifdef MAC_OS_X_10_6_FEATURES
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
#else
	NSArray *devices = [QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeVideo];
#endif

	// remove devices that are gone..
	for (int i = feeds.size() - 1; i >= 0; i--) {
		Ref<CameraFeedOSX> feed = (Ref<CameraFeedOSX>)feeds[i];

		if (![devices containsObject:feed->get_device()]) {
			// remove it from our array, this will also destroy it ;)
			remove_feed(feed);
		};
	};

	// add new devices..
	NSEnumerator *enumerator = [devices objectEnumerator];
	QTCaptureDevice *device;
	while((device = [enumerator nextObject])) {
		bool found = false;
		for (int i = 0; i < feeds.size() && !found; i++) {
			Ref<CameraFeedOSX> feed = (Ref<CameraFeedOSX>)feeds[i];
			if (feed->get_device() == device) {
				found = true;
			};
		};

		if (!found) {
			Ref<CameraFeedOSX> newfeed;
			newfeed.instance();
			newfeed->set_device(device);

			// assume display camera so inverse
			Transform2D transform = Transform2D(-1.0, 0.0, 0.0, -1.0, 1.0, 1.0);
			newfeed->set_transform(transform);

			add_feed(newfeed);
		};
	};
};

CameraOSX::CameraOSX() {
	// Find available cameras we have at this time
	update_feeds();

	// should only have one of these....
	device_notifications = [[MyDeviceNotifications alloc] initForServer:this];
};

CameraOSX::~CameraOSX() {
	[device_notifications release];
};
