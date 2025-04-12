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
    
    public required init(_ value: Value?) {
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
