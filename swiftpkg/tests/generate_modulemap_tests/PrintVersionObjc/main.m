#import "Foundation/Foundation.h"

// @import Foundation;
// @import FooSwift; 

int main(int argc, char **argv) {
  @autoreleasepool {
    // VersionInfo *verInfo = [[VersionInfo alloc] init];
    //
    NSString *str = @"Hello, World";
    fprintf(stdout, "%s\n", [str UTF8String]);


    //OIPrinter *printer = [[OIPrinter alloc] initWithPrefix:@"*** "];
    //[printer print:@"Hello world"];
  }
  return 0;
}
