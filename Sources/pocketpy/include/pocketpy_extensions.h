//
//  pocketpy_throw.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//


#pragma once
#include "pocketpy.h"

#ifdef __cplusplus
extern "C" {
#endif

// Declaration for Swift.
bool py_throw(py_Type type, const char *message);

#ifdef __cplusplus
}
#endif
