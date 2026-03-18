import Foundation
import MDPrevRendering

struct SyntaxHighlightThemeMenuModel {
    let sections: [Section]

    init(themes: [SyntaxHighlightTheme] = SyntaxHighlightTheme.allCases) {
        let normalizedThemes = themes
            .filter { !$0.isDisabled && !$0.isFollowPreview }
            .map { theme in
                NormalizedTheme(
                    theme: theme,
                    displayName: theme.displayName,
                    sectionLetter: Self.firstLetter(for: theme.displayName),
                    base16SubsectionLetter: Self.base16SubsectionLetter(for: theme)
                )
            }
            .sorted { lhs, rhs in
                Self.compare(lhs.displayName, rhs.displayName)
            }

        let groupedBySection = Dictionary(grouping: normalizedThemes, by: \.sectionLetter)
        sections = groupedBySection
            .map { sectionLetter, sectionThemes in
                let standaloneThemes = sectionThemes
                    .filter { $0.base16SubsectionLetter == nil }
                    .map(\.theme)

                let base16Pairs: [(letter: String, theme: NormalizedTheme)] = sectionThemes.compactMap { theme in
                    guard let subsectionLetter = theme.base16SubsectionLetter else {
                        return nil
                    }

                    return (letter: subsectionLetter, theme: theme)
                }

                let base16BySubsection = Dictionary(grouping: base16Pairs, by: { $0.letter })

                let base16Subsections = base16BySubsection
                    .map { subsectionLetter, pairs in
                        Base16Subsection(
                            letter: subsectionLetter,
                            themes: pairs
                                .map(\.1)
                                .sorted { lhs, rhs in
                                    Self.compare(lhs.displayName, rhs.displayName)
                                }
                                .map(\.theme)
                        )
                    }
                    .sorted { lhs, rhs in
                        Self.compare(lhs.letter, rhs.letter)
                    }

                return Section(
                    letter: sectionLetter,
                    base16Subsections: base16Subsections,
                    standaloneThemes: standaloneThemes
                )
            }
            .sorted { lhs, rhs in
                Self.compare(lhs.letter, rhs.letter)
            }
    }

    struct Section {
        let letter: String
        let base16Subsections: [Base16Subsection]
        let standaloneThemes: [SyntaxHighlightTheme]
    }

    struct Base16Subsection {
        let letter: String
        let themes: [SyntaxHighlightTheme]
    }

    private struct NormalizedTheme {
        let theme: SyntaxHighlightTheme
        let displayName: String
        let sectionLetter: String
        let base16SubsectionLetter: String?
    }

    private static func compare(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private static func firstLetter(for text: String) -> String {
        guard let first = text.first else {
            return "#"
        }

        return String(first).uppercased()
    }

    private static func base16SubsectionLetter(for theme: SyntaxHighlightTheme) -> String? {
        guard theme.rawValue.hasPrefix("base16/") else {
            return nil
        }

        let suffix = String(theme.rawValue.dropFirst("base16/".count))
        return firstLetter(for: suffix)
    }
}
