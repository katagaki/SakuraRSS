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
        let rowElements = directRows(of: table)
        // Expand colspan/rowspan into a 2D grid so columns stay aligned.
        var grid: [[String]] = []
        for (rowIndex, row) in rowElements.enumerated() {
            let cells = row.children().array().filter {
                let tag = $0.tagName().lowercased()
                return tag == "th" || tag == "td"
            }
            if cells.isEmpty { continue }
            while grid.count <= rowIndex { grid.append([]) }
            var col = 0
            for cell in cells {
                while col < grid[rowIndex].count && !grid[rowIndex][col].isEmpty {
                    col += 1
                }
                let text = (try? textContent(of: cell, baseURL: baseURL)) ?? ""
                let colspan = max(1, Int((try? cell.attr("colspan")) ?? "") ?? 1)
                let rowspan = max(1, Int((try? cell.attr("rowspan")) ?? "") ?? 1)
                for rowOffset in 0..<rowspan {
                    let targetRow = rowIndex + rowOffset
                    while grid.count <= targetRow { grid.append([]) }
                    for colOffset in 0..<colspan {
                        let targetCol = col + colOffset
                        while grid[targetRow].count <= targetCol {
                            grid[targetRow].append("")
                        }
                        grid[targetRow][targetCol] = text
                    }
                }
                col += colspan
            }
        }
        return grid.filter { !$0.allSatisfy(\.isEmpty) }
    }

    /// Returns `<tr>` elements that belong directly to this table, skipping
    /// rows from any nested tables. Handles optional `<thead>`/`<tbody>`/`<tfoot>` wrappers.
    private static func directRows(of table: Element) -> [Element] {
        var rows: [Element] = []
        for child in table.children() {
            let tag = child.tagName().lowercased()
            if tag == "tr" {
                rows.append(child)
            } else if tag == "thead" || tag == "tbody" || tag == "tfoot" {
                for grandchild in child.children() where grandchild.tagName().lowercased() == "tr" {
                    rows.append(grandchild)
                }
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
