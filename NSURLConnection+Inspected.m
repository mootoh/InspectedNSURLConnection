//
//  NSURLConnection+Inspected.m
//
//  Created by Motohiro Takayama (mootoh@gmail.com) on 11/27/12.
//

#import "NSURLConnection+Inspected.h"
#import "JRSwizzle.h"

@interface NSURLConnection (InspectionDelegates)
+ (NSMutableSet *)inspectedDelegates;
@end

@implementation NSURLConnection (InspectionDelegates)

static NSMutableSet *s_delegates = nil;

+ (NSMutableSet *)inspectedDelegates
{
	if (! s_delegates)
		s_delegates = [[NSMutableSet alloc] init];
	return s_delegates;
}

@end

/**
 * NSURLConnection* delegate to handle callbacks first.
 * It will forward the callback to the original delegate after logging.
 */
@interface InspectedConnectionDelegate : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableData *received;
@property (nonatomic, strong) id <NSURLConnectionDelegate> actualDelegate;
@property (nonatomic, strong) NSURLResponse *response;
@end

@implementation InspectedConnectionDelegate
@synthesize received, actualDelegate, response;

- (id) initWithActualDelegate:(id <NSURLConnectionDelegate>)actual
{
	self = [super init];
	if (self) {
		self.received = [[NSMutableData alloc] init];
		[self.received setLength:0];
		self.actualDelegate = actual;
		self.response = nil;
	}
	return self;
}

- (void) cleanup:(NSError *)error
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	if (self.response)
		userInfo[@"response"] = self.response;
	if (self.received.length > 0)
		userInfo[@"body"] = self.received;
	if (error)
		userInfo[@"error"] = error;

	[[NSNotificationCenter defaultCenter] postNotificationName:k_RECEIVED_RESPONSE object:nil userInfo:userInfo];

	self.response = nil;
	self.received = nil;
	self.actualDelegate = nil;
	[[NSURLConnection inspectedDelegates] removeObject:self];
}

// ------------------------------------------------------------------------
//
#pragma mark NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if ([self.actualDelegate respondsToSelector:@selector(connection:didFailWithError:)])
		[self.actualDelegate connection:connection didFailWithError:error];

	[self cleanup:error];
}

// ------------------------------------------------------------------------
#pragma mark NSURLConnectionDataDelegate
//
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse
{
	self.response = aResponse;

	if ([self.actualDelegate respondsToSelector:@selector(connection:didReceiveResponse:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		[actual connection:connection didReceiveResponse:response];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.received appendData:data];

	if ([self.actualDelegate respondsToSelector:@selector(connection:didReceiveData:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		[actual connection:connection didReceiveData:data];
	}
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
	NSLog(@"[InspectedConnectionDelegate:%@]: connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:", connection.originalRequest.URL);

	if ([self.actualDelegate respondsToSelector:@selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		[actual connection:connection didSendBodyData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if ([self.actualDelegate respondsToSelector:@selector(connectionDidFinishLoading:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		[actual connectionDidFinishLoading:connection];
	}

	[self cleanup:nil];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	NSLog(@"[InspectedConnectionDelegate:%@]: connection:willSendRequest:redirectResponse:", connection.originalRequest.URL);

	if ([self.actualDelegate respondsToSelector:@selector(connection:willSendRequest:redirectResponse:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		return [actual connection:connection willSendRequest:request redirectResponse:redirectResponse];
	}
	return request;
}

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request
{
	NSLog(@"[InspectedConnectionDelegate:%@]: connection:needNewBodyStream:", connection.originalRequest.URL);

	if ([self.actualDelegate respondsToSelector:@selector(connection:needNewBodyStream:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		return [actual connection:connection needNewBodyStream:request];
	}
	return nil;
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	NSLog(@"[InspectedConnectionDelegate:%@]: connection:willCacheResponse:", connection.originalRequest.URL);

	if ([self.actualDelegate respondsToSelector:@selector(connection:willCacheResponse:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		return [actual connection:connection willCacheResponse:cachedResponse];
	}
	return cachedResponse;
}

@end


@implementation NSURLConnection (Inspected)

// ------------------------------------------------------------------------
#pragma mark -
#pragma mark Class method swizzling
//

#define postSendingRequestNotification [[NSNotificationCenter defaultCenter] postNotificationName:k_SENDING_REQUEST object:nil userInfo:@{@"request" : request}]

+ (NSData *)inspected_sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error
{
	postSendingRequestNotification;

	NSData *responseData = [NSURLConnection inspected_sendSynchronousRequest:request returningResponse:response error:error];

	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	if (*response)
		userInfo[@"response"] = *response;
	if (responseData && responseData.length > 0)
		userInfo[@"body"] = responseData;
	if (*error)
		userInfo[@"error"] = *error;

	[[NSNotificationCenter defaultCenter] postNotificationName:k_RECEIVED_RESPONSE object:nil userInfo:userInfo];

	return responseData;
}

+ (NSURLConnection *)inspected_connectionWithRequest:(NSURLRequest *)request delegate:(id < NSURLConnectionDelegate >)delegate
{
	// connectionWithRequest:delegate calls initWithRequest:delegate internally, so no need to proxy the delegate.
	return [NSURLConnection inspected_connectionWithRequest:request delegate:delegate];
}

+ (void)inspected_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
//	NSLog(@"inspected_sendAsynchronousRequest");
	postSendingRequestNotification;
	[NSURLConnection inspected_sendAsynchronousRequest:request queue:queue completionHandler:handler];
}

// ------------------------------------------------------------------------
#pragma mark -
#pragma mark Instance method swizzling

- (id)inspected_initWithRequest:(NSURLRequest *)request delegate:(id < NSURLConnectionDelegate >)delegate
{
	postSendingRequestNotification;
	InspectedConnectionDelegate *inspectedDelegate = [[InspectedConnectionDelegate alloc] initWithActualDelegate:delegate];
	[[NSURLConnection inspectedDelegates] addObject:inspectedDelegate];
	return [self inspected_initWithRequest:request delegate:inspectedDelegate];
}

- (id)inspected_initWithRequest:(NSURLRequest *)request delegate:(id < NSURLConnectionDelegate >)delegate startImmediately:(BOOL)startImmediately
{
	postSendingRequestNotification;
	InspectedConnectionDelegate *inspectedDelegate = [[InspectedConnectionDelegate alloc] initWithActualDelegate:delegate];
	[[NSURLConnection inspectedDelegates] addObject:inspectedDelegate];
	return [self inspected_initWithRequest:request delegate:inspectedDelegate startImmediately:startImmediately];
}
#undef postSendingRequestNotification

// ------------------------------------------------------------------------
#pragma mark -
#pragma mark Method swizzling magics.
+ (void) swizzleClassMethod:(SEL)from to:(SEL)to
{
	NSError *error = nil;
	BOOL swizzled = [NSURLConnection jr_swizzleClassMethod:from withClassMethod:to error:&error];
	if (!swizzled || error) {
		NSLog(@"Failed in replacing method: %@", error);
	}
}

+ (void) swizzleMethod:(SEL)from to:(SEL)to
{
	NSError *error = nil;
	BOOL swizzled = [NSURLConnection jr_swizzleMethod:from withMethod:to error:&error];
	if (!swizzled || error) {
		NSLog(@"Failed in replacing method: %@", error);
	}
}

static BOOL s_inspectionEnabled = NO;

+ (void) setInspection:(BOOL)enabled
{
	if (s_inspectionEnabled == enabled)
		return;

	s_inspectionEnabled = enabled;

#define inspected_method(method) inspected_##method
#define swizzle_class_method_wrap(method) [NSURLConnection swizzleClassMethod:@selector(method) to:@selector(inspected_method(method))]
#define swizzle_method_wrap(method) [NSURLConnection swizzleMethod:@selector(method) to:@selector(inspected_method(method))]

	swizzle_class_method_wrap(sendSynchronousRequest:returningResponse:error:);
	swizzle_class_method_wrap(connectionWithRequest:delegate:);
	swizzle_class_method_wrap(sendAsynchronousRequest:queue:completionHandler:);

	swizzle_method_wrap(initWithRequest:delegate:);
	swizzle_method_wrap(initWithRequest:delegate:startImmediately:);

#undef swizzle_method_wrap
#undef swizzle_class_method_wrap
#undef inspected_method
}

+ (BOOL) inspectionEnabled
{
	return s_inspectionEnabled;
}

@end