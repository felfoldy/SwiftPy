//
//  InterpreterTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-23.
//

import Testing
@testable import SwiftPy

@MainActor
struct InterpreterTests {
    @Test func loadBundleModule() {
        Interpreter.run("from rlcompleter import Completer")
        #expect(py.main.Completer != nil)
    }
    
    @Test func evaluate() {
        #expect(Interpreter.evaluate("3 + 4") == 7)
    }

    @Test func stringTitle() {
        #expect(Interpreter.evaluate("\"hello WORLD\".title()") == "Hello World")
        #expect(Interpreter.evaluate("\"they're bill's\".title()") == "They'Re Bill'S")
        #expect(Interpreter.evaluate("\"123abc foo-bar\".title()") == "123Abc Foo-Bar")
        #expect(Interpreter.evaluate("\"ßeta\".title()") == "Sseta")
        #expect(
            Interpreter.evaluate("str.title.__doc__")
                == "Return a titlecased version of the string, with each word starting with an uppercase character."
        )
    }

    @Test func stringRSplit() {
        #expect(Interpreter.evaluate("'a,b,c'.rsplit(',', 1)") == ["a,b", "c"])
        #expect(Interpreter.evaluate("'a--b--c'.rsplit('--', 1)") == ["a--b", "c"])
        #expect(Interpreter.evaluate("'a,,b,'.rsplit(',')") == ["a", "", "b", ""])
        #expect(Interpreter.evaluate("'  a  b  c  '.rsplit(None, 1)") == ["  a  b", "c"])
        #expect(Interpreter.evaluate("'  a  b  '.rsplit()") == ["a", "b"])
        #expect(Interpreter.evaluate("'a,b'.rsplit(',', 0)") == ["a,b"])
    }

    @Test func dirIsNotNone() {
        Interpreter.run("import interpreter")

        #expect(Interpreter.evaluate("dir is None") == false)
    }

    #if os(macOS)
    @Test func sysOS() throws {
        Interpreter.run("import sys")
        #expect(Interpreter.evaluate("sys.os") == "macos")
    }
    #endif

    @Test func isolatedExecuteDoesNotLeakToMain() async throws {
        let namespace = PyObject { py.newdict($0) }
        let code = try Interpreter.compile("isolated_marker = 7")

        try await Interpreter.execute(code, globals: namespace)

        #expect(py.main.isolated_marker == nil)
    }

    @Test func clearMain_removesUserDefinedVariables() {
        Interpreter.run("_test_clear_x = 42")
        #expect(Interpreter.evaluate("_test_clear_x") == 42 as Int?)

        py.clearMain()

        #expect(py.main._test_clear_x == nil)
    }

    @Test func isolatedExecuteCapturesResultsInProvidedNamespace() async throws {
        let namespace = PyObject { py.newdict($0) }
        let code = try Interpreter.compile("answer = len([1, 2, 3]) + 39")

        // `len` proves builtins are still reachable from the isolated namespace.
        try await Interpreter.execute(code, globals: namespace)

        let values = [String: Int](namespace)
        #expect(values?["answer"] == 42)
    }

    @Test func isolatedExecuteSharesGlobalsAndLocals() async throws {
        let namespace = PyObject { py.newdict($0) }
        let code = try Interpreter.compile(
            """
            base = 40
            def add_two():
                return base + 2
            result = add_two()
            """
        )

        // A top-level function must see other top-level names, which only holds
        // when globals and locals are the same mapping.
        try await Interpreter.execute(code, globals: namespace)

        // The namespace also holds the `add_two` function, so read the single
        // value rather than casting every entry to Int.
        let values = [String: PyObject](namespace)
        #expect(Int(values?["result"]) == 42)
    }

    @Test func withOutputCaptureReturnsPrintedText() async throws {
        let code = try Interpreter.compile(
            """
            print("hello")
            print("world")
            """
        )

        let output = try await Interpreter.withOutputCapture {
            try await Interpreter.execute(code)
        }

        #expect(output == "hello\nworld\n")
    }

    @Test func displayHookTerminatesRepresentationWithNewline() async throws {
        let code = try Interpreter.compile(
            """
            "Test"
            print("Exit")
            """,
            mode: .single
        )

        let output = try await Interpreter.withOutputCapture {
            try await Interpreter.execute(code)
        }

        #expect(output == "'Test'\nExit\n")
    }

    @Test(
        .disabled("Performance benchmark")
    )
    func performance() {
        Interpreter.run(primes)
    }
}

let primes = """
UPPER_BOUND = 5000000
PREFIX = 32338

# exit(0)

class Node:
    def __init__(self):
        self.children = {}
        self.terminal = False


class Sieve:
    def __init__(self, limit):
        self.limit = limit
        self.prime = [False] * (limit + 1)

    def to_list(self):
        result = [2, 3]
        for p in range(5, self.limit + 1):
            if self.prime[p]:
                result.append(p)
        return result

    def omit_squares(self):
        r = 5
        while r * r < self.limit:
            if self.prime[r]:
                i = r * r
                while i < self.limit:
                    self.prime[i] = False
                    i = i + r * r
            r += 1
        return self

    def step1(self, x, y):
        n = (4 * x * x) + (y * y)
        if n <= self.limit and (n % 12 == 1 or n % 12 == 5):
            self.prime[n] = not self.prime[n]

    def step2(self, x, y):
        n = (3 * x * x) + (y * y)
        if n <= self.limit and n % 12 == 7:
            self.prime[n] = not self.prime[n]

    def step3(self, x, y):
        n = (3 * x * x) - (y * y)
        if x > y and n <= self.limit and n % 12 == 11:
            self.prime[n] = not self.prime[n]

    def loop_y(self, x):
        y = 1
        while y * y < self.limit:
            self.step1(x, y)
            self.step2(x, y)
            self.step3(x, y)
            y += 1

    def loop_x(self):
        x = 1
        while x * x < self.limit:
            self.loop_y(x)
            x += 1

    def calc(self):
        self.loop_x()
        return self.omit_squares()


def generate_trie(l):
    root = Node()
    for el in l:
        head = root
        for ch in str(el):
            if ch not in head.children:
                head.children[ch] = Node()
            head = head.children[ch]
        head.terminal = True
    return root


def find(upper_bound, prefix):
    primes = Sieve(upper_bound).calc()
    str_prefix = str(prefix)
    head = generate_trie(primes.to_list())
    for ch in str_prefix:
        head = head.children.get(ch)
        if head is None:    # either ch does not exist or the value is None
            return None

    queue, result = [(head, str_prefix)], []
    while queue:
        top, prefix = queue.pop()
        if top.terminal:
            result.append(int(prefix))
        for ch, v in top.children.items():
            queue.insert(0, (v, prefix + ch))

    result.sort()
    return result


def verify():
    left = [2, 23, 29]
    right = find(100, 2)
    if left != right:
        print(f"{left} != {right}")
        exit(1)

verify()
results = find(UPPER_BOUND, PREFIX)
assert results == [323381, 323383, 3233803, 3233809, 3233851, 3233863, 3233873, 3233887, 3233897]
"""
