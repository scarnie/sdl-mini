//
//  sdl_event.m
//  A2600
//
//  Created by Stuart Carnie on 10/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDL.h"
#import <queue>
#import "CNSRecursiveLock.h"
#include "../joystick/SDL_joystick_c.h"

using std::queue;

NSRecursiveLock *queueLock;
queue<SDL_Event> *eventQueue;

int SDL_EventInit() {
	queueLock = [NSRecursiveLock new];
	eventQueue = new queue<SDL_Event>();
	return 0;
}

extern "C" void SDL_Lock_EventThread(void) {
}

extern "C" void SDL_Unlock_EventThread(void) {
}

static __inline__ SDL_bool
SDL_ShouldPollJoystick()
{
    return SDL_TRUE;
}

int inputMode = 0;

#if 0

#include "touchstick.h"

extern CJoyStick g_touchStick;

int SDL_PollMouseEvent(SDL_Event* a) {
	TouchStickDPadState state = g_touchStick.dPadState();
	if (state == DPadCenter)
		return 0;
	
	static Uint32 timer = SDL_GetTicks();
	Uint32 now = SDL_GetTicks();
	if (now - timer < 20) {
		return 0;
	}
	timer = now;
	
	int x=0, y=0;
	
	switch (g_touchStick.dPadState()) {
		case DPadUp:
			y = -1;
			break;
		case DPadUpRight:
			y = -1, x = 1;
			break;
		case DPadRight:
			x = 1;
			break;
		case DPadDownRight:
			y = 1, x = 1;
			break;
		case DPadDown:
			y = 1;
			break;
		case DPadDownLeft:
			y = 1, x = -1;
			break;
		case DPadLeft:
			x = -1;
			break;
		case DPadUpLeft:
			y = -1, x = -1;
			break;
	}
	
	if (x!=0 || y != 0) {
		a->type = SDL_MOUSEMOTION;
		a->motion.yrel = y;
		a->motion.xrel = x;
		return 1;
	}
	return 0;
} 
#endif

int SDL_PollEvent(SDL_Event *e) {
	//if (inputMode == 2) {
	//	int res = SDL_PollMouseEvent(e);
	//	if (res)
	//		return res;
	//}
    
    /* Check for joystick state change */
    if (SDL_ShouldPollJoystick()) {
        SDL_JoystickUpdate();
    }
									 
	if (eventQueue->size()) {
		memcpy(e, &(eventQueue->front()), sizeof(SDL_Event));
		
		{
			CNSRecursiveLock autolock(queueLock);	// this ensures the lock is released on function exit
			eventQueue->pop();
		}
		
		if (e->type == SDL_NOEVENT)
			return 0;
		return 1;
	}
	e->type = SDL_NOEVENT;
	return 0;
}

int SDL_PushEvent(SDL_Event *e) {
	CNSRecursiveLock autolock(queueLock);	// this ensures the lock is released on function exit	
	eventQueue->push(*e);
	return 1;
}

void SDL_PushKeyEvent(SDLKey key) {
	CNSRecursiveLock autolock(queueLock);	// this ensures the lock is released on function exit
	SDL_Event e = { SDL_KEYDOWN };
	e.key.keysym.sym = key;
	eventQueue->push(e);
	
	e.type = SDL_NOEVENT;
	eventQueue->push(e);
	
	e.type = SDL_KEYUP;
	eventQueue->push(e);
}

void SDL_PumpEvents(void) {
	SInt32 result;
	do {
		result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, TRUE);
	} while(result == kCFRunLoopRunHandledSource);
    
    /* Check for joystick state change */
    if (SDL_ShouldPollJoystick()) {
        SDL_JoystickUpdate();
    }
}