//
//  ConversionTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-26.
//

import SwiftPy
import Testing
import Foundation

@MainActor
struct ConversionTests {
    @Test func dataToPython() {
        py.main.test_bytes = "Hello".data(using: .utf8)
        #expect(Interpreter.evaluate("test_bytes.decode()") == "Hello")
    }
    
    @Test func floatCastFromInt() throws {
        Interpreter.run("floatCastFromInt = 3")
        let value = py.main.floatCastFromInt
        let number = try Float.cast(value?.reference)
        #expect(number == 3.0)
    }
    
    @Test func dataFromPython() throws {
        let data: Data = try #require(Interpreter.evaluate("b'test'"))
        
        #expect(String(data: data, encoding: .utf8) == "test")
    }
    
    @Test func strArrayToPython() {
        let array: [String] = ["Hello", "World"]
        
        Interpreter.run("x = []")
        py.main.x = array
        
        #expect(py.main.x == ["Hello", "World"])
    }
    
    @Test func dictionaryToPython() {
        let dictionary: [String: Any] = ["Hello": 1, "World": Int64(2)]
        
        py.main.dictionary = dictionary
        
        #expect(Interpreter.evaluate(#"dictionary["Hello"]"#) == 1)
        #expect(Interpreter.evaluate(#"dictionary["World"]"#) == 2)
    }

    @Test func dictionaryFromPython() throws {
        Interpreter.run(#"dictionary = {"topic": "dict", "task": "iterate"}"#)
        
        let result: [String: String] = try #require(py.main.dictionary)
        
        #expect(result["topic"] == "dict")
        #expect(result["task"] == "iterate")
    }
    
    @Test func jsonDictionaryFromPython() throws {
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
        
        #expect(py.main.dictionary?["string"] == "hello")
        #expect(py.main.dictionary?["integer"] == 42)

        let dictionary: [String: Any] = try #require(py.main.dictionary)
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

        // This fails?
        //#expect(main.dictionary?["object"]?["nestedKey"] == "nestedValue")
    }
    
    static var casted: Double?
    
    @Test func castFloatFromInt() {        
        py.main.def("will_cast(x: float) -> None") { argc, argv in
            PyBind.function(argc, argv) { (x: Double) in
                ConversionTests.casted = x
            }
        }
        
        Interpreter.run("will_cast(42)")
        
        #expect(ConversionTests.casted == 42)
    }
}
