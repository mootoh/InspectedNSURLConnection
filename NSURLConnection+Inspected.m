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
@end

@implementation InspectedConnectionDelegate
@synthesize received, actualDelegate;

- (id) initWithActualDelegate:(id <NSURLConnectionDelegate>)actual
{
	self = [super init];
	if (self) {
		self.actualDelegate = actual;
		self.received = [[NSMutableData alloc] init];
	}
	return self;
}

- (void) cleanup
{
	self.actualDelegate = nil;
	[[NSURLConnection inspectedDelegates] removeObject:self];
}

// ------------------------------------------------------------------------
//
#pragma mark NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSLog(@"[InspectedConnectionDelegate:%@]: connection:didFailWithError: %@", connection.originalRequest.URL, error);

	[self.actualDelegate connection:connection didFailWithError:error];
	[self cleanup];
}

// ------------------------------------------------------------------------
#pragma mark NSURLConnectionDataDelegate
//
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
	int statusCode = httpResponse ? httpResponse.statusCode : -1;
	NSLog(@"[InspectedConnectionDelegate:%@]: connection:didReceiveResponse:] status code = %d", connection.originalRequest.URL, statusCode);

	if ([self.actualDelegate respondsToSelector:@selector(connection:didReceiveResponse:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		[actual connection:connection didReceiveResponse:response];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSLog(@"[InspectedConnectionDelegate:%@]: connection:didReceiveData:", connection.originalRequest.URL);
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
	NSString *receivedString = [[NSString alloc] initWithData:self.received encoding:NSUTF8StringEncoding];
	NSLog(@"[InspectedConnectionDelegate:%@]: connectionDidFinishLoading: %@", connection.originalRequest.URL, receivedString);

	if ([self.actualDelegate respondsToSelector:@selector(connectionDidFinishLoading:)]) {
		id <NSURLConnectionDataDelegate> actual = (id <NSURLConnectionDataDelegate>)self.actualDelegate;
		[actual connectionDidFinishLoading:connection];
	}
	[self cleanup];
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


/**
 * NSURLRequest category for inspection
 */
@implementation NSURLRequest (Detail)

- (NSString *) dumpDetail
{
	NSString *detail = @"NSURLRequest detail: {\n";
	detail = [detail stringByAppendingFormat:@"     URL: %@\n", self.URL];
	detail = [detail stringByAppendingFormat:@"  Method: %@\n", self.HTTPMethod];
	if (self.HTTPBody && [self.HTTPBody length] > 0) {
		NSString *bodyString = [[NSString alloc] initWithData:self.HTTPBody encoding:NSUTF8StringEncoding];
		if (bodyString)
			detail = [detail stringByAppendingFormat:@"    Body: %@\n", bodyString];
	}
	detail = [detail stringByAppendingString:@"}"];
	NSLog(@"%@", detail);
	return detail;
}

@end

@implementation NSURLConnection (Inspected)

// ------------------------------------------------------------------------
#pragma mark -
#pragma mark Class method swizzling
//
+ (NSData *)inspected_sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error
{
	NSLog(@"NSURLConnection (Inspected) : sendSynchronousRequest:returningResponse:error:");
	[request dumpDetail];

	NSData *ret = [NSURLConnection inspected_sendSynchronousRequest:request returningResponse:response error:error];
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)*response;
	NSLog(@"response = %d", httpResponse.statusCode);
	return ret;
}

+ (NSURLConnection *)inspected_connectionWithRequest:(NSURLRequest *)request delegate:(id < NSURLConnectionDelegate >)delegate
{
	NSLog(@"NSURLConnection (Inspected) : connectionWithRequest:delegate:");
	[request dumpDetail];

	InspectedConnectionDelegate *inspectedDelegate = [[InspectedConnectionDelegate alloc] initWithActualDelegate:delegate];
	[[NSURLConnection inspectedDelegates] addObject:inspectedDelegate];

	return [NSURLConnection inspected_connectionWithRequest:request delegate:inspectedDelegate];
}

+ (void)inspected_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse*, NSData*, NSError*))handler
{
	NSLog(@"NSURLConnection (Inspected) : sendAsynchronousRequest:queue:completionHandler:");
	[request dumpDetail];
	[NSURLConnection inspected_sendAsynchronousRequest:request queue:queue completionHandler:handler];
}

// ------------------------------------------------------------------------
#pragma mark -
#pragma mark Instance method swizzling

- (id)inspected_initWithRequest:(NSURLRequest *)request delegate:(id < NSURLConnectionDelegate >)delegate
{
	NSLog(@"NSURLConnection (Inspected) : initWithRequest:delegate:");
	[request dumpDetail];
	return [self inspected_initWithRequest:request delegate:delegate];
}

- (id)inspected_initWithRequest:(NSURLRequest *)request delegate:(id < NSURLConnectionDelegate >)delegate startImmediately:(BOOL)startImmediately
{
	NSLog(@"NSURLConnection (Inspected) : initWithRequest:delegate:startImmediately:");
	[request dumpDetail];
	return [self inspected_initWithRequest:request delegate:delegate startImmediately:startImmediately];
}

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

+ (void) setupSwizzling
{
	static BOOL initialized = NO;
	if (initialized)
		return;
	initialized = YES;

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

@end