//
//  PyAPI+Watchdog.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-08-06.
//

import pocketpy

public extension PyAPI {
    /// Arms the VM watchdog.
    ///
    /// If Python code runs longer than `milliseconds` of CPU time, the
    /// interpreter raises `TimeoutError` from within its dispatch loop,
    /// aborting even a tight synchronous loop such as `while 1: pass`.
    ///
    /// Call ``endWatchdog()`` afterwards to disarm it.
    func beginWatchdog(milliseconds: Int) {
        py_watchdog_begin(py_i64(milliseconds))
    }

    /// Disarms the VM watchdog previously started with
    /// ``beginWatchdog(milliseconds:)``.
    func endWatchdog() {
        py_watchdog_end()
    }
}
