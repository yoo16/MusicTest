//
//  ViewController.m
//  MusicTest
//
//  Created by Yohei Yoshikawa on 11/11/04.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import <AssertMacros.h>

//MIDI constants:
enum {
	kMIDIMessage_NoteOn    = 0x9,
	kMIDIMessage_NoteOff   = 0x8,
};

#define kLowNote  48
#define kHighNote 72
#define kMidNote  60

@implementation ViewController

@synthesize startButton = _startButton;
@synthesize stopButton = _stopButton;
@synthesize currentPresetLabel = _currentPresetLabel;
@synthesize aupresetFiles = _aupresetFiles;
@synthesize songs = _songs;
@synthesize currentSongIndex = _currentSongIndex;

@synthesize graphSampleRate = _graphSampleRate;
@synthesize processingGraph = _processingGraph;

@synthesize samplerUnit1 = _samplerUnit1;
@synthesize samplerUnit2 = _samplerUnit2;
@synthesize samplerNode1 = _samplerNode1;
@synthesize samplerNode2 = _samplerNode2;

@synthesize multiChannelMixerAudioUnit = _multiChannelMixerAudioUnit;
@synthesize multiChannelMixerNode = _multiChannelMixerNode;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initPresets];
    
    //Set up the audio session
    BOOL audioSessionActivated = [self setupAudioSession];
    NSLog(@"audioSessionActivated = %d", audioSessionActivated);

    //Create the audio processing graph
    [self createAUGraph];
    [self configureAndStartAudioProcessingGraph: _processingGraph];

    //loadPreset
    [self clickedLoadPreset: (UIButton *)self];
    
    //[self registerForUIApplicationNotifications];
}

- (void)viewDidUnload
{
    NSLog(@"--- viewDidUnload ---");
    [self stopMusic];
    AUGraphClose(_processingGraph);
    DisposeAUGraph(_processingGraph);
    DisposeMusicPlayer(musicPlayer);
    
    [self setStartButton:nil];
    [self setStopButton:nil];
    [self setCurrentPresetLabel:nil];
    [self setAupresetFiles:nil];
    [self setSongs:nil];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft);
}

#pragma -
#pragma IBAction
- (IBAction)clickedStartButton:(UIButton *)sender {
    [self playMusic:_currentSongIndex];
}

- (IBAction)clickedStopButton:(UIButton *)sender {
    [self stopMusic];
}

- (IBAction)clickedLoadPreset:(UIButton *)sender
{
    [self loadPreset:0];
}

- (IBAction) startPlayLowNote:(UIButton *)sender
{
    [self playNoteOn:sender.tag :127];
}

- (IBAction) stopPlayLowNote:(UIButton *)sender
{
	[self playNoteOff:sender.tag];
}

- (IBAction) startPlayMidNote:(UIButton *)sender
{
	[self playNoteOn:sender.tag :127];
}

- (IBAction) stopPlayMidNote:(UIButton *)sender
{
	[self playNoteOff:sender.tag];
}

- (IBAction) startPlayHighNote:(UIButton *)sender
{
	[self playNoteOn:sender.tag :127];
}

- (IBAction)stopPlayHighNote:(UIButton *)sender
{
	[self playNoteOff:sender.tag];
}

#pragma -
#pragma Custom Method
- (void)initPresets
{
    _currentSongIndex = 0;
    _aupresetFiles = [NSMutableArray arrayWithObjects:@"Piano1", @"Trombone1", @"Vibraphone1", nil];
    _songs = [NSMutableArray arrayWithObjects:@"WonderChristmas", @"HappyXmas", @"silent_night_jz", @"JingleBell", nil];
}

#pragma MusicPlayer
- (void)stopMusic
{
    MusicPlayerStop(musicPlayer);
}

- (void)playMusic:(NSUInteger)songIndex
{
    OSStatus result = noErr;

    Boolean isPlaying;
    MusicPlayerIsPlaying(musicPlayer, &isPlaying);
    if (isPlaying) return;

    //new sequence
    MusicSequence sequence = NULL;
    if (NewMusicSequence(&sequence) != noErr) NSLog(@"error");

    //load midi file
    NSString *soundName = [_songs objectAtIndex:songIndex];
    NSString *midiPath = [[NSBundle mainBundle] pathForResource:soundName ofType:@"mid"];
    inPathToMIDIFile = (__bridge CFURLRef)[NSURL fileURLWithPath:midiPath];
    result = MusicSequenceFileLoad(sequence, inPathToMIDIFile,
                                   kMusicSequenceFile_MIDIType,
                                   kMusicSequenceLoadSMF_ChannelsToTracks);
    NSLog(@"MusicSequenceFileLoad = %ld", result);
    
    //new musicPlayer
    result = NewMusicPlayer(&musicPlayer);
    NSLog(@"NewMusicPlayer = %ld", result);
    
    //set sequence to musicPlayer
    result = MusicPlayerSetSequence(musicPlayer, sequence);
    NSLog(@"MusicPlayerSetSequence = %ld", result);
    
    //get sequence from musicPlayer
    result = MusicPlayerGetSequence(musicPlayer, &sequence);
    NSLog(@"MusicPlayerGetSequence = %ld", result);
    
    //add AUGraph to sequence
    result = MusicSequenceSetAUGraph(sequence, _processingGraph);
    NSLog(@"MusicSequenceSetAUGraph = %ld", result);

    //play sequence on musicPlayer
    result = MusicPlayerStart(musicPlayer);
    NSLog(@"MusicPlayerStart = %ld", result);
    
    //numbers of track
    UInt32 numbersOfTrack = 0;
    MusicSequenceGetTrackCount(sequence, &numbersOfTrack);
    NSLog(@"numbersOfTrack = %d", (int) numbersOfTrack);
    
    for (int i = 0; i < numbersOfTrack; i++) {
        MusicTrack track = NULL;
        AUNode trackNode = 0;
        result = MusicSequenceGetIndTrack(sequence, i, &track);	
        result = MusicTrackGetDestNode(track, &trackNode);
        NSLog(@"MusicSequenceGetIndTrack %d = %ld",i, trackNode);
        
        MIDIEndpointRef midiEndpoint;
        result = MusicTrackGetDestMIDIEndpoint(track, &midiEndpoint);
        NSLog(@"MusicTrackGetDestMIDIEndpoint %ld", result);
        
        MIDIEntityRef midiEntity;
        result = MIDIEndpointGetEntity(midiEndpoint, &midiEntity);
        NSLog(@"MIDIEndpointGetEntity %ld", result);
        //-10855 = kAudioToolboxErr_IllegalTrackDestination
        
        MIDIDeviceRef midiDevice;
        result = MIDIEntityGetDevice(midiEntity, &midiDevice);
        NSLog(@"MIDIEntityGetDevice %ld", result);
        //-10842 = kMIDIObjectNotFound
        
        ItemCount itemCount = MIDIDeviceGetNumberOfEntities(midiDevice);
        NSLog(@"itemCount %ld", itemCount);
    }

    //tempo track
    MusicTrack tempoTrack;
    result = MusicSequenceGetTempoTrack(sequence, &tempoTrack);
    NSLog(@"MusicSequenceGetTempoTrack = %ld", result);
    
    MusicTimeStamp timeStamp;
    MusicPlayerGetTime(musicPlayer, &timeStamp);
    NSLog(@"timeStamp = %f", timeStamp);
    
    //Callback
    result = MusicSequenceSetUserCallback(sequence, musicEventUserDataCallback, NULL);
    NSLog(@"MusicSequenceSetUserCallback = %ld", result);
    char *userDataName = "MyEvent";
    MusicEventUserData *userData = (MusicEventUserData *) malloc(sizeof(MusicEventUserData) 
                                                                 + (sizeof(UInt8) * (strlen(userDataName) - 1)));
    //if(userData == NULL) return;
    userData->length = strlen(userDataName);
    userData->data[0] = 1;
    free(userData);
    
    //CFDictionaryRef
    CFDictionaryRef cfdDictionary = MusicSequenceGetInfoDictionary(sequence);
    NSLog(@"%@", cfdDictionary);
}

AudioStreamBasicDescription AUCanonicalASBD(Float64 sampleRate, UInt32 channel)
{
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = sampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagsAudioUnitCanonical;
    audioFormat.mChannelsPerFrame = channel;
    audioFormat.mBytesPerPacket = sizeof(AudioUnitSampleType);
    audioFormat.mBytesPerFrame = sizeof(AudioUnitSampleType);
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBitsPerChannel = 8 * sizeof(AudioUnitSampleType);
    audioFormat.mReserved = 0;
    return audioFormat;
}

AudioStreamBasicDescription CanonicalASBD(Float64 sampleRate, UInt32 channel)
{
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = sampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagsCanonical;
    audioFormat.mChannelsPerFrame = channel;
    audioFormat.mBytesPerPacket = sizeof(AudioUnitSampleType) * channel;
    audioFormat.mBytesPerFrame = sizeof(AudioUnitSampleType) * channel;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBitsPerChannel = 8 * sizeof(AudioUnitSampleType);
    audioFormat.mReserved = 0;
    return audioFormat;
}

#pragma mark -
#pragma mark Audio setup
- (BOOL) createAUGraph
{
    NSLog(@"--- createAUGraph ---");
	OSStatus result = noErr;

	result = NewAUGraph(&_processingGraph);
    NSLog(@"NewAUGraph = %ld", result);
    
    //AudioComponent
	AudioComponentDescription cd = {};
	cd.componentType = kAudioUnitType_MusicDevice;
	cd.componentSubType = kAudioUnitSubType_Sampler;
	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;

    //samplerNode add AUNode
	result = AUGraphAddNode(_processingGraph, &cd, &_samplerNode1);
    NSLog(@"samplerNode1 AUGraphAddNode = %ld", result);
    
    result = AUGraphAddNode(_processingGraph, &cd, &_samplerNode2);
    NSLog(@"samplerNode2 AUGraphAddNode = %ld", result);

	cd.componentType = kAudioUnitType_Output;
	cd.componentSubType = kAudioUnitSubType_RemoteIO;  
    //cd.componentType = kAudioUnitType_Mixer;
    //cd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    
    //add AUNode multiChannelMixerNode;
    result = AUGraphAddNode(_processingGraph, &cd, &_multiChannelMixerNode);
    NSLog(@"multiChannelMixerNode AUGraphAddNode = %ld", result);
    
    
    //AUGraphOpen
	result = AUGraphOpen(_processingGraph);
    NSLog(@"AUGraphOpen = %ld", result);
    
    //AUGraphNode Info
	result = AUGraphNodeInfo(_processingGraph, _samplerNode1, 0, &_samplerUnit1);
    NSLog(@"samplerNode1 AUGraphNodeInfo = %ld", result);
    
    //result = AUGraphNodeInfo(_processingGraph, _samplerNode2, 0, &_samplerUnit2);
    //NSLog(@"samplerNode2 AUGraphNodeInfo = %ld", result);

    result = AUGraphNodeInfo(_processingGraph, _multiChannelMixerNode, 0, &_multiChannelMixerAudioUnit);
    NSLog(@"multiChannelMixerNode AUGraphNodeInfo = %ld", result);
    
    
    //AUGraphConnectNodeInput
    result = AUGraphConnectNodeInput(_processingGraph, _samplerNode1, 0, _multiChannelMixerNode, 0);
    NSLog(@"samplerNode1 AUGraphConnectNodeInput = %ld", result);
    
    //result = AUGraphConnectNodeInput(_processingGraph, _samplerNode2, 0, _multiChannelMixerNode, 0);
    //NSLog(@"samplerNode2 AUGraphConnectNodeInput = %ld", result);
    
    return YES;
}

- (void) configureAndStartAudioProcessingGraph: (AUGraph) graph {
    NSLog(@"--- configureAndStartAudioProcessingGraph ---");
    
    OSStatus result = noErr;
    UInt32 framesPerSlice = 0;
    UInt32 framesPerSlicePropertySize = sizeof (framesPerSlice);
    UInt32 sampleRatePropertySize = sizeof (_graphSampleRate);

    result = AudioUnitInitialize (_multiChannelMixerAudioUnit);
    NSLog(@"AudioUnitInitialize = %ld", result);
    
    //Sample rate
    result = AudioUnitSetProperty (_multiChannelMixerAudioUnit,
                                   kAudioUnitProperty_SampleRate,
                                   kAudioUnitScope_Output,
                                   0,
                                   &_graphSampleRate,
                                   sampleRatePropertySize
                                   );
    NSLog(@"multiChannelMixerAudioUnit AudioUnitSetProperty = %ld", result);
    
    result = AudioUnitSetProperty (_samplerUnit1,
                                   kAudioUnitProperty_SampleRate,
                                   kAudioUnitScope_Output,
                                   0,
                                   &_graphSampleRate,
                                   sampleRatePropertySize
                                   );
    NSLog(@"samplerUnit1 AudioUnitSetProperty = %ld", result);
    
//    result = AudioUnitSetProperty (_samplerUnit2,
//                                   kAudioUnitProperty_SampleRate,
//                                   kAudioUnitScope_Output,
//                                   0,
//                                   &_graphSampleRate,
//                                   sampleRatePropertySize
//                                   );
//    NSLog(@"samplerUnit2 AudioUnitSetProperty = %ld", result);
    
    //Audio slice
    result = AudioUnitGetProperty (_multiChannelMixerAudioUnit,
                                   kAudioUnitProperty_MaximumFramesPerSlice,
                                   kAudioUnitScope_Global,
                                   0,
                                   &framesPerSlice,
                                   &framesPerSlicePropertySize
                                   );
    NSLog(@"multiChannelMixerAudioUnit AudioUnitSetProperty = %ld", result);
    
    result = AudioUnitSetProperty (_samplerUnit1,
                                   kAudioUnitProperty_MaximumFramesPerSlice,
                                   kAudioUnitScope_Global,
                                   0,
                                   &framesPerSlice,
                                   framesPerSlicePropertySize
                                   );
    NSLog(@"samplerUnit1 AudioUnitSetProperty = %ld", result);
    
//    result = AudioUnitSetProperty (_samplerUnit2,
//                                   kAudioUnitProperty_MaximumFramesPerSlice,
//                                   kAudioUnitScope_Global,
//                                   0,
//                                   &framesPerSlice,
//                                   framesPerSlicePropertySize
//                                   );
//    NSLog(@"samplerUnit2 AudioUnitSetProperty = %ld", result);


    //Bus count
    UInt32 busCount = 0;
    UInt32 size = sizeof (UInt32);
    AudioUnitGetProperty(_multiChannelMixerAudioUnit,
                         kAudioUnitProperty_ElementCount,
                         kAudioUnitScope_Input,
                         0,
                         &busCount,
                         &size);
    NSLog(@"multiChannelMixer busCount = %d", (int) busCount);

    AudioUnitGetProperty(_samplerUnit1,
                         kAudioUnitProperty_ElementCount,
                         kAudioUnitScope_Output,
                         0,
                         &busCount,
                         &size);
    NSLog(@"samplerUnit1 busCount = %d", (int) busCount);
    
//    AudioUnitGetProperty(_samplerUnit2,
//                         kAudioUnitProperty_ElementCount,
//                         kAudioUnitScope_Output,
//                         0,
//                         &busCount,
//                         &size);
//    NSLog(@"samplerUnit2 busCount = %d", (int) busCount);
    
    //AUGraph initialize
    if (graph) {
        //initialize AUGraph.
        result = AUGraphInitialize(graph);
        NSLog(@"AUGraphInitialize = %ld", result);

        //Start AUGraph
        result = AUGraphStart(graph);
        NSLog(@"AUGraphStart = %ld", result);
    }
}

- (void)loadPreset:(NSUInteger)index
{
    NSLog(@"--- loadPresete ---");
    if (index > [_aupresetFiles count] - 1) return;

    NSString *presetName = [_aupresetFiles objectAtIndex:index];
	NSURL *presetURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:presetName ofType:@"aupreset"]];
	if (presetURL) {
		NSLog(@"presetURL = '%@'\n", [presetURL description]);
        self.currentPresetLabel.text = presetName;
	}
    
	OSStatus result = [self loadSynthFromPresetURL: presetURL];
    NSLog(@"loadSynthFromPresetURL = %ld", result);
}

- (OSStatus)loadSynthFromPresetURL: (NSURL *) presetURL
{
    NSLog(@"--- loadSynthFromPresetURL ---");
	CFDataRef propertyResourceData = 0;
	Boolean status;
	SInt32 errorCode = 0;
	OSStatus result = noErr;
	
	// Read from the URL and convert into a CFData chunk
	status = CFURLCreateDataAndPropertiesFromResource (
                                                       kCFAllocatorDefault,
                                                       (__bridge CFURLRef) presetURL,
                                                       &propertyResourceData,
                                                       NULL,
                                                       NULL,
                                                       &errorCode
                                                       );
    NSLog(@"CFURLCreateDataAndPropertiesFromResource = %ld", result);
    NSLog(@"status %d", status);
   	
	// Convert the data object into a property list
	CFPropertyListRef presetPropertyList = 0;
	CFPropertyListFormat dataFormat = 0;
	CFErrorRef errorRef = 0;
	presetPropertyList = CFPropertyListCreateWithData (
                                                       kCFAllocatorDefault,
                                                       propertyResourceData,
                                                       kCFPropertyListImmutable,
                                                       &dataFormat,
                                                       &errorRef
                                                       );
    
    // Set the class info property for the Sampler unit using the property list as the value.
	if (presetPropertyList != 0) {
		result = AudioUnitSetProperty(_samplerUnit1,
                                      kAudioUnitProperty_ClassInfo,
                                      kAudioUnitScope_Global,
                                      0,
                                      &presetPropertyList,
                                      sizeof(CFPropertyListRef)
                                      );
        NSLog(@"samplerUnit1 = %ld", result);
        
//        result = AudioUnitSetProperty(_samplerUnit2,
//                                      kAudioUnitProperty_ClassInfo,
//                                      kAudioUnitScope_Global,
//                                      0,
//                                      &presetPropertyList,
//                                      sizeof(CFPropertyListRef)
//                                      );
//        NSLog(@"samplerUnit2 = %ld", result);
		CFRelease(presetPropertyList);
	}
    
    if (errorRef) CFRelease(errorRef);
	CFRelease(propertyResourceData);
    
	return result;
}


// Set up the audio session for this app.
- (BOOL) setupAudioSession
{
    NSLog(@"--- setupAudioSession ---");
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setDelegate: self];
    
    //Assign the Playback category to the audio session.
    NSError *audioSessionError = nil;
    [audioSession setCategory: AVAudioSessionCategoryPlayback error: &audioSessionError];
    if (audioSessionError != nil) {NSLog (@"Error setting audio session category."); return NO;}    
    
    //hardware sample rate.
    _graphSampleRate = 44100.0;
    
    [audioSession setPreferredHardwareSampleRate: _graphSampleRate error: &audioSessionError];
    if (audioSessionError != nil) {NSLog (@"Error setting preferred hardware sample rate."); return NO;}
    
    // Activate the audio session
    [audioSession setActive: YES error: &audioSessionError];
    if (audioSessionError != nil) {NSLog (@"Error activating the audio session."); return NO;}
    
    // Obtain the actual hardware sample rate and store it for later use in the audio processing graph.
    _graphSampleRate = [audioSession currentHardwareSampleRate];
    
    return YES;
}

#pragma mark -
#pragma mark Audio control
- (void)playNoteOn:(UInt32)noteNum :(UInt32)velocity 
{
	UInt32 noteCommand = kMIDIMessage_NoteOn << 4 | 0;
    
    OSStatus result = noErr;
	require_noerr (result = MusicDeviceMIDIEvent(_samplerUnit1, noteCommand, noteNum, velocity, 0), logTheError);
    
logTheError:
    if (result != noErr) NSLog (@"Unable to start playing the low note. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
}

- (void)playNoteOff:(UInt32)noteNum
{
	UInt32 noteCommand = kMIDIMessage_NoteOff << 4 | 0;
    
    OSStatus result = noErr;
	require_noerr (result = MusicDeviceMIDIEvent(_samplerUnit1, noteCommand, noteNum, 0, 0), logTheError);

    
logTheError:
    if (result != noErr) NSLog (@"Unable to start playing the low note. Error code: %d '%.4s'\n", (int) result, (const char *)&result);
}

- (void)stopAudioProcessingGraph {
    OSStatus result = noErr;
	if (_processingGraph) 
    {
        result = AUGraphStop(_processingGraph);
        NSLog(@"AUGraphStop = %ld", result);
    }
}

- (void)restartAudioProcessingGraph {
    OSStatus result = noErr;
	if (_processingGraph)
    {
        result = AUGraphStart(_processingGraph);
        NSLog(@"AUGraphStop = %ld", result);
    }
}

#pragma mark -
#pragma mark Audio session delegate methods
- (void)beginInterruption {
    [self stopPlayLowNote: (UIButton *)self];
    [self stopPlayMidNote: (UIButton *)self];
    [self stopPlayHighNote: (UIButton *)self];
    [self stopAudioProcessingGraph];
}

- (void)endInterruptionWithFlags: (NSUInteger) flags {
    NSError *endInterruptionError = nil;
    [[AVAudioSession sharedInstance] setActive: YES
                                         error: &endInterruptionError];
    if (endInterruptionError != nil) {
        NSLog (@"Unable to reactivate the audio session.");
        return;
    }
    
    if (flags & AVAudioSessionInterruptionFlags_ShouldResume) {
        [self restartAudioProcessingGraph];
    }
}

#pragma mark - Application state management
- (void)registerForUIApplicationNotifications
{
    NSLog(@"--- registerForUIApplicationNotifications ---");
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver: self
                           selector: @selector (handleResigningActive:)
                               name: UIApplicationWillResignActiveNotification
                             object: [UIApplication sharedApplication]];
    
    [notificationCenter addObserver: self
                           selector: @selector (handleBecomingActive:)
                               name: UIApplicationDidBecomeActiveNotification
                             object: [UIApplication sharedApplication]];
}


- (void)handleResigningActive: (id) notification
{
    [self stopPlayLowNote: (UIButton *)self];
    [self stopPlayMidNote: (UIButton *)self];
    [self stopPlayHighNote: (UIButton *)self];
    [self stopAudioProcessingGraph];
}

- (void)handleBecomingActive: (id) notification
{
    [self restartAudioProcessingGraph];
}

#pragma -
#pragma UITableView Delegate Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (tableView.tag) {
        case 1:
            return [_songs count];
        case 2:
            return [_aupresetFiles count];
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    switch (tableView.tag) {
        case 1:
            cell.textLabel.text = [_songs objectAtIndex:indexPath.row];
            break;
        case 2:
            cell.textLabel.text = [_aupresetFiles objectAtIndex:indexPath.row];
            break;
        default:
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (tableView.tag) {
        case 1:
            [self stopMusic];
            _currentSongIndex = [indexPath row];
            [self playMusic:_currentSongIndex];
            break;
        case 2:
            [self loadPreset:[indexPath row]];
            break;
        default:
            break;
    }
}



static void musicEventUserDataCallback(void *inclientData, MusicSequence inSequence, MusicTrack inTrack, MusicTimeStamp inEventTime, const MusicEventUserData *inEventData, MusicTimeStamp inStartSliceBeat, MusicTimeStamp inEndSliceBeat) {
    //char *userDataName = "MyEvent";
    //Boolean isMyEvent = strncmp(inEventData->data[1], userDataName, 7);
    //if(isMyEvent) {
        NSLog(@"--- musicEventUserDataCallback ---");
    //}
}


@end
