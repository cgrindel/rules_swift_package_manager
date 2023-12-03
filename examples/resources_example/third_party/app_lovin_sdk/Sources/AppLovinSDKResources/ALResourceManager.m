//
//  ALResourceManager.m
//  AppLovinSDK
//
//  Created by Ritam Sarmah on 11/3/21.
//  Copyright © 2021 AppLovin Corporation. All rights reserved.
//

#import "ALResourceManager.h"

@implementation ALResourceManager

static NSURL *ALResourceBundleURL;

+ (void)initialize
{
    [super initialize];
    
    ALResourceBundleURL = [SWIFTPM_MODULE_BUNDLE URLForResource: @"AppLovinSDKResources" withExtension: @"bundle"];
}

+ (NSURL *)resourceBundleURL
{
    return ALResourceBundleURL;
}

@end
