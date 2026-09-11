//
//  Embeddings.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-02.
//

import Foundation
import NaturalLanguage

@MainActor
public final class Embeddings {
    public static let shared = Embeddings()

    // Loading an NLEmbedding is expensive, so keep one per language alive.
    private var cache: [NLLanguage: NLEmbedding] = [:]

    private func embedding(for language: NLLanguage) throws(PythonError) -> NLEmbedding {
        if let cached = cache[language] {
            return cached
        }

        // NLLanguage accepts any tag, so this probe is what rejects typos and
        // unsupported languages. It doesn't load the model.
        guard !NLEmbedding.supportedSentenceEmbeddingRevisions(for: language).isEmpty,
              let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
            throw .ValueError("No sentence embedding for language '\(language.rawValue)'.")
        }

        cache[language] = embedding
        return embedding
    }

    func embed(text: String, language: String?) throws(PythonError) -> Embedding {
        let language = if let language {
            NLLanguage(rawValue: language)
        } else {
            NLLanguage.english
        }

        guard let vector = try embedding(for: language).vector(for: text) else {
            throw .ValueError("Could not compute an embedding for the given text.")
        }

        return Embedding(vector: vector, language: language.rawValue)
    }

    func similarity(_ a: Embedding, _ b: Embedding) throws(PythonError) -> Double {
        // Each language is its own vector space, so scores across them are
        // meaningless rather than merely inaccurate.
        guard a.language == b.language else {
            throw .ValueError("Cannot compare '\(a.language)' and '\(b.language)' embeddings.")
        }

        guard a.vector.count == b.vector.count else {
            throw .ValueError("Vectors must be the same length, got \(a.vector.count) and \(b.vector.count).")
        }

        var dot = 0.0
        var squaredA = 0.0
        var squaredB = 0.0

        for (x, y) in zip(a.vector, b.vector) {
            dot += x * y
            squaredA += x * x
            squaredB += y * y
        }

        let magnitude = (squaredA * squaredB).squareRoot()
        return magnitude > 0 ? dot / magnitude : 0
    }
}

extension Interpreter {
    func bindEmbeddings() {
        bindModule("embeddings", docs: """
        On-device sentence embeddings and semantic similarity.

        Embed text into a vector, then compare vectors to find text that means
        the same thing rather than text that shares the same words. Nothing
        leaves the device.

        ```python
        import embeddings

        question = embeddings.embed("Where is my order?")
        faq = embeddings.embed("How do I check my order status?")
        print(embeddings.similarity(question, faq))  # 0.77
        ```
        """) { module in
            module.class(Embedding.self)

            module.def(
                "embed(text: str, language: str | None = None) -> Embedding",
                docstring: """
                Return the sentence embedding of the text.

                text: The text to embed. Sentences and short paragraphs work best.
                language: A BCP-47 language tag, such as `"de"`. Defaults to English.

                Raises `ValueError` for a language with no sentence embedding.

                ```python
                import embeddings

                greeting = embeddings.embed("Guten Morgen", "de")
                print(greeting.language, len(greeting.vector))
                ```
                """
            ) { argc, argv in
                PyBind.function(argc, argv, Embeddings.shared.embed)
            }

            module.def(
                "similarity(a: Embedding, b: Embedding) -> float",
                docstring: """
                Return the cosine similarity of two embeddings, from -1 to 1.

                a: An embedding to compare.
                b: The embedding to compare it against.

                Text that means the same thing scores near 1, unrelated text
                near 0. Both embeddings must share a language, since every
                language is its own vector space.

                ```python
                import embeddings

                cat = embeddings.embed("the cat is sleeping")
                kitten = embeddings.embed("a kitten is taking a nap")
                market = embeddings.embed("the stock market fell sharply")

                print(embeddings.similarity(cat, kitten))  # 0.66
                print(embeddings.similarity(cat, market))  # 0.21
                ```
                """
            ) { argc, argv in
                PyBind.function(argc, argv, Embeddings.shared.similarity)
            }
        }
    }
}
