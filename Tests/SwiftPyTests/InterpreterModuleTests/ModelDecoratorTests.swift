//
//  ModelDecoratorTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-19.
//

@testable import SwiftPy
import Testing
import Foundation

/// Exercises the `@model` decorator from `modeling.py`: field defaults,
/// initialization, optionals, `list` fields, `__repr__`, mutation tracking,
/// and argument validation.
@MainActor
@Suite(.serialized)
struct ModelDecoratorTests {
    init() async {
        await Interpreter.run("""
        from modeling import model
        import json

        @model
        class Item:
            name: str = ''
            quantity: int = 0
            tags: list[str] = []
            description: str | None

        @model
        class Required:
            value: int
        """)
    }

    @Test func appliesDefaults() async {
        await Interpreter.run("item = Item()")
        #expect(Interpreter.evaluate("item.name") == "")
        #expect(Interpreter.evaluate("item.quantity") == 0)
        #expect(Interpreter.evaluate("item.tags") == [String]())
        // Optional field without a default becomes None.
        #expect(Interpreter.evaluate("item.description is None") == true)
    }

    @Test func keywordInit() async {
        await Interpreter.run("item = Item(name='Sword', quantity=2)")
        #expect(Interpreter.evaluate("item.name") == "Sword")
        #expect(Interpreter.evaluate("item.quantity") == 2)
    }

    @Test func positionalInit() async {
        await Interpreter.run("item = Item('Sword', 3)")
        #expect(Interpreter.evaluate("item.name") == "Sword")
        #expect(Interpreter.evaluate("item.quantity") == 3)
    }

    @Test func listField() async {
        await Interpreter.run("""
        item = Item()
        item.tags = item.tags + ['a', 'b']
        """)
        #expect(Interpreter.evaluate("item.tags") == ["a", "b"])
        #expect(Interpreter.evaluate("type(item.tags).__name__") == "list")
    }

    @Test func annotationsPreserveElementType() async {
        // The parametrized element type is retained on the annotation.
        #expect(Interpreter.evaluate("Item.__annotations__['tags']") == "list[str]")
    }

    @Test func schemaReflectsFieldsAndTypes() async {
        let schema: String? = Interpreter.evaluate("json.dumps(Item._schema)")
        #expect(schema == #"{"name": "Item", "properties": [{"name": "name", "type": "str", "default": ""}, {"name": "quantity", "type": "int", "default": 0}, {"name": "tags", "type": "list[str]", "default": []}, {"name": "description", "type": "str | None"}]}"#)
    }

    @Test func schemaOmitsDefaultForFieldsWithoutOne() async {
        // `description` has no default, so its schema entry has no 'default' key,
        // while `name` (which has one) does.
        #expect(Interpreter.evaluate("'default' in Item._schema['properties'][0]") == true)
        #expect(Interpreter.evaluate("'default' in Item._schema['properties'][3]") == false)
    }

    @Test func repr() async {
        await Interpreter.run("item = Item(name='Sword')")
        #expect(
            Interpreter.evaluate("repr(item)")
                == "Item(name='Sword', quantity=0, tags=[], description=None)"
        )
    }

    @Test func setterUpdatesFields() async {
        await Interpreter.run("""
        item = Item()
        item.quantity = 5
        """)
        #expect(Interpreter.evaluate("item._fields['quantity']") == 5)
    }

    @Test func missingRequiredArgumentRaises() async {
        await Interpreter.run("""
        def _raises():
            try:
                Required()
                return False
            except TypeError:
                return True
        """)
        #expect(Interpreter.evaluate("_raises()") == true)
    }

    @Test func unexpectedKeywordRaises() async {
        await Interpreter.run("""
        def _raises():
            try:
                Item(color='red')
                return False
            except TypeError:
                return True
        """)
        #expect(Interpreter.evaluate("_raises()") == true)
    }

    @Test func tooManyPositionalArgumentsRaises() async {
        await Interpreter.run("""
        def _raises():
            try:
                Item('a', 1, [], None, 'extra')
                return False
            except TypeError:
                return True
        """)
        #expect(Interpreter.evaluate("_raises()") == true)
    }
}
