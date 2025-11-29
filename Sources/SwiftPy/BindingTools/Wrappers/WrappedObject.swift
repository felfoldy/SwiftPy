//
//  WrappedObject.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-11-29.
//

import Foundation

open class WrappedObject<Value>: CustomStringConvertible {
    /// Attribute binder.
    @propertyWrapper
    public struct Attribute<ProxyValue> {
        @available(*, unavailable, message: "@ValueProxy can only be applied to classes")
        public var wrappedValue: ProxyValue {
            get { fatalError() }
            set { fatalError() }
        }
        
        let path: KeyPath<Value, ProxyValue>
        
        public init(_ path: KeyPath<Value, ProxyValue>) {
            self.path = path
        }
        
        public static subscript<P>(
            _enclosingInstance instance: P,
            wrapped wrappedKeyPath: KeyPath<P, ProxyValue>,
            storage storageKeyPath: ReferenceWritableKeyPath<P, Self>
        ) -> ProxyValue where P: WrappedObject<Value> {
            get {
                let storage = instance[keyPath: storageKeyPath]
                return instance.value[keyPath: storage.path]
            }
            set {
                let storage = instance[keyPath: storageKeyPath]
                if let path = storage.path as? ReferenceWritableKeyPath {
                    instance.value[keyPath: path] = newValue
                }
            }
        }
    }
    
    public var value: Value
    
    public init(_ value: Value) {
        self.value = value
    }
    
    public var description: String {
        String(describing: value)
    }
}
