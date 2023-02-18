@import Foundation;
@import FooSwift; 

int main(int argc, char **argv) {
  @autoreleasepool {
    // VersionInfo *verInfo = [[VersionInfo alloc] init];

    // NSString *str = @"Hello, World";
    // fprintf(stdout, "%s\n", [str UTF8String]);

    // FooSwiftVersionInfo *verInfo = [[FooSwiftVersionInfo alloc] init];
    // NSString *version = verInfo.version;

    // fprintf(stdout, "%s\n", [version UTF8String]);
    // [version writeToFile:@"/dev/stdout" atomically: NO];

    // NSString *version = @"Hello, World\n";
    // [version writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];

    FooSwiftVersionInfo *verInfo = [[FooSwiftVersionInfo alloc] init];
    NSString *version = verInfo.version;
    [version writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
  }
  return 0;
}
