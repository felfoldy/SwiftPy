//
//  pocketpy_extensions.c
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

#include "pocketpy_extensions.h"
#include "pocketpy.h"

bool py_throw(py_Type type, const char *message) {
    return py_exception(type, "%s", message);
}
