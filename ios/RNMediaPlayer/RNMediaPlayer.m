//
//  ExternalDisplayMediaQueueManager.m
//  player_app
//
//  Created by 嚴孝頤 on 2016/1/16.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import "RNMediaPlayer.h"

@implementation RNMediaPlayer {
	BOOL alreadyInitialize;
	UIScreen *screen;
	UIWindow *window;
	UIViewController *viewController;
	NSMutableArray *renderQueue;
	Container *rendoutContainer;
}

-(id)init {
	if ( self = [super init] ) {
		alreadyInitialize = NO;
	}
	return self;
}

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(initialize: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
	if(!alreadyInitialize){
		// Initialize property
		renderQueue = [[NSMutableArray alloc] init];
		rendoutContainer = nil;
	
		// External screen connect notification
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		[center addObserver:self selector:@selector(handleScreenDidConnectNotification:) name:UIScreenDidConnectNotification object:nil];
		[center addObserver:self selector:@selector(handleScreenDidDisconnectNotification:) name:UIScreenDidDisconnectNotification object:nil];
		
		// Window initialize
		dispatch_async(dispatch_get_main_queue(), ^{
			NSArray *screens = [UIScreen screens];
			if([screens count] > 1){
				screen = [screens objectAtIndex:1];
			}
			else{
				screen = [screens objectAtIndex:0];
			}
			window = [[UIWindow alloc] init];
			[window setBackgroundColor:[UIColor redColor]];
			viewController = [[UIViewController alloc] init];
			window.rootViewController = viewController;
			[self changeScreen];
			
			// Add UIPanGestureRecognizer
			UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
			[window addGestureRecognizer:pan];
			UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
			[window addGestureRecognizer:pinch];

			resolve(@{});
		});
		alreadyInitialize = YES;
	}
	[self clearAll];
}

RCT_EXPORT_METHOD(pushImage: (NSString *)path type:(NSString *)type duration:(NSTimeInterval)duration resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
	UIImage *image = [UIImage imageWithContentsOfFile:path];
	NSLog(@"duration:%f", duration);
	Container *container = [[ImageContainer alloc] initWithImage:image duration:duration renderView:window];
	if([self pushContainer:container withStringType:type]){
		resolve(@{});
	}
	else{
		NSError *err = [NSError errorWithDomain:@"Can't push image" code:-1 userInfo:nil];
		reject([NSString stringWithFormat: @"%lu", (long)err.code], err.localizedDescription, err);
	}
}

RCT_EXPORT_METHOD(pushVideo: (NSString *)path type:(NSString *)type resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
	Container *container = [[VideoContainer alloc] initWithURL:[NSURL URLWithString:path] renderView:window];
	if([self pushContainer:container withStringType:type]){
		resolve(@{});
	}
	else{
		NSError *err = [NSError errorWithDomain:@"Can't push video" code:-1 userInfo:nil];
		reject([NSString stringWithFormat: @"%lu", (long)err.code], err.localizedDescription, err);
	}
}

RCT_EXPORT_METHOD(clearAll: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
	[self clearAll];
	resolve(@{});
}

-(void) clearAll{
	if(rendoutContainer){
		renderQueue = [[NSMutableArray alloc] init];
	}
	else if([renderQueue count] > 0){
		Container *lastObject = [renderQueue lastObject];
		[NSMutableArray arrayWithObject:lastObject];
		[lastObject rendOut];
	}
}

-(BOOL) pushContainer: (Container *)container withStringType:(NSString *)type{
	enum ContainerPushType containerPushType = AtLast;
	if([type isEqualToString:@"AfterNow"]){
		containerPushType = AfterNow;
	}
	else if([type isEqualToString:@"Interrupt"]){
		containerPushType = Interrupt;
	}
	else if([type isEqualToString:@"ClearOther"]){
		containerPushType = ClearOther;
	}
	return [self pushContainer:container withType:containerPushType];
}

-(void) changeScreen{
	window.screen = screen;
	window.frame = CGRectMake(0, 0, screen.bounds.size.width / 2, screen.bounds.size.height / 2);
	[window makeKeyAndVisible];
}

-(void) handleScreenDidConnectNotification: (NSNotification *)notification{
	// Must inishiate event
	NSLog(@"Screen Connect");
	// Change screen to external screen
	NSArray *screens = [UIScreen screens];
	if([screens count] > 1){
		screen = [screens objectAtIndex:1];
		[self changeScreen];
	}
}

-(void) handleScreenDidDisconnectNotification: (NSNotification *)notification{
	NSLog(@"Screen Disconnect");
	// Change screen to internal screen
	NSArray *screens = [UIScreen screens];
	screen = [screens objectAtIndex:0];
	[self changeScreen];
}

-(BOOL) pushContainer: (Container *)container withType:(enum ContainerPushType) type{
	if(renderQueue){
		container.delegate = self;
		switch(type){
			case AtLast:
				[renderQueue insertObject:container atIndex:0];
				break;
			case AfterNow:
				if(rendoutContainer || [renderQueue count] == 0){
					[renderQueue addObject:container];
				}
				else{
					[renderQueue insertObject:container atIndex:([renderQueue count] - 1)];
				}
				break;
			case Interrupt:
				if(rendoutContainer || [renderQueue count] == 0){
					[renderQueue addObject:container];
				}
				else{
					[renderQueue insertObject:container atIndex:([renderQueue count] - 1)];
					[((Container *)[renderQueue lastObject]) rendOut];
				}
				break;
			case ClearOther:
				if(rendoutContainer || [renderQueue count] == 0){
					renderQueue = [NSMutableArray arrayWithObject:container];
				}
				else{
					Container *lastObject = [renderQueue lastObject];
					renderQueue = [NSMutableArray arrayWithObject:container];
					[renderQueue addObject:lastObject];
					[lastObject rendOut];
				}
				break;
		}
		if(!rendoutContainer && [renderQueue count] == 1){
			[self showNextContent];
		}
		return YES;
	}
	else{
		return NO;
	}
}

-(void) showNextContent{
	NSLog(@"showNextContent");
	if([renderQueue count] > 0){
		Container *container = renderQueue.lastObject;
		[container rendIn];
	}
}

-(void) containerRendInStart{
	NSLog(@"containerRendInStart");
}

-(void) containerRendOutStart{
	NSLog(@"containerRendOutStart");
	rendoutContainer = renderQueue.lastObject;
	[renderQueue removeObjectAtIndex:[renderQueue count] - 1];
}

-(void) containerRendOutFinish{
	NSLog(@"containerRendOutFinish");
	rendoutContainer = nil;
	[self showNextContent];
}

-(void) handlePan: (UIPanGestureRecognizer *)recognizer{
	CGPoint translation = [recognizer translationInView:window];
	recognizer.view.center = CGPointMake((recognizer.view.center.x + translation.x), (recognizer.view.center.y + translation.y));
	[recognizer setTranslation:CGPointMake(0, 0) inView:window];
}

-(void) handlePinch: (UIPinchGestureRecognizer *)recognizer{
	if(recognizer.state == UIGestureRecognizerStateBegan || recognizer.state == UIGestureRecognizerStateChanged){
		recognizer.view.transform = CGAffineTransformScale(recognizer.view.transform, recognizer.scale, recognizer.scale);
		recognizer.scale = 1;
	}
}

@end