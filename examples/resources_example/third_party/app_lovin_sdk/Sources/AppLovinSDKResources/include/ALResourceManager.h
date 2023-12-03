//
//  ALResourceManager.h
//  AppLovinSDK
//
//  Created by Ritam Sarmah on 11/3/21.
//  Copyright © 2021 AppLovin Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALResourceManager : NSObject

@property (class, nonatomic, strong, readonly) NSURL *resourceBundleURL;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
