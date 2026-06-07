import SwiftUI
import MarkdownUI
import Highlightr
import AppKit

public struct HighlightrCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let highlightr: Highlightr?
    
    public init() {
        self.highlightr = Highlightr()
        // atom-one-dark provides a fantastic, rich color palette that works well on both light and dark glass if we tweak the background.
        self.highlightr?.setTheme(to: "atom-one-dark")
    }
    
    public func highlightCode(_ code: String, language: String?) -> Text {
        guard let highlightr = highlightr else {
            return Text(code)
        }
        
        let languageToUse = language ?? "plaintext"
        if let attrStr = highlightr.highlight(code, as: languageToUse, fastRender: true) {
            let mutableAttrStr = NSMutableAttributedString(attributedString: attrStr)
            
            // Strip the ugly default font (Courier) so MarkdownUI's SF Mono can take over!
            mutableAttrStr.removeAttribute(.font, range: NSRange(location: 0, length: mutableAttrStr.length))
            // Strip any hardcoded background colors so our glass background shines through.
            mutableAttrStr.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutableAttrStr.length))
            
            do {
                let swiftyAttrStr = try AttributedString(mutableAttrStr, including: \.appKit)
                return Text(swiftyAttrStr)
            } catch {
                return Text(code)
            }
        } else {
            return Text(code)
        }
    }
}

public extension CodeSyntaxHighlighter where Self == HighlightrCodeSyntaxHighlighter {
    static var highlightr: Self {
        HighlightrCodeSyntaxHighlighter()
    }
}
