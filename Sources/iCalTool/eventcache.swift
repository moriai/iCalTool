//
//  eventcache.swift
//  iCalTool
//
//  Created by Satoshi Moriai on 7/2/2019.
//  Copyright © 2019 Satoshi Moriai. All rights reserved.
//

import Foundation
import EventKit

class EventCache {
    var eventCache = [String: EKEvent]()

    private func makeKey(_ event: EKEvent) -> String {
        return event.calendar.title + "|" + event.title + "|"
            + event.startDate.string() + "|" + event.endDate.string() + "|"
            + event.isAllDay.string() + "|" + (event.location ?? "") + "|" + (event.notes ?? "")
    }

    func add(event: EKEvent) {
        eventCache[makeKey(event)] = event
    }

    func delete(event: EKEvent) -> Bool {
        let key = makeKey(event)
        if eventCache[key] != nil {
            eventCache[key] = nil
            return true
        } else {
            return false
        }
    }

    func events() -> [EKEvent] {
        return [EKEvent](eventCache.values)
    }
}
