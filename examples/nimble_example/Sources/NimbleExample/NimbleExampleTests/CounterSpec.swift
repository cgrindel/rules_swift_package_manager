//
//  CounterSpec.swift
//  NimbleExampleTests
//
//  Created by TingYao Hsu on 23/03/2023.
//

import Nimble
import Quick

final class CounterSpec: QuickSpec {
  override func spec() {
    describe("Counter") {

      context("when counting a sentence") {
        let string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
        it("should return length") {
          expect(string.count).to(equal(56))
        }
      }
    }
  }
}
