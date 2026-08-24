//
//  MemberExtractors.swift
//  SwiftPy
//

import SwiftSyntax
import SwiftSyntaxMacros
import Foundation

protocol MemberExtractor {
    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata)
}

struct InitializerExtractor: MemberExtractor {
    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata) {
        let initializers = members
            .compactMap { $0.as(InitializerDeclSyntax.self) }
            .filter(\.modifiers.isVisibleForPython)

        guard !initializers.isEmpty else {
            return
        }

        for initializer in initializers {
            let parameters = initializer.signature.parameterClause.parameters

            let swiftParameterLabels = parameters
                .map { parameter in
                    parameter.firstName.text + ":"
                }
                .joined()

            let swiftInitializer = "\(metadata.className).init(\(swiftParameterLabels))"
                .replacingOccurrences(of: "()", with: "")

            let paramsString = PythonSignatureFormatStyle(
                hasSelf: true,
                convertsToSnakeCase: metadata.convertsToSnakeCase
            )
            .format(initializer.signature)

            let pySignature = "__init__(\(paramsString)) -> None"
            let docstring = initializer.description.docstring

            // Bound to the initializer as well as written into the stub, so
            // that `help()` can read it the way it reads a method's.
            let boundDocstring = docstring.map { ", " + $0.asSwiftLiteral } ?? ""

            metadata.bindings.append(
            """
            type.function("\(pySignature)"\(boundDocstring)) {
                __init__($1, \(swiftInitializer))
            }
            """
            )

            metadata.initSyntax.append("@overload")

            let initSyntax = "def \(pySignature):"

            if let docstring {
                metadata.initSyntax.append(initSyntax)
                metadata.initSyntax.append(.tab + docstring.inPythonTrippleQuotes)
                metadata.initSyntax.append("")
            } else {
                metadata.initSyntax.append(initSyntax + " ...")
            }
        }
    }
}

struct VariableExtractor: MemberExtractor {
    let context: any MacroExpansionContext

    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata) {
        let variables = members
            .compactMap { $0.as(VariableDeclSyntax.self) }
            .filter(\.modifiers.isVisibleForPython)

        for variable in variables {
            extract(variable, metadata: &metadata)
        }
    }

    private func extract(
        _ variable: VariableDeclSyntax,
        metadata: inout ClassMetadata
    ) {
        let specifier = variable.bindingSpecifier.text

        guard let binding = variable.bindings.first else {
            context.warning(variable, "Unable to read binding")
            return
        }

        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            context.warning(variable, "Unable to read pattern")
            return
        }

        let identifier = pattern.identifier.text

        let pythonIdentifier = metadata.identifier(identifier)

        if let docstring = variable.description.docstring {
            metadata.variableDocs.append("\(pythonIdentifier): \(docstring)")
        }

        if let annotation = binding.typeAnnotation?.type.description {
            metadata.variableSyntax.append("\(pythonIdentifier): \(annotation.singleLine.pyType)")
        }

        // Bind static property.
        if variable.modifiers.isStatic {
            metadata.bindings.append(
                "PyObject(type).\(pythonIdentifier) = \(identifier)"
            )
            return
        }

        let setter: String = {
            if specifier != "var" {
                return "nil"
            }

            // { computed }
            if let accessors = binding.accessorBlock?.accessors,
               accessors.is(CodeBlockItemListSyntax.self) {
                return "nil"
            }

            return "{ _bind_setter(\\.\(identifier), $1) }"
        }()

        metadata.bindings.append(
        """
        type.property(
            "\(pythonIdentifier)",
            getter: { _bind_getter(\\.\(identifier), $1) },
            setter: \(setter)
        )
        """
        )
    }
}

struct FunctionExtractor: MemberExtractor {
    let context: any MacroExpansionContext

    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata) {
        let functions = members
            .compactMap { $0.as(FunctionDeclSyntax.self) }
            .filter(\.modifiers.isVisibleForPython)

        for function in functions {
            extract(function, metadata: &metadata)
        }
    }

    private func extract(
        _ function: FunctionDeclSyntax,
        metadata: inout ClassMetadata
    ) {
        let identifier = function.name.text
        let isStatic = function.modifiers.isStatic
        let signature = function.signature

        let paramsString = PythonSignatureFormatStyle(
            hasSelf: !isStatic,
            convertsToSnakeCase: metadata.convertsToSnakeCase
        )
        .format(signature)

        let returnType = signature.returnClause?.type.description.singleLine.pyType ?? "None"
        let pythonIdentifier = metadata.identifier(identifier)
        let pySignature = "\(pythonIdentifier)(\(paramsString)) -> \(returnType)".singleLine

        if isStatic {
            metadata.functionSyntax.append("@staticmethod")
        }

        let isAsync = signature.effectSpecifiers?.asyncSpecifier != nil
        let functionSyntax = isAsync
            ? "async def \(pySignature):"
            : "def \(pySignature):"

        let docstring = function.description.docstring

        if let docstring {
            metadata.functionSyntax.append(functionSyntax)
            metadata.functionSyntax.append(.tab + docstring.inPythonTrippleQuotes)
            metadata.functionSyntax.append("")
        } else {
            metadata.functionSyntax.append(functionSyntax + " ...")
        }

        let labels = signature.parameterClause.parameters
            .map { "\($0.firstName.text):" }
            .joined()
        let swiftReference = labels.isEmpty ? identifier : "\(identifier)(\(labels))"

        // Bound to the method as well as written into the stub, so that `help()`
        // can read it from the method the way it reads a module's functions.
        let boundDocstring = docstring.map { ", " + $0.asSwiftLiteral } ?? ""

        if isStatic {
            metadata.bindings.append(
            """
            type.staticmethod("\(pySignature)"\(boundDocstring)) { argc, argv in
                PyBind.function(argc, argv, \(swiftReference))
            }
            """
            )
        } else {
            metadata.bindings.append(
            """
            type.function("\(pySignature)"\(boundDocstring)) {
                _bind_function($1, \(swiftReference))
            }
            """
            )
        }
    }
}
