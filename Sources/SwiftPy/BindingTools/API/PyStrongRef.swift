@MainActor
private var nextID: Int32 = 0

@MainActor
private var freeSlots: [Int32] = []

@MainActor
@dynamicMemberLookup
public final class PyStrongRef {
    public let reference: PyRef
    private let cacheID: Int32
    
    public init(_ reference: PyRef) {
        let copy = PyRef.allocate(capacity: 1)
        copy.initialize(to: reference.pointee)

        if let slot = freeSlots.popLast() {
            py.list.setitem(py.objectCache, i: slot, value: copy)
            cacheID = slot
        } else {
            py.list.append(py.objectCache, value: copy)
            cacheID = nextID
            nextID += 1
        }
        self.reference = copy
        #if DEBUG
        log.trace("retain \(self.description) at: \(self.cacheID)")
        #endif
    }

    public convenience init?(_ reference: PyRef?) {
        guard let reference else { return nil }
        self.init(reference)
    }

    @MainActor deinit {
        #if DEBUG
        log.trace("release \(self.description) at: \(self.cacheID)")
        #endif
        py.list.setitem(py.objectCache, i: cacheID, value: py.None())
        reference.deinitialize(count: 1)
        reference.deallocate()
        freeSlots.append(cacheID)
    }
    
    public subscript(dynamicMember dynamicMember: String) -> PyStrongRef? {
        get {
            let attribute = Interpreter.silenceErrors {
                try py.getattr(
                    reference,
                    name: dynamicMember
                )
            }
            return PyStrongRef(attribute)
        }
        set {
            Interpreter.silenceErrors {
                try py.setattr(
                    reference,
                    name: dynamicMember,
                    value: newValue?.reference
                )
            }
        }
    }
    
    @inlinable
    public func callAsFunction(_ args: PythonConvertible?...) throws {
        try py.call(reference, args: args)
    }
    
    @inlinable
    @discardableResult
    public func callAsFunction<Value: PythonConvertible>(_ args: PythonConvertible?...) throws -> Value {
        let result = try py.call(reference, args: args)
        return try Value.cast(result)
    }
}

extension PyStrongRef: PythonConvertible, @MainActor CustomStringConvertible {
    public var description: String {
        try! py.repr(reference)
    }
    
    public func toPython(_ reference: PyAPI.Reference) {
        reference.assign(self.reference)
    }
    
    public static func fromPython(_ reference: PyAPI.Reference) -> PyStrongRef {
        PyStrongRef(reference)
    }
    
    public static let pyType = PyType.object
}

extension PyAPI {
    @inlinable
    public func retain(_ ref: PyRef?) -> PyStrongRef? {
        PyStrongRef(ref)
    }

    @inlinable
    public func retain(_ ref: PyRef) -> PyStrongRef {
        PyStrongRef(ref)
    }
    
    @inlinable
    public func retain<Value: PythonConvertible>(_ value: Value) -> PyStrongRef? {
        let tmp = py.pushtmp()
        defer { py.pop() }
        value.toPython(tmp)
        return PyStrongRef(tmp)
    }
}
