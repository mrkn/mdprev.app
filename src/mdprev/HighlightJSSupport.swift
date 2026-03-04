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

    static var syntaxTokenCSS: String {
        """
              .mdprev-code-line-text {
                color: var(--syntax-text);
              }

              .mdprev-code-line-text .hljs-comment,
              .mdprev-code-line-text .hljs-quote {
                color: var(--syntax-comment);
                font-style: italic;
              }

              .mdprev-code-line-text .hljs-keyword,
              .mdprev-code-line-text .hljs-selector-tag,
              .mdprev-code-line-text .hljs-literal,
              .mdprev-code-line-text .hljs-doctag,
              .mdprev-code-line-text .hljs-formula {
                color: var(--syntax-keyword);
              }

              .mdprev-code-line-text .hljs-string,
              .mdprev-code-line-text .hljs-meta .hljs-string,
              .mdprev-code-line-text .hljs-regexp,
              .mdprev-code-line-text .hljs-char.escape_ {
                color: var(--syntax-string);
              }

              .mdprev-code-line-text .hljs-number,
              .mdprev-code-line-text .hljs-symbol,
              .mdprev-code-line-text .hljs-bullet,
              .mdprev-code-line-text .hljs-link {
                color: var(--syntax-number);
              }

              .mdprev-code-line-text .hljs-title,
              .mdprev-code-line-text .hljs-title.class_,
              .mdprev-code-line-text .hljs-title.class_.inherited__,
              .mdprev-code-line-text .hljs-title.function_ {
                color: var(--syntax-type);
              }

              .mdprev-code-line-text .hljs-function,
              .mdprev-code-line-text .hljs-attr,
              .mdprev-code-line-text .hljs-property,
              .mdprev-code-line-text .hljs-params {
                color: var(--syntax-function);
              }

              .mdprev-code-line-text .hljs-variable,
              .mdprev-code-line-text .hljs-template-variable,
              .mdprev-code-line-text .hljs-selector-id,
              .mdprev-code-line-text .hljs-selector-class {
                color: var(--syntax-variable);
              }

              .mdprev-code-line-text .hljs-addition {
                color: var(--syntax-string);
              }

              .mdprev-code-line-text .hljs-deletion {
                color: var(--syntax-keyword);
              }
        """
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
        guard let url = urlInSubdirectory ?? urlAtRoot,
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }

        return inlineScript(source)
    }

    private static func inlineScript(_ source: String) -> String {
        source.replacingOccurrences(of: "</script>", with: "<\\/script>")
    }
}
