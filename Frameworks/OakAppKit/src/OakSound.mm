#import "OakSound.h"
#import <io/path.h>

void OakPlayUISound (OakSoundIdentifier aSound)
{
	struct sound_info_t
	{
		OakSoundIdentifier name;
		std::string path;
		NSSound* sound;
	};

	static sound_info_t sounds[] =
	{
		{ OakSoundDidTrashItemUISound,         "dock/drag to trash.aif"   },
		{ OakSoundDidMoveItemUISound,          "system/Volume Mount.aif"  },
		{ OakSoundDidCompleteSomethingUISound, "system/burn complete.aif" },
		{ OakSoundDidBeginRecordingUISound,    "system/begin_record.caf"  },
		{ OakSoundDidEndRecordingUISound,      "system/end_record.caf"    }
	};

	for(auto& sound : sounds)
	{
		if(sound.name == aSound)
		{
			if(!sound.sound)
			{
				// The system UI sounds have lived here since macOS 10.7 and still
				// do on macOS 26. Missing files degrade to silence, not to errors.
				std::string const path = path::join("/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds", sound.path);
				sound.sound = [[NSSound alloc] initWithContentsOfFile:[NSString stringWithUTF8String:path.c_str()] byReference:YES];
			}

			[sound.sound play];
			break;
		}
	}
}
