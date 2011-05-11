#import "NgnMessagingSession.h"
#import "NgnStringUtils.h"
#import <Foundation/NSDictionary.h>

#import "SipSession.h"
#import "SipMessage.h"

#undef kSessions
#define kSessions [NgnMessagingSession getAllSessions]

@interface NgnMessagingSession (Private)
+(NSMutableDictionary*) getAllSessions;
-(NgnMessagingSession*) internalInitWithSipStack: (NgnSipStack*)sipStack andSession: (MessagingSession**)session andRemotePartyUri: (NSString*)remoteUri;
@end


@implementation NgnMessagingSession (Private)

+(NSMutableDictionary*) getAllSessions{
	static NSMutableDictionary* sessions = nil;
	if(sessions == nil){
		sessions = [[NSMutableDictionary alloc] init];
	}
	return sessions;
}

-(NgnMessagingSession*) internalInitWithSipStack: (NgnSipStack*)sipStack andSession: (MessagingSession**)session andRemotePartyUri: (NSString*)remoteUri{
	if((self = (NgnMessagingSession*)[super initWithSipStack:sipStack])){
		if(!(_mSession = new MessagingSession([sipStack getStack]))){
			TSK_DEBUG_ERROR("Failed to create session");
			return self;
		}
		
		if(session && *session){
			_mSession = *session, *session = tsk_null;
		}
		else {
			_mSession = new MessagingSession([sipStack getStack]);
		}
		
		[super initialize];
		[super setSigCompId: [sipStack getSigCompId]];
		[super setToUri: remoteUri];
	}
	return self;
}

@end

@implementation NgnMessagingSession

+(NgnMessagingSession*) takeIncomingSessionWithSipStack: (NgnSipStack*) sipStack andMessagingSession: (MessagingSession**) session andSipMessage: (const SipMessage*) sipMessage{
	const char* _toUri = sipMessage ? const_cast<SipMessage*>(sipMessage)->getSipHeaderValue("f") : tsk_null;
	NgnMessagingSession* imSession = [[[NgnMessagingSession alloc] internalInitWithSipStack: sipStack 
																andSession: session 
																andRemotePartyUri: [NgnStringUtils toNSString: _toUri]] autorelease];
	if(imSession){
		[kSessions setObject: imSession forKey:[imSession getIdAsNumber]];
	}
	return imSession;
}

+(NgnMessagingSession*) createOutgoingSessionWithStack: (NgnSipStack*)sipStack andToUri: (NSString*)_toUri{
	@synchronized(kSessions){
		NgnMessagingSession* imSession = [[[NgnMessagingSession alloc] internalInitWithSipStack: sipStack andSession: tsk_null andRemotePartyUri: _toUri] autorelease];
		if(imSession){
			[kSessions setObject: imSession forKey:[imSession getIdAsNumber]];
		}
		return imSession;
	}
}

+(NgnMessagingSession*) getSessionWithId: (long)sessionId{
	@synchronized(kSessions){
		return [kSessions objectForKey:[NSNumber numberWithLong:sessionId]];
	}
}

+(BOOL) hasSessionWithId: (long)sessionId{
	return [NgnMessagingSession getSessionWithId:sessionId] != nil;
}

+(void) releaseSession: (NgnMessagingSession**) session{
	@synchronized (kSessions){
		if (session && *session){
			if ([(*session) retainCount] == 1) {
				[kSessions removeObjectForKey: [*session getIdAsNumber]];
			}
			else {
				[(*session) release];
			}
			*session = nil;
		}
	}
}

+(NgnMessagingSession*) sendBinaryMessageWithSipStack: (NgnSipStack*)sipStack andToUri: (NSString*)uri andMessage: (NSString*) asciiText smscValue: (NSString*) smsc{
	NgnMessagingSession* imSession = [NgnMessagingSession createOutgoingSessionWithStack: sipStack andToUri: uri];
	if(imSession){
	}
	return imSession;
}

+(NgnMessagingSession*) sendDataWithSipStack: (NgnSipStack*)sipStack andToUri: (NSString*)uri andData: (NSData*) data andContentType: (NSString*) ctype andActionConfig: (ActionConfig*) config{
	NgnMessagingSession* imSession = [NgnMessagingSession createOutgoingSessionWithStack: sipStack andToUri: uri];
	if(imSession){
		if(![imSession sendData: data contentType: ctype actionConfig: config]){
			[NgnMessagingSession releaseSession: &imSession];
		}
	}
	return imSession;
}

+(NgnMessagingSession*) sendDataWithSipStack: (NgnSipStack*)sipStack andToUri: (NSString*)uri andData: (NSData*) data andContentType: (NSString*) ctype{
	return [NgnMessagingSession sendDataWithSipStack: sipStack 
								andToUri: uri 
								andData: data 
								andContentType: ctype
								andActionConfig: nil
			];
}

+(NgnMessagingSession*) sendTextMessageWithSipStack: (NgnSipStack*)sipStack andToUri: (NSString*)uri andMessage: (NSString*) asciiText andContentType: (NSString*) ctype andActionConfig: (ActionConfig*)config{
	NgnMessagingSession* imSession = [NgnMessagingSession createOutgoingSessionWithStack: sipStack andToUri: uri];
	if(imSession){
		if(![imSession sendTextMessage: asciiText contentType: ctype actionConfig: config]){
			[NgnMessagingSession releaseSession: &imSession];
		}
	}
	return imSession;
}

+(NgnMessagingSession*) sendTextMessageWithSipStack: (NgnSipStack*)sipStack andToUri: (NSString*)uri andMessage: (NSString*) asciiText andContentType: (NSString*) ctype{
	return [NgnMessagingSession sendTextMessageWithSipStack: sipStack 
									andToUri: uri 
									andMessage: asciiText 
									andContentType: ctype
									andActionConfig: nil
			];
}

-(BOOL) sendBinaryMessage:(NSString*) asciiText smscValue: (NSString*) smsc{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
	return FALSE;
}

-(BOOL) sendData: (NSData*) data contentType: (NSString*) ctype actionConfig: (ActionConfig*) config{
	if(_mSession){
		[super addHeaderWithName: @"Content-Type" andValue: ctype];
		return _mSession->send([data bytes], [data length], config);
	}
	else {
		TSK_DEBUG_ERROR("Null session");
		return FALSE;
	}
}

-(BOOL) sendData: (NSData*) data contentType: (NSString*) ctype{
	return [self sendData:data contentType:ctype actionConfig:nil];
}

-(BOOL) sendTextMessage:(NSString*) asciiText contentType: (NSString*) ctype actionConfig: (ActionConfig*)config{
	return [self sendData: [asciiText dataUsingEncoding: NSUTF8StringEncoding]
			  contentType: ctype
			  actionConfig: config
			];
}

-(BOOL) sendTextMessage:(NSString*) asciiText contentType: (NSString*) ctype{
	return [self sendData: [asciiText dataUsingEncoding: NSUTF8StringEncoding]
			  contentType: ctype
			];
}

-(BOOL) acceptWithActionConfig: (ActionConfig*)config{
	if(_mSession){
		return _mSession->accept(config);
	}
	else {
		TSK_DEBUG_ERROR("Null session");
		return FALSE;
	}
}

-(BOOL) accept{
	return [self acceptWithActionConfig: nil];
}


-(BOOL) rejectWithActionConfig: (ActionConfig*)config{
	if(_mSession){
		return _mSession->reject(config);
	}
	else {
		TSK_DEBUG_ERROR("Null session");
		return FALSE;
	}
}

-(BOOL) reject{
	return [self rejectWithActionConfig: nil];
}

-(void)dealloc{
	if(_mSession){
		delete _mSession;
	}
	
	[super dealloc];
}

-(SipSession*)getSession{
	return _mSession;
}

@end
