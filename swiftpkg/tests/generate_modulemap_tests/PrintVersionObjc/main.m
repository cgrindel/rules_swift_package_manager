// #import "Foundation/Foundation.h";
@import Foundation;
@import FooSwift; 

int main(int argc, char **argv) {
  @autoreleasepool {
    OIFooSwiftVersionInfo *verInfo = [[OIFooSwiftVersionInfo alloc] init];
     NSString *version = verInfo.myVersion;
    [version writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
  }
  return 0;
}
