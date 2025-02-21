//
//  PythonValueBindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-21.
//

open class PythonValueReference<Value> {
    public private(set) var get: () -> Value? = { nil }
    public private(set) var set: ((Value?) -> Void)?
    
    public var value: Value? {
        get { get() }
        set { set?(newValue) }
    }
    
    private var storedValue: Value?

    public var _pythonCache = PythonBindingCache()

    public init(get: @escaping () -> Value?, set: ((Value?) -> Void)? = nil) {
        self.get = get
        self.set = set
    }
    
    public init(_ value: Value?) {
        self.storedValue = value
        self.get = { [unowned self] in storedValue }
        self.set = { [unowned self] in storedValue = $0 }
    }
    
    public init<Root: PythonBindable>(_ object: Root?, _ path: KeyPath<Root, Value>) {
        get = { [weak object] in
            object?[keyPath: path]
        }
        
        if let writablePath = path as? WritableKeyPath<Root, Value> {
            set = { [weak object] newValue in
                if let newValue {
                    object?[keyPath: writablePath] = newValue
                }
            }
        }
    }
}

public typealias PythonValueBindable<Value> = PythonValueReference<Value> & PythonBindable

public extension PythonBindable {
    /// Stores the binding in the `_pythonCache`.
    ///
    /// Useful for storing wrapper classes without recreating them.
    ///
    /// - Parameters:
    ///   - key: key.
    ///   - makeBinding: Creates the binding, will only be called if the cache is empty.
    /// - Returns: `true` indicating no errors were thrown.
    @inlinable func _cached(_ key: String, makeBinding: () -> PythonBindable) -> Bool {
        if let cached = _pythonCache.bindings[key] {
            return PyAPI.return(cached)
        }
        let binding = makeBinding()
        _pythonCache.bindings[key] = binding
        return PyAPI.return(binding)
    }
}
