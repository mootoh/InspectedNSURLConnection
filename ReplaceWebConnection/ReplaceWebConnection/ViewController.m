//
//  ViewController.m
//  ReplaceWebConnection
//
//  Created by Motohiro Takayama on 11/27/12.
//

#import "ViewController.h"
#import "NSURLConnection+Inspected.h"

@interface OtherDelegate : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@end

@implementation OtherDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSLog(@"OtherDelegate: connection:didReceiveData:");
}

@end

@implementation ViewController

- (void) testSendSynchronous
{
	NSURLRequest *req = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://google.com"]];
	NSURLResponse *res = nil;
	NSError *err = nil;
	[NSURLConnection sendSynchronousRequest:req returningResponse:&res error:&err];
	if (err) {
		NSLog(@"error: %@", err);
	} else {
		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)res;
		if (! httpResponse)
			return;
		NSLog(@"HTTP response status code: %d", httpResponse.statusCode);
	}
}

- (void) testConnectionWithDelegate
{
	NSURLRequest *req = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://google.com"]];
	OtherDelegate *delegate = [[OtherDelegate alloc] init];
	[NSURLConnection connectionWithRequest:req delegate:delegate];
}

- (void) test
{
	[self testSendSynchronous];
	[self testConnectionWithDelegate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendingRequest:) name:k_SENDING_REQUEST object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedResponse:) name:k_RECEIVED_RESPONSE object:nil];

	self.inspectionEnabled = NO;
	self.inspectionEnabledLabel.text = @"Disabled";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)toggleInspection:(id)sender
{
	self.inspectionEnabled = !self.inspectionEnabled;
	self.inspectionEnabledLabel.text = self.inspectionEnabled ? @"Enabled" : @"Disabled";
	[NSURLConnection setInspection:self.inspectionEnabled];
}

- (IBAction)runTest:(id)sender {
	[self test];
}

@end

/**
 * NSURLRequest category for inspection
 */
@implementation NSURLRequest (Inspect)

- (NSString *) inspect
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

/**
 * NSHTTPURLResponse category for inspection
 */
@implementation NSHTTPURLResponse (Inspect)

- (NSString *) inspect:(NSData *)body error:(NSError *)error
{
	NSString *detail = @"NSHTTPURLResponse detail: {\n";
	detail = [detail stringByAppendingFormat:@"     URL: %@\n", self.URL];
	detail = [detail stringByAppendingFormat:@"  status: %d\n", self.statusCode];
	if (body && [body length] > 0) {
		NSString *bodyString = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
		if (bodyString)
			detail = [detail stringByAppendingFormat:@"    Body: %@\n", bodyString];
	}
	if (error)
		detail = [detail stringByAppendingFormat:@"   Error: %@\n", error];
	detail = [detail stringByAppendingString:@"}"];
	NSLog(@"%@", detail);
	return detail;
}

@end


@implementation ViewController (Observer)

- (void) sendingRequest:(NSNotification *)notification
{
	NSDictionary *userInfo = notification.userInfo;
	NSURLRequest *request = userInfo[@"request"];
	NSLog(@"[Observer:sendingRequest:]: dumping request");
	[request inspect];
}

- (void) receivedResponse:(NSNotification *)notification
{
	NSDictionary *userInfo = notification.userInfo;
	NSHTTPURLResponse *response = userInfo[@"response"];
	NSData *responseBody = userInfo[@"body"];
	NSError *error = userInfo[@"error"];

	if (response) {
		NSLog(@"[Observer:receivedResponse:]: dumping response");
		[response inspect:responseBody error:error];
	}
}

@end