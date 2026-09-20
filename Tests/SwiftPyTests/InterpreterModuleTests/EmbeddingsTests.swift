//
//  EmbeddingsTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-02.
//

import Testing
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct EmbeddingsTests {
    /// Sentence embedding assets aren't present on every run destination, so
    /// the model-dependent tests bail out instead of failing.
    private func isAvailable() async -> Bool {
        await Interpreter.run("""
        import embeddings
        try:
            _available = len(embeddings.embed('hello').vector) > 0
        except:
            _available = False
        """)
        return Interpreter.evaluate("_available") == true
    }

    @Test func embed_tagsVectorWithLanguage() async {
        guard await isAvailable() else { return }

        await Interpreter.run("_e = embeddings.embed('Where is my order?')")

        #expect(Interpreter.evaluate("len(_e.vector) > 0") == true)
        #expect(Interpreter.evaluate("_e.language") == "en")
    }

    @Test func similarity_scoresRelatedTextHigher() async throws {
        guard await isAvailable() else { return }

        await Interpreter.run("""
        _a = embeddings.embed('Where is my order?')
        _b = embeddings.embed('How do I check my order status?')
        _c = embeddings.embed('The weather is cold today.')
        _related = embeddings.similarity(_a, _b)
        _unrelated = embeddings.similarity(_a, _c)
        """)

        let related: Double = try #require(Interpreter.evaluate("_related"))
        let unrelated: Double = try #require(Interpreter.evaluate("_unrelated"))
        #expect(related > unrelated)
    }

    @Test func similarity_withItself_isOne() async throws {
        guard await isAvailable() else { return }

        await Interpreter.run("_a = embeddings.embed('a sentence')")

        let similarity: Double = try #require(
            Interpreter.evaluate("embeddings.similarity(_a, _a)")
        )
        #expect(abs(similarity - 1) < 0.0001)
    }

    @Test func embedding_rebuiltFromStoredVector_matchesOriginal() async throws {
        guard await isAvailable() else { return }

        await Interpreter.run("""
        _a = embeddings.embed('a sentence')
        _restored = embeddings.Embedding(_a.vector, _a.language)
        """)

        let similarity: Double = try #require(
            Interpreter.evaluate("embeddings.similarity(_a, _restored)")
        )
        #expect(abs(similarity - 1) < 0.0001)
    }

    @Test func embed_withUnknownLanguage_raises() async {
        await Interpreter.run("""
        import embeddings
        try:
            embeddings.embed('hello', 'zz')
            _raised = False
        except ValueError:
            _raised = True
        """)

        #expect(Interpreter.evaluate("_raised") == true)
    }

    @Test func similarity_acrossLanguages_raises() async {
        guard await isAvailable() else { return }

        await Interpreter.run("""
        _a = embeddings.embed('hello')
        _de = embeddings.Embedding(_a.vector, 'de')
        try:
            embeddings.similarity(_a, _de)
            _raised = False
        except ValueError:
            _raised = True
        """)

        #expect(Interpreter.evaluate("_raised") == true)
    }

    @Test func repr_omitsVectorContents() async throws {
        guard await isAvailable() else { return }

        let repr: String = try #require(
            Interpreter.evaluate("repr(embeddings.embed('hello'))")
        )
        #expect(repr.contains("'en'"))
        #expect(repr.contains("dimensions"))
    }
}
