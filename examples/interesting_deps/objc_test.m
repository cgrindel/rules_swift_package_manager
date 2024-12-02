#import <OCMock/OCMock.h>

@import Foundation;
@import XCTest;

@interface ObjcTest : XCTestCase
@end

@implementation ObjcTest

- (void)testMock {
  OCMockObject *mock = [OCMockObject mockForClass:[NSObject class]];
  XCTAssertNotNil(mock);
}

@end
