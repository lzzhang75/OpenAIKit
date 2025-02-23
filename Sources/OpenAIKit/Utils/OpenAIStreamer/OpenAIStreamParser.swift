//
//  OpenAIStreamParser.swift
//  OpenAIKit
//
//  Copyright (c) 2023 MarcoDotIO
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

#if os(Linux) || SERVER
import FoundationNetworking
#endif

public final class OpenAIStreamParser {
    //  Events are separated by end of line. End of line can be:
    //  \r = CR (Carriage Return) → Used as a new line character in Mac OS before X
    //  \n = LF (Line Feed) → Used as a new line character in Unix/Mac OS X
    //  \r\n = CR + LF → Used as a new line character in Windows
    private let validNewlineCharacters = ["\r\n", "\n", "\r"]
    private let dataBuffer: NSMutableData

    init() {
        dataBuffer = NSMutableData()
    }

    var currentBuffer: String? {
        return NSString(data: dataBuffer as Data, encoding: String.Encoding.utf8.rawValue) as String?
    }

    func append(data: Data?) -> [OpenAIEvent] {
        guard let data = data else { return [] }
        dataBuffer.append(data)

        let events = extractEventsFromBuffer().compactMap { [weak self] eventString -> OpenAIEvent? in
            guard let self = self else { return nil }
            return OpenAIEvent(eventString: eventString, newLineCharacters: self.validNewlineCharacters)
        }

        return events
    }

    private func extractEventsFromBuffer() -> [String] {
        var events = [String]()

        var searchRange =  NSRange(location: 0, length: dataBuffer.length)
        while let foundRange = searchFirstEventDelimiter(in: searchRange) {
            // if we found a delimiter range that means that from the beggining of the buffer
            // until the beggining of the range where the delimiter was found we have an event.
            // The beggining of the event is: searchRange.location
            // The lenght of the event is the position where the foundRange was found.
            let dataChunk = dataBuffer.subdata(
                with: NSRange(location: searchRange.location, length: foundRange.location - searchRange.location)
            )

            if let text = String(bytes: dataChunk, encoding: .utf8) {
                events.append(text)
            }

            // We move the searchRange start position (location) after the fundRange we just found and
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = dataBuffer.length - searchRange.location
        }

        // We empty the piece of the buffer we just search in.
        dataBuffer.replaceBytes(in: NSRange(location: 0, length: searchRange.location), withBytes: nil, length: 0)

        return events
    }

    // This methods returns the range of the first delimiter found in the buffer. For example:
    // If in the buffer we have: `id: event-id-1\ndata:event-data-first\n\n`
    // This method will return the range for the `\n\n`.
    private func searchFirstEventDelimiter(in range: NSRange) -> NSRange? {
        let delimiters = validNewlineCharacters.map { "\($0)\($0)".data(using: String.Encoding.utf8)! }

        for delimiter in delimiters {
            let foundRange = dataBuffer.range(
                of: delimiter, options: NSData.SearchOptions(), in: range
            )

            if foundRange.location != NSNotFound {
                return foundRange
            }
        }

        return nil
    }
}
