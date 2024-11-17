/**************************************************************************/
/*  tts_osx.mm                                                            */
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

#include "tts_osx.h"

#ifndef MAC_OS_X_VERSION_10_5_FEATURES
#define NSUInteger unsigned long
#endif

@implementation TTS_OSX

- (id)init {
	self = [super init];
	self->speaking = false;
	self->have_utterance = false;
	self->last_utterance = -1;
	self->paused = false;
	self->synth = [[NSSpeechSynthesizer alloc] init];
	[self->synth setDelegate:self];
	print_verbose("Text-to-Speech: NSSpeechSynthesizer initialized.");
	return self;
}


// NSSpeechSynthesizer callback (macOS 10.4+)

- (void)speechSynthesizer:(NSSpeechSynthesizer *)ns_synth willSpeakWord:(NSRange)characterRange ofString:(NSString *)string {
	if (!paused && have_utterance) {
		// Convert from UTF-16 to UTF-32 position.
		int pos = 0;
		for (NSUInteger i = 0; i < MIN(characterRange.location, string.length); i++) {
			unichar c = [string characterAtIndex:i];
			if ((c & 0xfffffc00) == 0xd800) {
				i++;
			}
			pos++;
		}

		OS::get_singleton()->tts_post_utterance_event(OS::TTS_UTTERANCE_BOUNDARY, last_utterance, pos);
	}
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)ns_synth didFinishSpeaking:(BOOL)success {
	if (!paused && have_utterance) {
		if (success) {
			OS::get_singleton()->tts_post_utterance_event(OS::TTS_UTTERANCE_ENDED, last_utterance);
		} else {
			OS::get_singleton()->tts_post_utterance_event(OS::TTS_UTTERANCE_CANCELED, last_utterance);
		}
		have_utterance = false;
	}
	speaking = false;
	[self update];
}

- (void)update {
	if (!speaking && queue.size() > 0) {
		OS::TTSUtterance &message = queue.front()->get();

		NSSpeechSynthesizer *ns_synth = synth;
#ifdef MAC_OS_X_VERSION_10_6_FEATURES
		[ns_synth setObject:nil forProperty:NSSpeechResetProperty error:nil];
#endif
		[ns_synth setVoice:[NSString stringWithUTF8String:message.voice.utf8().get_data()]];
#ifdef MAC_OS_X_VERSION_10_5_FEATURES
		int base_pitch = [[ns_synth objectForProperty:NSSpeechPitchBaseProperty error:nil] intValue];
		[ns_synth setObject:[NSNumber numberWithInt:(base_pitch * (message.pitch / 2.f + 0.5f))] forProperty:NSSpeechPitchBaseProperty error:nullptr];
#endif
		[ns_synth setVolume:(Math::range_lerp(message.volume, 0.f, 100.f, 0.f, 1.f))];
		[ns_synth setRate:(message.rate * 200)];

		last_utterance = message.id;
		have_utterance = true;
		[ns_synth startSpeakingString:[NSString stringWithUTF8String:message.text.utf8().get_data()]];
		
		queue.pop_front();

		OS::get_singleton()->tts_post_utterance_event(OS::TTS_UTTERANCE_STARTED, message.id);
		speaking = true;
	}
}

- (void)pauseSpeaking {
#ifdef MAC_OS_X_VERSION_10_5_FEATURES
	NSSpeechSynthesizer *ns_synth = synth;
	[ns_synth pauseSpeakingAtBoundary:NSSpeechImmediateBoundary];
	paused = true;
#endif
}

- (void)resumeSpeaking {
#ifdef MAC_OS_X_VERSION_10_5_FEATURES
	NSSpeechSynthesizer *ns_synth = synth;
	[ns_synth continueSpeaking];
	paused = false;
#endif
}

- (void)stopSpeaking {
	for (List<OS::TTSUtterance>::Element *E = queue.front(); E; E = E->next()) {
		OS::TTSUtterance &message = E->get();
		OS::get_singleton()->tts_post_utterance_event(OS::TTS_UTTERANCE_CANCELED, message.id);
	}
	queue.clear();
	NSSpeechSynthesizer *ns_synth = synth;
	if (have_utterance) {
		OS::get_singleton()->tts_post_utterance_event(OS::TTS_UTTERANCE_CANCELED, last_utterance);
	}
	[ns_synth stopSpeaking];
	have_utterance = false;
	speaking = false;
	paused = false;
}

- (bool)isSpeaking {
	return speaking || (queue.size() > 0);
}

- (bool)isPaused {
	return paused;
}

- (void)speak:(const String &)text voice:(const String &)voice volume:(int)volume pitch:(float)pitch rate:(float)rate utterance_id:(int)utterance_id interrupt:(bool)interrupt {
	if (interrupt) {
		[self stopSpeaking];
	}

	if (text.empty()) {
		OS::get_singleton()->tts_post_utterance_event(OS::TTS_UTTERANCE_CANCELED, utterance_id);
		return;
	}

	OS::TTSUtterance message;
	message.text = text;
	message.voice = voice;
	message.volume = CLAMP(volume, 0, 100);
	message.pitch = CLAMP(pitch, 0.f, 2.f);
	message.rate = CLAMP(rate, 0.1f, 10.f);
	message.id = utterance_id;
	queue.push_back(message);

	if ([self isPaused]) {
		[self resumeSpeaking];
	} else {
		[self update];
	}
}

- (Array)getVoices {
	Array list;
	
#ifdef MAC_OS_X_VERSION_10_5_FEATURES
	for (NSString *voiceIdentifierString in [NSSpeechSynthesizer availableVoices]) {
		NSString *voiceLocaleIdentifier = [[NSSpeechSynthesizer attributesForVoice:voiceIdentifierString] objectForKey:NSVoiceLocaleIdentifier];
		NSString *voiceName = [[NSSpeechSynthesizer attributesForVoice:voiceIdentifierString] objectForKey:NSVoiceName];
		Dictionary voice_d;
		voice_d["name"] = String([voiceName UTF8String]);
		voice_d["id"] = String([voiceIdentifierString UTF8String]);
		voice_d["language"] = String([voiceLocaleIdentifier UTF8String]);
		list.push_back(voice_d);
	}
#endif
	return list;
}

@end
