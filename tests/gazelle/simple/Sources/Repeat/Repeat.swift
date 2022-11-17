// This file is based upon the Repeat example in apple/swift-argument-parser.
// https://github.com/apple/swift-argument-parser/blob/main/Examples/repeat/Repeat.swift
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//

import ArgumentParser

@main
struct Repeat: ParsableCommand {
    @Option(help: "The number of times to repeat 'phrase'.")
    var count: Int?

    @Flag(help: "Include a counter with each repetition.")
    var includeCounter = false

    @Argument(help: "The phrase to repeat.")
    var phrase: String

    mutating func run() throws {
        let repeatCount = count ?? 2

        for idx in 1 ... repeatCount {
            if includeCounter {
                print("\(idx): \(phrase)")
            } else {
                print(phrase)
            }
        }
    }
}
