// #import "Foundation/Foundation.h"
@import Foundation;
@import FooSwift; 

int main(int argc, char **argv) {
  @autoreleasepool {
    // VersionInfo *verInfo = [[VersionInfo alloc] init];

    // NSString *str = @"Hello, World";
    // fprintf(stdout, "%s\n", [str UTF8String]);

    FooSwiftVersionInfo *verInfo = [[FooSwiftVersionInfo alloc] init];
    NSString *version = verInfo.version;
    fprintf(stdout, "%s\n", [version UTF8String]);
  }
  return 0;
}
