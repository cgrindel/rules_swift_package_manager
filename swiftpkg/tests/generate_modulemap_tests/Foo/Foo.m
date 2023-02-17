#import "Foo.h"

@import SimpleCore;

@implementation FooVersionInfo

- (NSString *)myVersion {
  VersionInfo *versionInfo = [[VersionInfo alloc] init];
  return versionInfo.myVersion;
}

@end
