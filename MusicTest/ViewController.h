//
//  ViewController.h
//  MusicTest
//
//  Created by Yohei Yoshikawa on 11/11/04.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/MusicPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface ViewController : UIViewController
 <
AVAudioSessionDelegate,
UITableViewDelegate
>
{
    MusicPlayer musicPlayer;
    CFURLRef inPathToMIDIFile;
    NSMutableArray *aupresetFiles;
    NSMutableArray *songs;
    NSUInteger currentSongIndex;
    
    AudioUnit samplerUnit1;
    AudioUnit samplerUnit2;
    AUNode samplerNode1;
    AUNode samplerNode2;
    
    AUNode multiChannelMixerNode;
}

@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (nonatomic, strong) IBOutlet UILabel  *currentPresetLabel;

@property (nonatomic, strong) NSMutableArray *aupresetFiles;
@property (nonatomic, strong) NSMutableArray *songs;
@property (nonatomic) NSUInteger currentSongIndex;

@property (readwrite) Float64 graphSampleRate;
@property (readwrite) AUGraph processingGraph;

@property (readwrite) AudioUnit samplerUnit1;
@property (readwrite) AudioUnit samplerUnit2;
@property (readwrite) AUNode samplerNode1;
@property (readwrite) AUNode samplerNode2;

@property (readwrite) AUNode multiChannelMixerNode;
@property (readwrite) AudioUnit multiChannelMixerAudioUnit;

- (IBAction)clickedStartButton:(UIButton *)sender;
- (IBAction)clickedStopButton:(UIButton *)sender;

- (IBAction)clickedLoadPreset:(UIButton *)sender;
- (IBAction)startPlayLowNote:(UIButton *)sender;
- (IBAction)stopPlayLowNote:(UIButton *)sender;
- (IBAction)startPlayMidNote:(UIButton *)sender;
- (IBAction)stopPlayMidNote:(UIButton *)sender;
- (IBAction)startPlayHighNote:(UIButton *)sender;
- (IBAction)stopPlayHighNote:(UIButton *)sender;

- (void)initPresets;
- (void)loadPreset:(NSUInteger)index;

- (void)playMusic:(NSUInteger)songIndex;
- (void)stopMusic;

- (BOOL)setupAudioSession;
- (OSStatus)loadSynthFromPresetURL:(NSURL *)presetURL;
- (BOOL)createAUGraph;
- (void)playNoteOn:(UInt32)noteNum :(UInt32)velocity;
- (void)playNoteOff:(UInt32)noteNum;

- (OSStatus)loadSynthFromPresetURL:(NSURL *) presetURL;
- (void)registerForUIApplicationNotifications;
- (BOOL)createAUGraph;
- (void)configureAndStartAudioProcessingGraph: (AUGraph) graph;
- (void)stopAudioProcessingGraph;
- (void)restartAudioProcessingGraph;


//
extern AudioStreamBasicDescription AUCanonicalASBD(Float64 sampleRate, UInt32 channel);
extern AudioStreamBasicDescription CanonicalASBD(Float64 sampleRate, UInt32 channel);

//
static void musicEventUserDataCallback(void *inclientData, MusicSequence inSequence, MusicTrack inTrack, MusicTimeStamp inEventTime, const MusicEventUserData *inEventData, MusicTimeStamp inStartSliceBeat, MusicTimeStamp inEndSliceBeat);

@end
