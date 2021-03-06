// Sources/SwiftProtobuf/JSONEncoder.swift - JSON Encoding support
//
// Copyright (c) 2014 - 2016 Apple Inc. and the project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE.txt for license information:
// https://github.com/apple/swift-protobuf/blob/master/LICENSE.txt
//
// -----------------------------------------------------------------------------
///
/// JSON serialization engine.
///
// -----------------------------------------------------------------------------

import Foundation

public struct JSONEncoder {
    fileprivate var json: [String] = []
    private var separator: String = ""
    public init() {}
    public var result: String { return json.joined(separator: "") }

    mutating func append(text: String) {
        json.append(text)
    }
    mutating func appendTokens(tokens: [JSONToken]) {
        for t in tokens {
            switch t {
            case .beginArray: append(text: "[")
            case .beginObject: append(text: "{")
            case .boolean(let v):
                // Note that quoted boolean map keys get stored as .string()
                putBoolValue(value: v, quote: false)
            case .colon: append(text: ":")
            case .comma: append(text: ",")
            case .endArray: append(text: "]")
            case .endObject: append(text: "}")
            case .null: putNullValue()
            case .number(.double(let v)): append(text: String(v))
            case .number(.int(let v)): append(text: String(v))
            case .number(.uint(let v)): append(text: String(v))
            case .string(let v): putStringValue(value: v)
            }
        }
    }
    mutating func startField(name: String) {
        append(text: separator + "\"" + name + "\":")
        separator = ","
    }
    public mutating func startObject() {
        append(text: "{")
        separator = ""
    }
    public mutating func endObject() {
        append(text: "}")
        separator = ","
    }
    mutating func putNullValue() {
        append(text: "null")
    }
    mutating func putFloatValue(value: Float, quote: Bool) {
        putDoubleValue(value: Double(value), quote: quote)
    }
    mutating func putDoubleValue(value: Double, quote: Bool) {
        if value.isNaN {
            append(text: "\"NaN\"")
        } else if !value.isFinite {
            if value < 0 {
                append(text: "\"-Infinity\"")
            } else {
                append(text: "\"Infinity\"")
            }
        } else {
            // TODO: Be smarter here about choosing significant digits
            // See: protoc source has C++ code for this with interesting ideas
            let s: String
            if value < Double(Int64.max) && value > Double(Int64.min) && value == Double(Int64(value)) {
                s = String(Int64(value))
            } else {
                s = String(value)
            }
            if quote {
                append(text: "\"" + s + "\"")
            } else {
                append(text: s)
            }
        }
    }
    mutating func putInt64(value: Int64, quote: Bool) {
        // Always quote integers with abs value > 2^53
        if quote || value > 0x1FFFFFFFFFFFFF || value < -0x1FFFFFFFFFFFFF {
            append(text: "\"" + String(value) + "\"")
        } else {
            append(text: String(value))
        }
    }
    mutating func putUInt64(value: UInt64, quote: Bool) {
        if quote || value > 0x1FFFFFFFFFFFFF { // 2^53 - 1
            append(text: "\"" + String(value) + "\"")
        } else {
            append(text: String(value))
        }
    }

    mutating func putBoolValue(value: Bool, quote: Bool) {
        if quote {
            append(text: value ? "\"true\"" : "\"false\"")
        } else {
            append(text: value ? "true" : "false")
        }
    }
    mutating func putStringValue(value: String) {
        let hexDigits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"];
        append(text: "\"")
        for c in value.unicodeScalars {
            switch c.value {
            // Special two-byte escapes
            case 8: append(text: "\\b")
            case 9: append(text: "\\t")
            case 10: append(text: "\\n")
            case 12: append(text: "\\f")
            case 13: append(text: "\\r")
            case 34: append(text: "\\\"")
            case 92: append(text: "\\\\")
            case 0...31, 127...159: // Hex form for C0 and C1 control chars
                let digit1 = hexDigits[Int(c.value / 16)]
                let digit2 = hexDigits[Int(c.value & 15)]
                append(text: "\\u00\(digit1)\(digit2)")
            case 0...127:  // ASCII
                append(text: String(c))
            default: // Non-ASCII
                append(text: String(c))
            }
        }
        append(text: "\"")
    }
    mutating func putBytesValue(value: Data) {
        var out: String = ""
        if value.count > 0 {
            let digits: [Character] = ["A", "B", "C", "D", "E", "F",
            "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q",
            "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b",
            "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
            "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x",
            "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8",
            "9", "+", "/"]
            var t: Int = 0
            for (i,v) in value.enumerated() {
                if i > 0 && i % 3 == 0 {
                    out.append(digits[(t >> 18) & 63])
                    out.append(digits[(t >> 12) & 63])
                    out.append(digits[(t >> 6) & 63])
                    out.append(digits[t & 63])
                    t = 0
                }
                t <<= 8
                t += Int(v)
            }
            switch value.count % 3 {
            case 0:
                out.append(digits[(t >> 18) & 63])
                out.append(digits[(t >> 12) & 63])
                out.append(digits[(t >> 6) & 63])
                out.append(digits[t & 63])
            case 1:
                t <<= 16
                out.append(digits[(t >> 18) & 63])
                out.append(digits[(t >> 12) & 63])
                out.append(Character("="))
                out.append(Character("="))
            default:
                t <<= 8
                out.append(digits[(t >> 18) & 63])
                out.append(digits[(t >> 12) & 63])
                out.append(digits[(t >> 6) & 63])
                out.append(Character("="))
            }
        }
        append(text: "\"" + out + "\"")
    }
}

