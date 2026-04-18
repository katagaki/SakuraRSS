import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Builds a `{{TABLE}}…{{/TABLE}}` marker from a `<table>` element.
    /// Rows use `|` as the cell separator and `\n` as the row separator.
    /// Returns `nil` when the table is empty or appears to be layout-only.
    static func tableMarker(from table: Element, baseURL: URL? = nil) -> String? {
        let rows: [[String]]
        do {
            rows = try extractTableRows(from: table, baseURL: baseURL)
        } catch {
            return nil
        }
        guard rows.count >= 1 else { return nil }
        // Guard against single-cell layout tables that just wrap a paragraph.
        if rows.count == 1 && rows[0].count <= 1 { return nil }
        let payload = rows
            .map { cells in
                cells
                    .map { encodeTableCell($0) }
                    .joined(separator: "|")
            }
            .joined(separator: "\n")
        return "{{TABLE}}\(payload){{/TABLE}}"
    }

    private static func extractTableRows(
        from table: Element, baseURL: URL?
    ) throws -> [[String]] {
        let rowElements = try table.select("tr")
        var rows: [[String]] = []
        for row in rowElements {
            let cells = try row.select("th, td")
            guard !cells.isEmpty() else { continue }
            var rowCells: [String] = []
            for cell in cells {
                let text = (try? textContent(of: cell, baseURL: baseURL)) ?? ""
                rowCells.append(text)
            }
            if !rowCells.allSatisfy(\.isEmpty) {
                rows.append(rowCells)
            }
        }
        return rows
    }

    private static func encodeTableCell(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "|", with: "¦")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Returns `{{MATH}}latex{{/MATH}}` marker for MathJax / KaTeX blocks
    /// when we can recover the underlying LaTeX source.
    static func mathMarker(from element: Element) -> String? {
        let className = (try? element.className()) ?? ""
        let tag = element.tagName().lowercased()
        let hasKatex = className.contains("katex")
        let hasMathJax = className.contains("MathJax") || className.contains("mathjax")
        let isMathTag = tag == "math"
        guard hasKatex || hasMathJax || isMathTag else { return nil }

        if let annotation = try? element.select(
            "annotation[encoding=application/x-tex]"
        ).first(),
           let text = try? annotation.text(),
           !text.isEmpty {
            return "{{MATH}}\(ArticleMarker.escape(text)){{/MATH}}"
        }
        if let mathML = try? element.attr("data-mathml"), !mathML.isEmpty {
            return "{{MATH}}\(ArticleMarker.escape(mathML)){{/MATH}}"
        }
        let text = ((try? element.text()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return "{{MATH}}\(ArticleMarker.escape(text)){{/MATH}}"
        }
        return nil
    }
}
