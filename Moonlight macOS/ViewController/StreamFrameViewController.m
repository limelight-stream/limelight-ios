//
//  StreamFrameViewController.m
//  Moonlight macOS
//
//  Created by Felix Kratz on 09.03.18.
//  Copyright © 2018 Felix Kratz. All rights reserved.
//

#import "StreamFrameViewController.h"
#import "VideoDecoderRenderer.h"
#import "StreamManager.h"
#import "Gamepad.h"
#import "keepAlive.h"
#import "ControllerSupport.h"
#import "StreamView.h"

@interface StreamFrameViewController ()
@end

@implementation StreamFrameViewController {
    StreamManager *_streamMan;
    StreamConfiguration *_streamConfig;
    NSTimer* _eventTimer;
    NSTimer* _searchTimer;
    ViewController* _origin;
    ControllerSupport* _controllerSupport;
}

-(ViewController*) _origin {
    return _origin;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [keepAlive keepSystemAlive];
    self.streamConfig = _streamConfig;

    _streamMan = [[StreamManager alloc] initWithConfig:self.streamConfig
                                            renderView:self.view
                                   connectionCallbacks:self];
    NSOperationQueue* opQueue = [[NSOperationQueue alloc] init];
    [opQueue addOperation:_streamMan];
    
    // Initialize the controllers (GC and IOHID)
    // I have not tested it, but i think there will be a bug, when mixing GC and IOHID Controllers, because all GCControllers also register as IOHID Controllers.
    // To fix this, we need to get the IOHIDDeviceRef for the GCController and compare it with every IOHID Controller.
    // This shouldn't be a problem as long as this will not be put on the mac app store, as the IOHIDDeviceRef is a private field.
    // The other "fix" would be to disable explicit GC support for the mac version for now.
    // Can someone test this?
    _controllerSupport = [[ControllerSupport alloc] init];
    
    // The gamepad currently gets polled at 1/Framerate.
    _eventTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/_streamConfig.frameRate target:self selector:@selector(eventTimerTick) userInfo:nil repeats:true];
    
    // We search for new devices every 2 seconds.
    _searchTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(searchTimerTick) userInfo:nil repeats:true];
}

- (void)eventTimerTick {
    Gamepad_processEvents();
}

- (void)searchTimerTick {
    Gamepad_detectDevices();
}

- (void) viewDidAppear {
    [super viewDidAppear];
    
    // Hide the cursor and disconnect it from the mouse movement
    [NSCursor hide];
    CGAssociateMouseAndMouseCursorPosition(false);
    
    //During the setup the window should not be resizable, but to use the fullscreen feature of macOS it has to be resizable.
    [self.view.window setStyleMask:[self.view.window styleMask] | NSWindowStyleMaskResizable];
    
    if (self.view.bounds.size.height != NSScreen.mainScreen.frame.size.height || self.view.bounds.size.width != NSScreen.mainScreen.frame.size.width) {
        [self.view.window toggleFullScreen:self];
    }
    [_progressIndicator startAnimation:nil];
    [_origin dismissController:nil];
    _origin = nil;
}

-(void)viewWillDisappear {
    [NSCursor unhide];
    [keepAlive allowSleep];
    [_streamMan stopStream];
    CGAssociateMouseAndMouseCursorPosition(true);
    if (self.view.bounds.size.height == NSScreen.mainScreen.frame.size.height && self.view.bounds.size.width == NSScreen.mainScreen.frame.size.width) {
        [self.view.window toggleFullScreen:self];
        [self.view.window setStyleMask:[self.view.window styleMask] & ~NSWindowStyleMaskResizable];
    }
}

- (void)connectionStarted {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_progressIndicator stopAnimation:nil];
        self->_progressIndicator.hidden = true;
    });
}

- (void)connectionTerminated:(long)errorCode {
    [_streamMan stopStream];
    [self transitionToSetupView:1];
}

- (void)transitionToSetupView:(long)errorCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Mac" bundle:nil];
        ViewController* view = (ViewController*)[storyBoard instantiateControllerWithIdentifier :@"setupFrameVC"];
        [view setError:errorCode];
        self.view.window.contentViewController = view;
    });
}

- (void)setOrigin: (ViewController*) viewController {
    _origin = viewController;
}

- (void)displayMessage:(const char *)message {
    //[_streamView drawMessage:[NSString stringWithFormat:@"%s", message]];
}

- (void)displayTransientMessage:(const char *)message {
}

- (void)launchFailed:(NSString *)message {

}

- (void)stageComplete:(const char *)stageName {
    
}

- (void)stageFailed:(const char *)stageName withError:(long)errorCode {
    //[_streamView drawMessage:[NSString stringWithFormat:@"Stage: %s failed with code: %li", stageName, errorCode]];
}

- (void)stageStarting:(const char *)stageName {
    //[_streamView drawMessage:[NSString stringWithFormat:@"%s", stageName]];
}

@end
