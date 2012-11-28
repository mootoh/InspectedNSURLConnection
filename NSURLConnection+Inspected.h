//
//  NSURLConnection+Inspected.h
//
//  Created by Motohiro Takayama (mootoh@gmail.com) on 11/27/12.
//

#import <Foundation/Foundation.h>

/**
 * NSURLConnection extension to log the request/response.
 *
 * Can be useful when using 3rd party binary library and
 * wants to inspect what data is going on.
 */
@interface NSURLConnection (Inspected)
+ (void) setupSwizzling;
@end