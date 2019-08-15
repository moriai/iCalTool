//
//  csvtokenizer.swift
//  iCalTool
//
//  Created by Satoshi Moriai on 6/30/2019.
//  Copyright © 2019 Satoshi Moriai. All rights reserved.
//

import Foundation

public enum CSVtokenizerError: String, Error {
    case illegalPunctuation = "Illegal punctuation"
    case noRightDoubleQuotation = "No right double quotation"
    case cantReadFile = "Can't read file"
}

public class CSVtokenizer {
    let buffer: String
    var index: String.Index
    var debug: Bool = false

    public init(string: String) {
        buffer = string
        index = string.startIndex
    }

    public convenience init(contentsOfFile path: String, encoding enc: String.Encoding = String.Encoding.utf8) throws {
        var string: String

        if path == "-" || path == "" {
            string = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding:enc) ?? ""
        } else if FileManager().isReadableFile(atPath: path) {
            string = try String(contentsOfFile: path, encoding:enc)
        } else {
            throw CSVtokenizerError.cantReadFile
        }
        self.init(string: string)
    }

    public func getChar() -> Character? {
        var char: Character
        let crlf: Character = "\r\n"

        if index == buffer.endIndex {
            return nil
        }

        char = buffer[index]
        index = buffer.index(after: self.index)

        if debug {
            let s = String(char)
            print("getChar: \(char): ", terminator: "")
            for c in s.unicodeScalars {
                print("\(c.value) ", terminator: "")
            }
            print()
        }

        if char == crlf {
            char = "\n"
        }

        return char
    }

    public func getCell() throws -> (value: String, eol: Bool)? {
        var cellString: String = ""
        var char = getChar()

        if char == nil {
            return nil
        }

        if char == "\"" {
            while true {
                char = getChar()
                if char == "\"" {
                    char = getChar()
                    if char != "\"" {
                        break
                    }
                }
                if char == nil {
                    throw CSVtokenizerError.noRightDoubleQuotation
                }
                cellString.append(char!)
            }
        } else {
            while char != "," && char != "\n" && char != nil {
                cellString.append(char!)
                char = getChar()
            }
        }

        if char == "," {
            return (cellString, false)
        } else if char == "\n" || char == nil {
            return (cellString, true)
        }

        throw CSVtokenizerError.illegalPunctuation
    }

    public func getLine() throws -> [String]? {
        var line = [String]()
        while let cell = try getCell() {
            line += [cell.value]
            if cell.eol {
                return line
            }
        }
        return nil
    }

    public func getNamedCells(mapping: [String]) throws -> [String:String]? {
        var cells = [String:String]()
        var column = 0
        while let cell = try getCell() {
            if column < mapping.count {
                cells[mapping[column]] = cell.value
            }
            if cell.eol {
                return cells
            }
            column += 1
        }
        return nil
    }
}
