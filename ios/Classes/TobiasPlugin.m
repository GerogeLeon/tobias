#import "TobiasPlugin.h"
#import <AlipaySDK/AlipaySDK.h>

__weak TobiasPlugin* __tobiasPlugin;

@interface TobiasPlugin()

@property (atomic, copy) FlutterResult currentCallback;

@end

@implementation TobiasPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"com.jarvanmo/tobias"
              binaryMessenger:[registrar messenger]];
    TobiasPlugin* instance = [[TobiasPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    [registrar addApplicationDelegate:instance];
}

#pragma mark - Flutter Plugin

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
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
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - Application Delegates

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [self handleOpenURL:url];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        __weak TobiasPlugin* __self = self;
        [[AlipaySDK defaultService] handleOpenUniversalLink:userActivity standbyCallback:^(NSDictionary *resultDic) {
            [__self onPayResultReceived:resultDic];
        }];
        return YES;
    }
    return NO;
}

#pragma mark - URL Handling

- (BOOL)handleOpenURL:(NSURL*)url {
    if ([url.host isEqualToString:@"safepay"] || [url.host isEqualToString:@"platformapi"]) {
        __weak TobiasPlugin* __self = self;

        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            [__self onPayResultReceived:resultDic];
        }];

        [[AlipaySDK defaultService] processAuth_V2Result:url standbyCallback:^(NSDictionary *resultDic) {
            [__self onAuthResultReceived:resultDic];
        }];

        return YES;
    }
    return NO;
}

#pragma mark - Callback Handling

- (void)onPayResultReceived:(NSDictionary*)resultDic {
    // FlutterResult 是线程安全的，可以在任何线程调用
    @synchronized (self) {
        if (self.currentCallback) {
            NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:resultDic];
            [response setValue:@"iOS" forKey:@"platform"];
            self.currentCallback(response);
            self.currentCallback = nil;
        }
    }
}

- (void)onAuthResultReceived:(NSDictionary*)resultDic {
    // FlutterResult 是线程安全的，可以在任何线程调用
    @synchronized (self) {
        if (self.currentCallback) {
            NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:resultDic];
            [response setValue:@"iOS" forKey:@"platform"];
            self.currentCallback(response);
            self.currentCallback = nil;
        }
    }
}

#pragma mark - Payment Implementation

- (void)pay:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString* urlScheme = [self fetchUrlScheme];
    if (!urlScheme) {
        result([FlutterError errorWithCode:@"ALIPAY_URLSCHEME_NOT_FOUND"
                                 message:@"未找到支付宝 URL Scheme"
                                 details:nil]);
        return;
    }

    NSString *orderString = call.arguments[@"order"];
    if (!orderString) {
        result([FlutterError errorWithCode:@"INVALID_ORDER"
                                 message:@"订单信息不能为空"
                                 details:nil]);
        return;
    }

    @synchronized (self) {
        self.currentCallback = result;
    }

    __weak TobiasPlugin* __self = self;

    [[AlipaySDK defaultService] payOrder:orderString
                              fromScheme:urlScheme
                        fromUniversalLink:call.arguments[@"universalLink"]
                                callback:^(NSDictionary *resultDic) {
        // 支付宝回调可能在任意线程，但 FlutterResult 是线程安全的
        [__self onPayResultReceived:resultDic];
    }];
}

- (void)_auth:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString* urlScheme = [self fetchUrlScheme];
    if (!urlScheme) {
        result([FlutterError errorWithCode:@"ALIPAY_URLSCHEME_NOT_FOUND"
                                 message:@"未找到支付宝 URL Scheme"
                                 details:nil]);
        return;
    }

    NSString *authInfo = call.arguments;
    if (!authInfo) {
        result([FlutterError errorWithCode:@"INVALID_AUTH_INFO"
                                 message:@"授权信息不能为空"
                                 details:nil]);
        return;
    }

    @synchronized (self) {
        self.currentCallback = result;
    }

    __weak TobiasPlugin* __self = self;

    [[AlipaySDK defaultService] auth_V2WithInfo:authInfo
                                     fromScheme:urlScheme
                                       callback:^(NSDictionary *resultDic) {
        [__self onAuthResultReceived:resultDic];
    }];
}

#pragma mark - Utility Methods

- (void)getVersion:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString *version = [AlipaySDK defaultService].currentVersion ?: @"";
    result(version);
}

- (NSString*)fetchUrlScheme {
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSArray* types = infoDic[@"CFBundleURLTypes"];

    for (NSDictionary* dic in types) {
        if ([@"alipay" isEqualToString:dic[@"CFBundleURLName"]]) {
            NSArray *schemes = dic[@"CFBundleURLSchemes"];
            if (schemes && schemes.count > 0) {
                return schemes[0];
            }
        }
    }
    return nil;
}

- (void)_isAliPayInstalled:(FlutterMethodCall*)call result:(FlutterResult)result {
    BOOL installed = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"alipays://"]];
    result(@(installed));
}

- (void)_isAliPayHKInstalled:(FlutterMethodCall*)call result:(FlutterResult)result {
    BOOL installed = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"alipayhk://"]];
    result(@(installed));
}

@end
