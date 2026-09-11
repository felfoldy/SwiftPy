//
//  PocketPyModule.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-11.
//

public extension PyAPI {
    /// Creates `_pocketpy`: what pocketpy lacks against CPython, written in
    /// Python. Its presence is how shared Python code tells the backends
    /// apart -- under CPython the import fails and the builtin stays.
    func installPocketPyModule() {
        let module = newmodule("_pocketpy")
        _ = try? exec(source: Self.pocketPySource, filename: "<_pocketpy>", mode: .execution, module: module)
    }

    private static let pocketPySource = """
    def dir(obj) -> list[str]:
        # pocketpy's builtin dir misses inherited members, so walk the MRO.
        if hasattr(obj, '__dir__') and not isinstance(obj, type):
            return obj.__dir__()

        tp_module = type(__import__('math'))
        if isinstance(obj, tp_module):
            return [k for k, _ in obj.__dict__.items()]
        names = set()
        if not isinstance(obj, type):
            obj_d = obj.__dict__
            if obj_d is not None:
                names.update([k for k, _ in obj_d.items()])
            cls = type(obj)
        else:
            cls = obj
        while cls is not None:
            names.update([k for k, _ in cls.__dict__.items()])
            cls = cls.__base__
        return sorted(list(names))
    """
}
