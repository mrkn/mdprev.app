import Foundation

public enum HighlightJSSupport {
    public static let bootstrapMarker = "mdprev-highlight-bootstrap-v1"

    public static func inlineScriptTagsHTML(for theme: SyntaxHighlightTheme) -> String {
        guard !theme.isDisabled else {
            return ""
        }

        var scripts: [String] = []

        if !inlineLibraryScript.isEmpty {
            scripts.append("<script>\(inlineLibraryScript)</script>")
        }

        scripts.append("<script>\(inlineBootstrapScript)</script>")
        return scripts.joined(separator: "\n")
    }

    public static func syntaxThemeCSS(
        for theme: SyntaxHighlightTheme,
        previewTheme: PreviewTheme,
        followThemeLightIdentifier: String = HighlightJSThemeCatalog.resolvedFollowPreviewLightIdentifier,
        followThemeDarkIdentifier: String = HighlightJSThemeCatalog.resolvedFollowPreviewDarkIdentifier,
        followThemeSepiaIdentifier: String = HighlightJSThemeCatalog.resolvedFollowPreviewSepiaIdentifier
    ) -> String {
        if theme.isDisabled {
            return ""
        }

        if theme.isFollowPreview {
            return followPreviewThemeCSS(
                previewTheme,
                lightIdentifier: followThemeLightIdentifier,
                darkIdentifier: followThemeDarkIdentifier,
                sepiaIdentifier: followThemeSepiaIdentifier
            )
        }

        return singleThemeCSS(themeIdentifier: theme.rawValue)
    }

    private static func followPreviewThemeCSS(
        _ previewTheme: PreviewTheme,
        lightIdentifier: String,
        darkIdentifier: String,
        sepiaIdentifier: String
    ) -> String {
        let resolvedLightIdentifier = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: lightIdentifier,
            fallback: darkIdentifier
        )
        let resolvedDarkIdentifier = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: darkIdentifier,
            fallback: resolvedLightIdentifier
        )
        let resolvedSepiaIdentifier = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: sepiaIdentifier,
            fallback: resolvedLightIdentifier
        )

        switch previewTheme {
        case .dark:
            return singleThemeCSS(themeIdentifier: resolvedDarkIdentifier)

        case .light:
            return singleThemeCSS(themeIdentifier: resolvedLightIdentifier)

        case .sepia:
            return singleThemeCSS(themeIdentifier: resolvedSepiaIdentifier)

        case .system:
            let lightCSS = themedCSS(themeIdentifier: resolvedLightIdentifier)
            let darkCSS = themedCSS(themeIdentifier: resolvedDarkIdentifier)

            return """
                  \(lightCSS)

                  @media (prefers-color-scheme: dark) {
                  \(indented(darkCSS, spaces: 2))
                  }
            """
        }
    }

    private static func singleThemeCSS(themeIdentifier: String) -> String {
        themedCSS(themeIdentifier: themeIdentifier)
    }

    private static func themedCSS(themeIdentifier: String) -> String {
        guard let css = HighlightJSThemeCatalog.css(for: themeIdentifier) else {
            return "/* mdprev-hljs-theme:\(themeIdentifier)-missing */"
        }

        return """
              /* mdprev-hljs-theme:\(themeIdentifier) */
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

          codeElement.classList.add('hljs');

          const language = resolveLanguage(container, codeElement);
          if (!language) {
            codeElement.dataset.mdprevHighlighted = 'true';
            continue;
          }

          codeElement.classList.add(`language-${language}`);

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
