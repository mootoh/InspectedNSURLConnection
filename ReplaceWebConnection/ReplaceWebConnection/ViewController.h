//
//  ViewController.h
//  ReplaceWebConnection
//
//  Created by Motohiro Takayama on 11/27/12.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (nonatomic) BOOL inspectionEnabled;
@property (strong, nonatomic) IBOutlet UILabel *inspectionEnabledLabel;

- (IBAction)toggleInspection:(id)sender;
- (IBAction)runTest:(id)sender;

@end
