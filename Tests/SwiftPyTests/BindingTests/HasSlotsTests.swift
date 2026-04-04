//
//  HasSlotsTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-15.
//

import Testing
import SwiftPy
import pocketpy

@Scriptable
class Player {}

extension Player: HasSlots {
    enum Slot: Int32, CaseIterable {
        case health
    }
}

@MainActor
@Suite("HasSlots", .tags(.experimental))
struct HasSlotsTests {
    @Test
    func registersSlots() {
        let player = Player()
        PyObject(.main)?.player = player
        
        player[.health] = 10
        
        let ref = player._pythonCache.reference

        #expect(Player(ref)?[.health] == 10)
    }
}
