//
//  SignatureCleaner.swift
//  Smock
//
//  Created by Dan Kane on 9/21/26.
//

import SwiftSyntax

class SignatureCleaner: SyntaxRewriter {
    var removeComments: Bool = true
    var removeLineBreaks: Bool = false

    init(removeComments: Bool, removeLineBreaks: Bool) {
        self.removeComments = removeComments
        self.removeLineBreaks = removeLineBreaks
    }

    override func visit(_ token: TokenSyntax) -> TokenSyntax {
        // Filter trivia
        let cleanLeading = token.leadingTrivia.filteringPieces(
            comments: removeComments,
            lineBreaks: removeLineBreaks
        )
        var cleanTrailing = token.trailingTrivia.filteringPieces(
            comments: removeComments,
            lineBreaks: removeLineBreaks
        )

        if token.tokenKind == .comma {
            cleanTrailing = cleanTrailing.appending(TriviaPiece.spaces(1))
        }

        return token
            .with(\.leadingTrivia, cleanLeading)
            .with(\.trailingTrivia, cleanTrailing)
    }
}

private extension Trivia {
    func filteringPieces(comments: Bool, lineBreaks: Bool) -> Trivia {
        var last: TriviaPiece?
        return Trivia(pieces: self.compactMap { piece -> TriviaPiece? in
            let next = switch piece {
            case .lineComment, .blockComment, .docLineComment, .docBlockComment: comments ? nil : piece // strip comments
            case .newlines, .carriageReturns, .carriageReturnLineFeeds: lineBreaks ? nil : piece // stripe line breaks
            case .spaces where lineBreaks,
                 .tabs where lineBreaks: // Remove white space following line breaks
                switch last {
                case .newlines, .carriageReturns, .carriageReturnLineFeeds, .spaces, .tabs: nil as TriviaPiece?
                default: piece
                }
            default: piece
            }

            last = piece
            return next
        })
    }
}

extension SyntaxProtocol {
    /// Reproduces the full header & signature of the function, excluding comments,
    /// while completely preserving line-wrapping and indentation.
    func signatureDescription(
        removeComments: Bool = true,
        removeLineBreaks: Bool = false
    ) -> String {
        // Clean the header while preserving other formatting trivia
        let cleanedNode = SignatureCleaner(
            removeComments: removeComments,
            removeLineBreaks: removeLineBreaks
        ).rewrite(Syntax(self))

        // 3. Trim extra dangling spacing at the very end of the signature text
        return cleanedNode.trimmedDescription
    }
}
