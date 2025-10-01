#import "TobiasPlugin.h"
#import <AlipaySDK/AlipaySDK.h>

__weak TobiasPlugin* __tobiasPlugin;

@interface TobiasPlugin()

@property (atomic, copy) FlutterResult currentCallback;

@end

@implementation TobiasPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NSLog(@"[Tobias] Plugin registered");
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"com.jarvanmo/tobias"
              binaryMessenger:[registrar messenger]];
    TobiasPlugin* instance = [[TobiasPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    [registrar addApplicationDelegate:instance];

    __tobiasPlugin = instance;
}

#pragma mark - Flutter Plugin

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"[Tobias] handleMethodCall called: %@", call.method);

    if ([@"pay" isEqualToString:call.method]) {
        [self pay:call result:result];
    } else if ([@"version" isEqualToString:call.method]) {
        [self getVersion:call result:result];
    } else if ([@"auth" isEqualToString:call.method]) {
        [self _auth:call result:result];
    } else if ([@"isAliPayInstalled" isEqualToString:call.method]) {
        [self _isAliPayInstalled:call result:result];
    } else if ([@"isAliPayHKInstalled" isEqualToString:call.method]) {
        [self _isAliPayHKInstalled:call result:result];
    } else {
        NSLog(@"[Tobias] Unknown method: %@", call.method);
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - Application Delegates

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSLog(@"[Tobias] application:openURL:options: called with URL: %@", url);
    NSLog(@"[Tobias] URL scheme: %@, host: %@", url.scheme, url.host);

    BOOL handled = [self handleOpenURL:url];
    NSLog(@"[Tobias] handleOpenURL result: %@", handled ? @"YES" : @"NO");
    return handled;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    NSLog(@"[Tobias] application:openURL:sourceApplication:annotation: called with URL: %@", url);
    NSLog(@"[Tobias] Source application: %@", sourceApplication);

    BOOL handled = [self handleOpenURL:url];
    NSLog(@"[Tobias] handleOpenURL result: %@", handled ? @"YES" : @"NO");
    return handled;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
    NSLog(@"[Tobias] continueUserActivity called, activityType: %@", userActivity.activityType);

    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = userActivity.webpageURL;
        NSLog(@"[Tobias] Universal Link URL: %@", url);

        __weak TobiasPlugin* __self = self;
        [[AlipaySDK defaultService] handleOpenUniversalLink:userActivity standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"[Tobias] Universal Link standbyCallback received: %@", resultDic);
            [__self onPayResultReceived:resultDic];
        }];
        return YES;
    }
    NSLog(@"[Tobias] Not a browsing web activity, ignoring");
    return NO;
}

#pragma mark - URL Handling

- (BOOL)handleOpenURL:(NSURL*)url {
    NSLog(@"[Tobias] handleOpenURL called with URL: %@", url);
    NSLog(@"[Tobias] URL host: %@", url.host);

    if ([url.host isEqualToString:@"safepay"] || [url.host isEqualToString:@"platformapi"]) {
        NSLog(@"[Tobias] Handling Alipay URL");

        __weak TobiasPlugin* __self = self;

        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"[Tobias] processOrderWithPaymentResult callback: %@", resultDic);
            [__self onPayResultReceived:resultDic];
        }];

        [[AlipaySDK defaultService] processAuth_V2Result:url standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"[Tobias] processAuth_V2Result callback: %@", resultDic);
            [__self onAuthResultReceived:resultDic];
        }];

        return YES;
    }

    NSLog(@"[Tobias] URL not recognized as Alipay URL");
    return NO;
}

#pragma mark - Callback Handling

- (void)onPayResultReceived:(NSDictionary*)resultDic {
    NSLog(@"[Tobias] onPayResultReceived called with result: %@", resultDic);
    NSLog(@"[Tobias] Current callback exists: %@", self.currentCallback ? @"YES" : @"NO");

    // FlutterResult 是线程安全的，可以在任何线程调用
    @synchronized (self) {
        if (self.currentCallback) {
            NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:resultDic];
            [response setValue:@"iOS" forKey:@"platform"];
            NSLog(@"[Tobias] Calling Flutter callback with response: %@", response);
            self.currentCallback(response);
            self.currentCallback = nil;
            NSLog(@"[Tobias] Callback cleared");
        } else {
            NSLog(@"[Tobias] No current callback available, result ignored");
        }
    }
}

- (void)onAuthResultReceived:(NSDictionary*)resultDic {
    NSLog(@"[Tobias] onAuthResultReceived called with result: %@", resultDic);
    NSLog(@"[Tobias] Current callback exists: %@", self.currentCallback ? @"YES" : @"NO");

    // FlutterResult 是线程安全的，可以在任何线程调用
    @synchronized (self) {
        if (self.currentCallback) {
            NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:resultDic];
            [response setValue:@"iOS" forKey:@"platform"];
            NSLog(@"[Tobias] Calling Flutter callback with auth response: %@", response);
            self.currentCallback(response);
            self.currentCallback = nil;
            NSLog(@"[Tobias] Callback cleared");
        } else {
            NSLog(@"[Tobias] No current callback available, auth result ignored");
        }
    }
}

#pragma mark - Payment Implementation

- (void)pay:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"[Tobias] pay method called");

    NSString* urlScheme = [self fetchUrlScheme];
    NSLog(@"[Tobias] Fetched URL scheme: %@", urlScheme);

    if (!urlScheme) {
        NSLog(@"[Tobias] ERROR: URL scheme not found");
        result([FlutterError errorWithCode:@"ALIPAY_URLSCHEME_NOT_FOUND"
                                 message:@"未找到支付宝 URL Scheme"
                                 details:nil]);
        return;
    }

    NSString *orderString = call.arguments[@"order"];
    if (!orderString) {
        NSLog(@"[Tobias] ERROR: Order string is empty");
        result([FlutterError errorWithCode:@"INVALID_ORDER"
                                 message:@"订单信息不能为空"
                                 details:nil]);
        return;
    }

    NSString *universalLink = call.arguments[@"universalLink"];
    NSLog(@"[Tobias] Universal link from arguments: %@", universalLink);

    @synchronized (self) {
        self.currentCallback = result;
        NSLog(@"[Tobias] Current callback set");
    }

    __weak TobiasPlugin* __self = self;

    NSLog(@"[Tobias] Calling AlipaySDK payOrder...");
    [[AlipaySDK defaultService] payOrder:orderString
                              fromScheme:urlScheme
                        fromUniversalLink:universalLink
                                callback:^(NSDictionary *resultDic) {
        NSLog(@"[Tobias] AlipaySDK payOrder callback received: %@", resultDic);
        NSLog(@"[Tobias] Callback thread: %@", [NSThread currentThread]);
        // 支付宝回调可能在任意线程，但 FlutterResult 是线程安全的
        [__self onPayResultReceived:resultDic];
    }];
}

- (void)_auth:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"[Tobias] _auth method called");

    NSString* urlScheme = [self fetchUrlScheme];
    NSLog(@"[Tobias] Fetched URL scheme for auth: %@", urlScheme);

    if (!urlScheme) {
        NSLog(@"[Tobias] ERROR: URL scheme not found for auth");
        result([FlutterError errorWithCode:@"ALIPAY_URLSCHEME_NOT_FOUND"
                                 message:@"未找到支付宝 URL Scheme"
                                 details:nil]);
        return;
    }

    NSString *authInfo = call.arguments;
    if (!authInfo) {
        NSLog(@"[Tobias] ERROR: Auth info is empty");
        result([FlutterError errorWithCode:@"INVALID_AUTH_INFO"
                                 message:@"授权信息不能为空"
                                 details:nil]);
        return;
    }

    @synchronized (self) {
        self.currentCallback = result;
        NSLog(@"[Tobias] Current callback set for auth");
    }

    __weak TobiasPlugin* __self = self;

    NSLog(@"[Tobias] Calling AlipaySDK auth_V2WithInfo...");
    [[AlipaySDK defaultService] auth_V2WithInfo:authInfo
                                     fromScheme:urlScheme
                                       callback:^(NSDictionary *resultDic) {
        NSLog(@"[Tobias] AlipaySDK auth_V2WithInfo callback received: %@", resultDic);
        [__self onAuthResultReceived:resultDic];
    }];
}

#pragma mark - Utility Methods

- (void)getVersion:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *version = [AlipaySDK defaultService].currentVersion ?: @"";
    NSLog(@"[Tobias] getVersion called, returning: %@", version);
    result(version);
}

- (NSString*)fetchUrlScheme {
    NSLog(@"[Tobias] fetchUrlScheme called");

    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSArray* types = infoDic[@"CFBundleURLTypes"];

    NSLog(@"[Tobias] Found %lu URL types", (unsigned long)types.count);

    for (NSDictionary* dic in types) {
        NSString *urlName = dic[@"CFBundleURLName"];
        NSLog(@"[Tobias] Checking URL type: %@", urlName);

        if ([@"alipay" isEqualToString:urlName]) {
            NSArray *schemes = dic[@"CFBundleURLSchemes"];
            NSLog(@"[Tobias] Found alipay URL schemes: %@", schemes);

            if (schemes && schemes.count > 0) {
                NSString *scheme = schemes[0];
                NSLog(@"[Tobias] Using scheme: %@", scheme);
                return scheme;
            }
        }
    }

    NSLog(@"[Tobias] WARNING: No alipay URL scheme found");
    return nil;
}

- (void)_isAliPayInstalled:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSURL *testURL = [NSURL URLWithString:@"alipays://"];
    BOOL installed = [[UIApplication sharedApplication] canOpenURL:testURL];
    NSLog(@"[Tobias] _isAliPayInstalled called, result: %@", installed ? @"YES" : @"NO");
    result(@(installed));
}

- (void)_isAliPayHKInstalled:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSURL *testURL = [NSURL URLWithString:@"alipayhk://"];
    BOOL installed = [[UIApplication sharedApplication] canOpenURL:testURL];
    NSLog(@"[Tobias] _isAliPayHKInstalled called, result: %@", installed ? @"YES" : @"NO");
    result(@(installed));
}

@end
