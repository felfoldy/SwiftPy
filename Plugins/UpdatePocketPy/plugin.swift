//
//  plugin.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-16.
//

import Foundation
import PackagePlugin

@main
struct UpdatePocketPy: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let url = URL(string: "https://github.com/pocketpy/pocketpy/releases/latest/download")!

        let pocketpy_h = try String(
            contentsOf:  url.appending(path: "pocketpy.h"),
            encoding: .utf8
        )
        // Insert extensions.
        .appending(#"#include "pocketpy_extensions.h""#)
        
        var pocketpy_c = try String(
            contentsOf: url.appending(path: "pocketpy.c"),
            encoding: .utf8
        )

        for (original, new) in sourceReplacements {
            pocketpy_c = pocketpy_c.replacingOccurrences(of: original, with: new)
        }

        let outUrl = context.package.directoryURL
            .appending(path: "Sources/pocketpy")

        try pocketpy_h.write(
            to: outUrl.appending(path: "include/pocketpy.h"),
            atomically: true,
            encoding: .utf8
        )

        try pocketpy_c.write(
            to: outUrl.appending(path: "src/pocketpy.c"),
            atomically: true,
            encoding: .utf8
        )
    }
}

private let sourceReplacements: [(String, String)] = [
    // Async/await injection into lexer.
    (
        """
        static void add_token_with_value(Lexer* self, TokenIndex type, TokenValue value) {
            switch(type) {
                case TK_LBRACE:
                case TK_LBRACKET:
                case TK_LPAREN: self->brackets_level++; break;
                case TK_RPAREN:
                case TK_RBRACKET:
                case TK_RBRACE: self->brackets_level--; break;
                default: break;
            }
            Token token = {type,
                           self->token_start,
                           (int)(self->curr_char - self->token_start),
                           self->current_line - ((type == TK_EOL) ? 1 : 0),
                           self->brackets_level,
                           value};
        """,
        """
        static void add_token_with_value(Lexer* self, TokenIndex type, TokenValue value) {
            switch(type) {
                case TK_LBRACE:
                case TK_LBRACKET:
                case TK_LPAREN: self->brackets_level++; break;
                case TK_RPAREN:
                case TK_RBRACKET:
                case TK_RBRACE: self->brackets_level--; break;
                default: break;
            }
            Token token = {type,
                           self->token_start,
                           (int)(self->curr_char - self->token_start),
                           self->current_line - ((type == TK_EOL) ? 1 : 0),
                           self->brackets_level,
                           value};

            if(type == TK_ID && token.length == 5 && strncmp(token.start, "await", 5) == 0) {
                // await -> yield from
                token.type = TK_YIELD_FROM;
            }

            // handle "async def", "not in", "is not", "yield from"
            Token* back = &c11_vector__back(Token, &self->nexts);

            if(back->type == TK_ID && back->length == 5 && strncmp(back->start, "async", 5) == 0 &&
               type == TK_DEF) {
                // remove previous async token
                self->nexts.length--;
                
                Token deco = *back;
                deco.type = TK_DECORATOR;
                c11_vector__push(Token, &self->nexts, deco);
                
                Token id = *back;
                id.type = TK_ID;
                c11_vector__push(Token, &self->nexts, id);
                
                Token eol = *back;
                eol.type = TK_EOL;
                c11_vector__push(Token, &self->nexts, eol);
                // def
                c11_vector__push(Token, &self->nexts, token);
                return;
            }
        """
    )
]
