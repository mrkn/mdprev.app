import Foundation

enum HighlightJSSupport {
    static let bootstrapMarker = "mdprev-highlight-bootstrap-v1"

    static var inlineScriptTagsHTML: String {
        var scripts: [String] = []

        if !inlineLibraryScript.isEmpty {
            scripts.append("<script>\(inlineLibraryScript)</script>")
        }

        scripts.append("<script>\(inlineBootstrapScript)</script>")
        return scripts.joined(separator: "\n")
    }

    static func syntaxThemeCSS(
        for theme: SyntaxHighlightTheme,
        previewTheme: PreviewTheme
    ) -> String {
        switch theme {
        case .followPreview:
            return followPreviewThemeCSS(previewTheme)

        case .github:
            return singleThemeCSS(asset: .github)

        case .githubDark:
            return singleThemeCSS(asset: .githubDark)

        case .atomOneDark:
            return singleThemeCSS(asset: .atomOneDark)

        case .xcode:
            return singleThemeCSS(asset: .xcode)
        }
    }

    private static func followPreviewThemeCSS(_ previewTheme: PreviewTheme) -> String {
        switch previewTheme {
        case .dark:
            return singleThemeCSS(asset: .githubDark)

        case .light, .sepia:
            return singleThemeCSS(asset: .github)

        case .system:
            let lightCSS = themedCSS(asset: .github)
            let darkCSS = themedCSS(asset: .githubDark)

            return """
                  \(lightCSS)

                  @media (prefers-color-scheme: dark) {
                  \(indented(darkCSS, spaces: 2))
                  }

                  \(lineLevelOverridesCSS)
            """
        }
    }

    private static func singleThemeCSS(asset: HighlightJSThemeAsset) -> String {
        """
              \(themedCSS(asset: asset))

              \(lineLevelOverridesCSS)
        """
    }

    private static func themedCSS(asset: HighlightJSThemeAsset) -> String {
        guard let css = themeCSSByAsset[asset] else {
            return "/* mdprev-hljs-theme:\(asset.marker)-missing */"
        }

        return """
              /* mdprev-hljs-theme:\(asset.marker) */
              \(css)
        """
    }

    private static func indented(_ text: String, spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + $0 }
            .joined(separator: "\n")
    }

    private static let lineLevelOverridesCSS = """
              .mdprev-code-line-text.hljs {
                display: block;
                background: transparent !important;
                padding: 0 !important;
              }
        """

    private static let themeCSSByAsset: [HighlightJSThemeAsset: String] = [
        .github: loadInlineStyle(resource: "github.min", subdirectory: "highlightjs/styles"),
        .githubDark: loadInlineStyle(resource: "github-dark.min", subdirectory: "highlightjs/styles"),
        .atomOneDark: loadInlineStyle(resource: "atom-one-dark.min", subdirectory: "highlightjs/styles"),
        .xcode: loadInlineStyle(resource: "xcode.min", subdirectory: "highlightjs/styles")
    ]

    private static let inlineLibraryScript = loadInlineScript(
        resource: "highlight.min",
        extension: "js",
        subdirectory: "highlightjs"
    )

    private static let inlineBootstrapScript = inlineScript(bootstrapScriptSource)

    private static let bootstrapScriptSource = """
    (() => {
      window['\(bootstrapMarker)'] = true;

      const highlight = window.hljs;
      if (!highlight || typeof highlight.highlight !== 'function') {
        return;
      }

      const resolveLanguage = (container, codeElement) => {
        const preferred = (container.dataset.language || '').trim();
        if (preferred && highlight.getLanguage(preferred)) {
          return preferred;
        }

        const classList = (codeElement.className || '').split(/\\s+/);
        for (const token of classList) {
          if (!token.startsWith('language-')) {
            continue;
          }

          const candidate = token.slice('language-'.length);
          if (candidate && highlight.getLanguage(candidate)) {
            return candidate;
          }
        }

        return null;
      };

      const applyHighlighting = () => {
        const containers = document.querySelectorAll('.mdprev-codeblock-container');
        for (const container of containers) {
          const codeElement = container.querySelector('pre.mdprev-codeblock code');
          if (!codeElement || codeElement.dataset.mdprevHighlighted === 'true') {
            continue;
          }

          const language = resolveLanguage(container, codeElement);
          if (!language) {
            codeElement.dataset.mdprevHighlighted = 'true';
            continue;
          }

          const lineElements = codeElement.querySelectorAll('.mdprev-code-line-text');
          for (const lineElement of lineElements) {
            const source = lineElement.textContent || '';
            try {
              lineElement.innerHTML = highlight.highlight(source, {
                language,
                ignoreIllegals: true
              }).value;
            } catch (_error) {
              lineElement.textContent = source;
            }
            lineElement.classList.add('hljs');
            lineElement.classList.add(`language-${language}`);
          }

          codeElement.dataset.mdprevHighlighted = 'true';
        }
      };

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', applyHighlighting, { once: true });
      } else {
        applyHighlighting();
      }
    })();
    """

    private static func loadInlineScript(resource: String, extension fileExtension: String, subdirectory: String?) -> String {
        guard let source = loadResource(
            resource: resource,
            fileExtension: fileExtension,
            subdirectory: subdirectory
        ) else {
            return ""
        }

        return inlineScript(source)
    }

    private static func loadInlineStyle(resource: String, subdirectory: String?) -> String {
        loadResource(resource: resource, fileExtension: "css", subdirectory: subdirectory) ?? ""
    }

    private static func loadResource(resource: String, fileExtension: String, subdirectory: String?) -> String? {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle.main
#endif

        let urlInSubdirectory = bundle.url(
            forResource: resource,
            withExtension: fileExtension,
            subdirectory: subdirectory
        )
        let urlAtRoot = bundle.url(forResource: resource, withExtension: fileExtension)

        guard let url = urlInSubdirectory ?? urlAtRoot else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func inlineScript(_ source: String) -> String {
        source.replacingOccurrences(of: "</script>", with: "<\\/script>")
    }
}

private enum HighlightJSThemeAsset: Hashable {
    case github
    case githubDark
    case atomOneDark
    case xcode

    var marker: String {
        switch self {
        case .github:
            return "github"
        case .githubDark:
            return "github-dark"
        case .atomOneDark:
            return "atom-one-dark"
        case .xcode:
            return "xcode"
        }
    }
}
