#import "Foo.h"

@import SimpleCore;

@implementation FooVersionInfo

/* - (instancetype)init { */
/*   self = [super init]; */
/*   return self; */
/* } */


- (NSString *)myVersion {
  VersionInfo *versionInfo = [[VersionInfo alloc] init];
  return versionInfo.version
}

@end
