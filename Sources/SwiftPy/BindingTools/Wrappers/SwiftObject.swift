//
//  SwiftObject.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-11-29.
//

@Scriptable
public final class SwiftObject: PythonBindable {
    private var _value: Any
    
    private init(value: Any) {
        _value = value
    }
}

extension SwiftObject: @MainActor CustomStringConvertible {
    public var value: Any {
        get { _value }
        set { _value = newValue }
    }

    public convenience init(_ value: Any) {
        self.init(value: value)
    }
    
    public var description: String {
        String(describing: _value)
    }
}
