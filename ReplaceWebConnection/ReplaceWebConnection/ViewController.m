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
