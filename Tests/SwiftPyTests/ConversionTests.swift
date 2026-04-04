//
//  ConversionTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-26.
//

import SwiftPy
import Testing
import pocketpy
import Foundation

@MainActor
struct ConversionTests {
    let profiler = profile("ConversionTests")
    let main = PyModule.main
    
    @Test func dataToPython() {
        main.test_bytes = "Hello".data(using: .utf8)
        #expect(Interpreter.evaluate("test_bytes.decode()") == "Hello")
    }
    
    @Test func floatCastFromInt() throws {
        Interpreter.run("floatCastFromInt = 3")
        let number = try Float.cast(.main["floatCastFromInt"])
        #expect(number == 3.0)
    }
    
    @Test func dataFromPython() throws {
        let data: Data = try #require(Interpreter.evaluate("b'test'"))
        
        #expect(String(data: data, encoding: .utf8) == "test")
    }
    
    @Test func strArrayToPython() {
        profiler.event("ConversionTests.strArrayToPython")
        let array: [String] = ["Hello", "World"]
        
        Interpreter.execute("x = []")
        array.toPython(Interpreter.main["x"])
        
        #expect(Interpreter.main["x"] == ["Hello", "World"])
    }
    
    @Test func dictionaryToPython() {
        profiler.event("ConversionTests.dictionaryToPython")

        let dictionary: [String: Any] = ["Hello": 1, "World": Int64(2)]
        
        dictionary.toPython(.main.emplace("dictionary"))

        #expect(Interpreter.evaluate(#"dictionary["Hello"]"#) == 1)
        #expect(Interpreter.evaluate(#"dictionary["World"]"#) == 2)
    }

    @Test func dictionaryFromPython() throws {
        profiler.event("ConversionTests.dictionaryFromPython")
        
        Interpreter.run(#"dictionary = {"topic": "dict", "task": "iterate"}"#)
        
        let result = try #require([String: String](main.dictionary))
        
        #expect(result["topic"] == "dict")
        #expect(result["task"] == "iterate")
    }
    
    @Test func jsonDictionaryFromPython() throws {
        profiler.event("ConversionTests.jsonDictionaryFromPython")
        
        Interpreter.run("""
        dictionary = {
            "string": "hello",
            "integer": 42,
            "double": 3.14,
            "boolean": True,
            "nullValue": None,
            "array": [1, "two", False, None],
            "object": {"nestedKey": "nestedValue"}
        }
        """)
        
        #expect(main.dictionary?["string"] == "hello")
        #expect(main.dictionary?["integer"] == 42)

        let dictionary = try #require([String: Any](main.dictionary))
        #expect(dictionary["string"] as? String == "hello")
        #expect(dictionary["integer"] as? Int == 42)
        #expect(dictionary["double"] as? Double == 3.14)
        #expect(dictionary["boolean"] as? Bool == true)

        let array = try #require(dictionary["array"] as? [Any?])
        try #require(array.count == 4)
        #expect(array[0] as? Int == 1)
        #expect(array[1] as? String == "two")
        #expect(array[2] as? Bool == false)
        #expect(array[3] == nil)

        //#expect(main.dictionary?["object"]?["nestedKey"] == "nestedValue")
    }
    
    static var casted: Double?
    
    @Test func castFloatFromInt() {
        profiler.event("ConversionTests.castFloatFromInt")
        
        Interpreter.main.bind("will_cast(x: float) -> None") { argc, argv in
            PyBind.function(argc, argv) { (x: Double) in
                ConversionTests.casted = x
            }
        }
        
        Interpreter.run("will_cast(42)")
        
        #expect(ConversionTests.casted == 42)
    }
}
