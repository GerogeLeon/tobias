![logo](./arts/tobias_logo.png)

[![pub package](https://img.shields.io/pub/v/tobias.svg)](https://pub.dartlang.org/packages/tobias)
![Build status](https://github.com/OpenFlutter/tobias/actions/workflows/build_test.yml/badge.svg)
[![GitHub stars](https://img.shields.io/github/stars/OpenFlutter/tobias)](https://github.com/OpenFlutter/tobias/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/OpenFlutter/tobias)](https://github.com/OpenFlutter/tobias/network)
[![GitHub license](https://img.shields.io/github/license/OpenFlutter/tobias)](https://github.com/OpenFlutter/tobias/blob/master/LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/OpenFlutter/tobias)](https://github.com/OpenFlutter/tobias/issues)
<a target="_blank" href="https://qm.qq.com/q/TJ29rkzywM"><img border="0" src="https://pub.idqqimg.com/wpa/images/group.png" alt="OpenFlutter" title="OpenFlutter"></a>

> Join QQ Group now: 1003811176

![QQGroup](https://gitee.com/OpenFlutter/resoures-repository/raw/master/common/flutter.png)

## Tobias是什么

Tobias 是一个为支付宝支付 SDK 做的 Flutter 插件，支持 iOS, Android 和 OpenHarmony

## 使用的alipay sdk 版本

android alipaysdk version: 15.8.35
ios alipaysdk version: 15.8.35
https://opendocs.alipay.com/open/54/104509

alipay SDK 付款存在以下两种模式，商家测试人员需要关注这两类场景完成测试。
○ 若用户已安装支付宝客户端，则直接跳转到支付宝客户端进行付款。
○ 若用户未安装支付宝客户端，则在本 SDK 内部进行 H5 支付。

## iOS上插件正常工作前提 （我踩的坑，我不是ios开发者）

===AppDelegate.swift
在业务项目的 ios/Runner/AppDelegate.swift 中的application方法中必须有调父类

```swift
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
       //其它代码
       //必须要调父类的，否则插件中的application方法不会执行，导致支付结果参数的回调不会进行（插件功能异常）
        return super.application(app, open: url, options: options);
    }
```

===Info.plist
Info.plist文件中供alipay用的URLScheme不能与其它的同名 （AI回答的，我未验证，但建议不要搞，可问iOS同学）

```agsl
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>alipay</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>membershipApp</string>   //不能再给其它的用
			</array>
		</dict>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>wechat</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>membershipAppWeChat</string>   //不能再用上面的membershipApp
			</array>
		</dict>
```

===验证URL Scheme生效 （我的为membershipApp）
支行ios app后，在Safari中打开 membershipApp://safepay ， 要能调起app。

## 开始

在使用前强烈阅读[官方接入指南](https://docs.open.alipay.com/204/105051/)。

1. 您需要在[pubspec.yaml](./example/pubspec.yaml)中配置`url_scheme`。 Url scheme是一个独特的字符串用来重新启动你的app
   但是请注意字符串`_`是不合法的.
2. 如果在 OpenHarmony, 请在项目中的 `module.json5` 文件中的 `module.querySchemes` 中添加 `alipays`，如下:

```json5
{
  "module": {
    "querySchemes": [
      "alipays"
    ],
  }
}
```

## 支付

Tobias使用起来很简单，只需要把从服务器取得的字符串交给Tobias就行了:
如果安卓出现Unhandled Exception: MissingPluginException(No implementation found for method pay on channel
com.jarvanmo/tobias)错误
请将[android/build.gradle](https://github.com/OpenFlutter/tobias/blob/master/android/build.gradle#L5)更改为同一版本。

```dart
import 'package:tobias/tobias.dart' ;
Tobias tobias = Tobias();
tobias.pay(yourOrder);
```

在iOS端, 你还需要配置并传入一个universal link.
See [how to configure universal link](https://opendocs.alipay.com/open/0b9qzi).

返回值是一个包含支付宝支付结果的`map`。其中还包含了一个额外的 `platform`字段，
它的值为 `iOS` 或 `android`。
> 注意:Tobias 使用的是 pay_V2.

## 授权登录

> 当前在 OpenHarmony 上不支持授权登录

```
import 'package:tobias/tobias.dart' ;
Tobias tobias = Tobias();
tobias.auth("your auth str);
```

## 检查支付宝安装情况

```
Tobias tobias = Tobias();
var result = await tobias.isAliPayInstalled;
```

你可以通过调用 `tobias.version` 来获取对应平上的SDK版本，其返回值是一个包含 `version` 和 `platform`的map。
结果示例:

```dart
{result: partner="2088411752388544"&seller_id="etongka123@163.com"&out_trade_no="180926084213001"&subject="test pay"&total_fee="0.01"&notify_url="http://127.0.0.1/alipay001"&service="mobile.securitypay.pay"&payment_type="1"&_input_charset="utf-8"&it_b_pay="30m"&return_url="m.alipay.com"&success="true"&sign_type="RSA"&sign="nCZ8MDhsNvYNAbrLZJZ2VUy6vydgAp+JCq1aQo6ORDYtI9zwtnja3qNGQNiDJCuktoIj7fSTM487XhjPDqnOreZjIA1GJpxu9D1I3nMXIn1M7DfZ0noDwXcYZ438/jbYac7g8mhpwdKGweLCAni9mO3Y6q3iBFkox8i9PcsGxJY=",
resultStatus: 9000,
memo:
,
platform
:
iOS
}

```

> 如果你在iOS上遇到了 `utdid`问题, 你可以在[pubspec.yaml](./example/pubspec.yaml)中开启`no_utdid: true`。

## 升级到1.0.0

从`tobais 1.0.0`开始开发者不必重写`AppDelegate`了。如果你以前重写了这个方法,请在 `AppDelegate`中删除相应的代码:

```objective-c

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
  return [WXApi handleOpenURL:url delegate:[FluwxResponseHandler defaultManager]];
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString*, id> *)options
{
  return [WXApi handleOpenURL:url delegate:[FluwxResponseHandler defaultManager]];
}
```

如果一定要重写这2个方法,请确保你调用了 `super`:

```objective-c

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
  return [super application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString*, id> *)options
{
    
  return [super application:application openURL:url options:options];
}
```

## 请作者喝杯咖啡

<img src="./arts/wx.jpeg" height="300">  <img src="./arts/ali.jpeg" height="300">

### 欢迎关注公众号

![subscribe](./arts/wx_subscription.png)

## LICENSE

    Copyright 2018 OpenFlutter Project

    Licensed to the Apache Software Foundation (ASF) under one or more contributor
    license agreements.  See the NOTICE file distributed with this work for
    additional information regarding copyright ownership.  The ASF licenses this
    file to you under the Apache License, Version 2.0 (the "License"); you may not
    use this file except in compliance with the License.  You may obtain a copy of
    the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
    License for the specific language governing permissions and limitations under
    the License.
