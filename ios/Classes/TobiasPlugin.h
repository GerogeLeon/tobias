#import <Flutter/Flutter.h>


@interface TobiasPlugin : NSObject<FlutterPlugin,FlutterApplicationLifeCycleDelegate>
+(BOOL)handleOpenURL:(NSURL*)url;
@end
