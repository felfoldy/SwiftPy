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
struct HasSlotsTests {
    @Test func registersSlots() {
        let main = Interpreter.main
        let player = Player()
        player.toPython(main.emplace("player"))
        
        player[.health] = 10
        
        let ref = player._pythonCache.reference

        #expect(Player(ref)?[.health] == 10)
    }
}
