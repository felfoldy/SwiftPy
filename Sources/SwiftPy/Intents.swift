//
//  Intents.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-22.
//

import AppIntents

@available(macOS 13.0, iOS 16.0, *)
@MainActor
class PythonIntent: PythonBindable {
    var _pythonCache = PythonBindingCache()
    
    let signature: String
    let create: () -> any AppIntent

    init?<Intent: AppIntent>(intent: @escaping () -> Intent) {
        create = intent
        
        // Set its parameters.
        let parameters = Mirror(reflecting: intent())
            .children

        var args = [String]()
        
        for parameter in parameters {
            guard let label = parameter.label,
                  let value = parameter.value as? (any PythonIntentParameter) else {
                // Throw instead?
                return nil
            }

            args.append("\(label): \(value.type.pyType.name)")
        }
        
        signature = "(\(args.joined(separator: ", "))) -> AsyncTask"
    }
    
    static let pyType: PyType = .make("Intent", module: Interpreter.intents) { userdata in
        deinitFromPython(userdata)
    } bind: { type in
        type.magic("__call__") { argc, argv in
            guard let obj = PythonIntent(argv) else {
                return throwTypeError(argv, 0)
            }
            
            // Create an intent.
            let intent = obj.create()
            
            // Set its parameters.
            let parameters = Mirror(reflecting: intent)
                .children
            
            guard argc == parameters.count + 1 else {
                return PyAPI.throw(.TypeError, "Expected \(parameters.count) arguments.")
            }
            
            for (offset, parameter) in parameters.enumerated() {
                let argOffset = offset + 1
                let pyParam = (parameter.value as? any PythonIntentParameter)
                pyParam?.setValue(argv?[argOffset])
            }
            
            return PyAPI.return(
                AsyncTask { () async -> Void in
                    _ = try? await intent.perform()
                }
            )
        }
    }
}

protocol PythonIntentParameter<T> {
    associatedtype T: PythonConvertible
    var type: T.Type { get }
    
    @MainActor func setValue(_ value: PyAPI.Reference?)
}

@available(macOS 13.0, iOS 16.0, *)
extension IntentParameter: PythonIntentParameter where Value: PythonConvertible {
    public typealias T = Value
    
    public var type: Value.Type { Value.self }
    
    public func setValue(_ value: PyAPI.Reference?) {
        if let newValue = T(value) {
            wrappedValue = newValue
        }
    }
}

// MARK: - Interpreter + intent

@available(macOS 13.0, iOS 16.0, *)
public extension Interpreter {
    static func register<Intent: AppIntent>(_ intent: Intent.Type) {
        let intents = Interpreter.intents
                
        if intents["Intent"] == nil {
            intents.insertTypes(PythonIntent.pyType)
        }
        
        guard let intent = PythonIntent(intent: Intent.init) else {
            log.critical("Failed to register intent: \(Intent.self). Make sure all parameters are python bindable.")
            return
        }

        let identifier = intents.emplace(Intent.persistentIdentifier)
        intent.toPython(identifier)
        
        log.notice("Regiser intent: \(Intent.self)")
    }
}
