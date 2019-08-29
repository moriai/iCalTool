//
//  main.swift
//  iCalTool
//
//  Created by Satoshi Moriai on 1/2/2018.
//  Copyright © 2018 Satoshi Moriai. All rights reserved.
//

import Foundation
import EventKit

var logLevel: Int = 0

func dprint(_ level:Int, _ items: Any..., separator: String = " ", terminator: String = "\n") {
    if level <= logLevel {
        for item in items {
            print(item, separator:separator, terminator:terminator)
        }
    }
}

extension EKEventStore {
    // For performance reasons, gathers only those events within a four year time span.
    func events(calendars: [EKCalendar]?, withStart: Date, end: Date) -> [EKEvent]? {
        let predicate = self.predicateForEvents(withStart: withStart, end: end,
                                                calendars: calendars)
        return self.events(matching: predicate)
    }

    func add(event: EKEvent) {
        do {
            try self.save(event, span: .thisEvent, commit: true)
        }
        catch let error {
            print("Save failure: \(error.localizedDescription)")
        }
    }

    func delete(eventUID: String) {
        if let event = self.event(withIdentifier: eventUID) {
            do {
                try self.remove(event, span: .thisEvent, commit: true)
            }
            catch let error {
                print("Remove failure: \(error.localizedDescription)")
            }
        } else {
            print("No such event: \"\(eventUID)\"")
        }
    }

    func delete(event: EKEvent) {
        do {
            try self.remove(event, span: .thisEvent, commit: true)
        }
        catch let error {
            print("Remove failure: \(error.localizedDescription)")
        }
    }

    func calendar(withName name: String) -> EKCalendar? {
        if name == "" || name == "." {
            return self.defaultCalendarForNewEvents
        }
        for cal in self.calendars(for: .event) {
            if cal.title == name {
                return self.calendar(withIdentifier: cal.calendarIdentifier)
            }
        }
        return nil
    }
}

extension EKEvent {
    convenience init?(eventStore: EKEventStore, from data: [String]) {
        if data.count <= 11 {
            dprint(0, "\(data)\n^ insufficient data -- ignored!")
            return nil
        }
        guard let calendar = eventStore.calendar(withName: data[0]) else {
            dprint(1, "\(data)\n^ unknown calendar name -- ignored!")
            return nil
        }
        let title = data[1]
        if title == "" {
            dprint(0, "\(data)\n^ no tile -- ignored!")
            return nil
        }
        guard let startDate = dateFormatter.xdate(from: data[2]) else {
            dprint(0, "\(data)\n^ illegal date format -- ignored!")
            return nil
        }
        guard let endDate = dateFormatter.xdate(from: data[3]) else {
            dprint(0, "\(data)\n^ illegal date format -- ignored!")
            return nil
        }

        self.init(eventStore: eventStore)
        self.calendar = calendar
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = data[4].bool()
        self.location = data[5]
        self.notes = data[10]
    }
}

extension Bool {
    func string() -> String {
        return self ? "TRUE" : "FALSE"
    }
}

extension String {
    func bool() -> Bool {
        return self == "true" || self == "TRUE" || self == "True"
    }

    func escapeDQuote() -> String {
        return self.replacingOccurrences(of: "\"", with: "\"\"")
    }
}

extension Optional where Wrapped == String {
    func escapeDQuote() -> String {
        return self?.escapeDQuote() ?? ""
    }
}

extension DateFormatter {
    func xdate(from string: String) -> Date? {
        let formats: [String] = [
            "yyyy/MM/dd",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd HH:mm:ss"
        ]
        self.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            self.dateFormat = format
            if let date = self.date(from: string) {
                return date
            }
        }
        return nil
    }
}

let dateFormatter = DateFormatter()
extension Date {
    func string() -> String {
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        return dateFormatter.string(from: self)
    }
}

extension Optional where Wrapped == Date {
    func string() -> String {
        return self?.string() ?? "(nil)"
    }
}

enum EKStringOption {
    case longFormat, onlyUUID, defaultFormat
}

extension EKEvent {
    func string(_ option: EKStringOption = .defaultFormat) -> String {
        let title = self.title.escapeDQuote()
        let location = self.location.escapeDQuote()
        switch option {
            case .longFormat:
                let notes = self.notes.escapeDQuote()
                return "\"\(title)\",\"\(self.startDate.string())\",\"\(self.endDate.string())\",\"\(self.isAllDay.string())\",\"\(location)\",\"\(notes)\",\"\(self.calendarItemIdentifier)\""
            case .onlyUUID:
                return "\(self.calendarItemIdentifier)"
            default:
                return "\"\(title)\",\"\(self.startDate.string())\",\"\(self.endDate.string())\",\"\(self.isAllDay.string())\",\"\(location)\",\"\(self.calendarItemIdentifier)\""
        }
    }
}

extension EKCalendar {
    func string(_ option: EKStringOption = .defaultFormat) -> String {
        switch option {
        case .longFormat:
            return "\(calendarIdentifier),\"\(title)\""
        case .onlyUUID:
            return "\(calendarIdentifier)"
        default:
            return "\"\(title)\""
        }
    }
}

enum CalendarOps {
    case List, AddEvent, DeleteEvent, Sync, Diff, Describe, DoIt
}

var argv = ArraySlice(CommandLine.arguments)
let commandName = argv.removeFirst()
let usage = """
        iCalTool \(version)
        The macOS Calendar manipulation tool

        Usage: \(commandName) [Flag] <Subcommand> ...

        Flags:
            -v  Enable verbose output
            -s  Enable silent output
            -h  Print help message

        Subcommands:
            list[n|i] [calendar-name [start-date [end-date]]]
            add [csv-file|-]
            sync (csv-file|-) [start-date [end-date]]
            diff (csv-file|-) [start-date [end-date]]
            desc[n] [uuid]...
            delete [uuid]...
            help

        """

if argv.first != nil {
    switch argv.first! {
        case "-v": logLevel += 1; argv.removeFirst()
        case "-vv", "-d": logLevel += 2; argv.removeFirst()
        case "-s": logLevel -= 1; argv.removeFirst()
        case "-h": print(usage); exit(0)
        default: break
    }
}

guard let opString = argv.popFirst() else {
    print(usage)
    exit(1)
}

var op: CalendarOps = .DoIt
var printOption: EKStringOption = .defaultFormat
switch opString {
    case "list":    op = .List
    case "listn":   op = .List; printOption = .longFormat
    case "listi":   op = .List; printOption = .onlyUUID
    case "add":     op = .AddEvent
    case "sync":    op = .Sync
    case "diff":    op = .Diff
    case "desc":    op = .Describe
    case "descn":   op = .Describe; printOption = .longFormat
    case "delete":  op = .DeleteEvent
    case "help":    print(usage); exit(0)
    default:        print("\(opString): unknown command"); exit(1)
}

let eventStore = EKEventStore()
eventStore.requestAccess(to: .event,
        completion: {(granted, error) in
            if !granted {
                print("Access denied!")
                exit(1)
            }
        }
)

if op == .List {
    if argv.count == 0 {
        for calendar in eventStore.calendars(for: .event) {
            print(calendar.string(printOption), (calendar == eventStore.defaultCalendarForNewEvents ? ",*" : ""), separator: "")
        }

    } else {
        let calendarName = argv.removeFirst()

        guard let calendar = eventStore.calendar(withName: calendarName) else {
            print("Unknown calendar: \"\(calendarName)\"")
            exit(1)
        }

        let currentDate = Date()
        var startDate = currentDate.addingTimeInterval(-86400*(365*3+1))
        if argv.count >= 1 {
            startDate = dateFormatter.xdate(from: argv.removeFirst())!
        }
        var endDate = startDate.addingTimeInterval(86400*(365*4+1))
        if argv.count >= 1 {
            endDate = dateFormatter.xdate(from: argv.removeFirst())!
        }
        dprint(0, "List events from \(startDate.string()) to \(endDate.string())")

        let events: [EKEvent]? = eventStore.events(calendars: [calendar], withStart: startDate, end: endDate)
        if let _events = events {
            dprint(0, "\(_events.count) event(s) in calendar \"\(calendarName)\"")
            for event in _events {
                print(event.string(printOption))
            }
        }
    }

} else if op == .AddEvent {
    var path = "-"
    if argv.count >= 1 {
        path = argv.removeFirst()
    }

    do {
        let csv = try CSVtokenizer(contentsOfFile: path, encoding: String.Encoding.shiftJIS)
        while let data = try csv.getLine() {
            if let event = EKEvent(eventStore: eventStore, from: data) {
                dprint(0, "new event: \(event.calendarItemIdentifier)")
                eventStore.add(event: event)
            }
        }
    } catch let error as CSVtokenizerError {
        print("\(path): \(error.rawValue)")
        exit(1)
    } catch {
        print(error)
        exit(1)
    }

} else if op == .Sync || op == .Diff {
    guard let path = argv.popFirst() else {
        print("insufficient argments")
        exit(1)
    }
    var startDate: Date? = nil
    if argv.count >= 1 {
        startDate = dateFormatter.xdate(from: argv.removeFirst())!
    }
    var endDate: Date? = nil
    if argv.count >= 1 {
        endDate = dateFormatter.xdate(from: argv.removeFirst())!
    }

    let eventSource = EventCache()
    var targetCalendars = Set<EKCalendar>()
    var minDate: Date? = nil
    var maxDate: Date? = nil
    do {
        let csv = try CSVtokenizer(contentsOfFile: path, encoding: String.Encoding.shiftJIS)
        while let data = try csv.getLine() {
            if let event = EKEvent(eventStore: eventStore, from: data) {
                if (startDate == nil || event.startDate >= startDate!)
                    && (endDate == nil || event.endDate < endDate!) {
                    eventSource.add(event: event)
                    targetCalendars.insert(event.calendar)
                    if minDate == nil || event.startDate < minDate! {
                        minDate = event.startDate
                    }
                    if maxDate == nil || event.endDate > maxDate! {
                        maxDate = event.endDate
                    }
                }
            }
        }
    } catch let error as CSVtokenizerError {
        print("\(path): \(error.rawValue)")
        exit(1)
    } catch {
        print(error)
        exit(1)
    }

    if startDate == nil {
        startDate = minDate
    }
    if endDate == nil {
        endDate = maxDate
    }

    if op == .Diff {
        dprint(0, "Diff calendar ", terminator: "")
    } else {
        dprint(0, "Sync calendar ", terminator: "")
    }
    for calendar in targetCalendars {
        dprint(0, "\"\(calendar.title)\" ", terminator: "")
    }
    dprint(0, "\n with \(path) between \(minDate.string()) and \(maxDate.string())")

    var unchanged = 0
    var removed = 0
    var added = 0
    let events: [EKEvent]? = eventStore.events(calendars: Array(targetCalendars), withStart: startDate!, end: endDate!)
    if let _events = events {
        dprint(0, "\(_events.count) event(s) in target calendar(s)")
        for event in _events {
            if !targetCalendars.contains(event.calendar) {
                continue
            }
            if eventSource.delete(event: event) {
                unchanged += 1
                dprint(1, "same event: \(event.calendarItemIdentifier)")
            } else {
                if op == .Sync {
                    eventStore.delete(event: event)
                }
                removed += 1
                dprint(1, "removed event: \(event.calendarItemIdentifier)")
            }
        }
    }

    for event in eventSource.events() {
        if op == .Sync {
            eventStore.add(event: event)
        }
        added += 1
        dprint(1, "new event: \(event.calendarItemIdentifier)")
    }

    dprint(0, "\(unchanged) unchanged, \(added) added, \(removed) removed")

} else if op == .Describe {
    for id in argv {
        if let event = eventStore.event(withIdentifier: id) {
            print(event.string(printOption))
        } else if let calendar = eventStore.calendar(withIdentifier: id) {
            print(calendar.string(printOption))
        } else {
            print("No such event or calendar: \(id)")
        }
    }

} else if op == .DeleteEvent {
    for id in argv {
        eventStore.delete(eventUID: id)
    }

}
