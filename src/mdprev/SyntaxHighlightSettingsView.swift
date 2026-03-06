import SwiftUI

struct SyntaxHighlightSettingsView: View {
    @ObservedObject var settingsStore: SyntaxHighlightSettingsStore

    var body: some View {
        Form {
            Section("Follow Theme") {
                themeSelectionRow(
                    title: "Light Mode Theme",
                    selectedIdentifier: settingsStore.followThemeLightIdentifier,
                    setSelectedIdentifier: settingsStore.setFollowThemeLightIdentifier
                )
                themeSelectionRow(
                    title: "Dark Mode Theme",
                    selectedIdentifier: settingsStore.followThemeDarkIdentifier,
                    setSelectedIdentifier: settingsStore.setFollowThemeDarkIdentifier
                )
                Picker("Sepia Theme", selection: sepiaModeSelection) {
                    ForEach(FollowThemeSepiaMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                if settingsStore.followThemeSepiaMode == .custom {
                    themeSelectionRow(
                        title: "Sepia Theme",
                        selectedIdentifier: settingsStore.followThemeSepiaIdentifier,
                        setSelectedIdentifier: settingsStore.setFollowThemeSepiaIdentifier
                    )
                } else {
                    Text("Sepia will use the selected Light Mode theme.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("These themes are used when Syntax Highlight is set to Follow Theme.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 360)
        .padding(16)
    }

    @ViewBuilder
    private func themeSelectionRow(
        title: String,
        selectedIdentifier: String,
        setSelectedIdentifier: @escaping (String) -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Menu(selectedThemeTitle(for: selectedIdentifier)) {
                ForEach(themeMenuModel.sections, id: \.letter) { section in
                    Menu(section.letter) {
                        ForEach(section.base16Subsections, id: \.letter) { subsection in
                            Menu("Base16 / \(subsection.letter)") {
                                ForEach(subsection.themes, id: \.rawValue) { theme in
                                    Button(menuItemTitle(for: theme, selectedIdentifier: selectedIdentifier)) {
                                        setSelectedIdentifier(theme.rawValue)
                                    }
                                }
                            }
                        }

                        ForEach(section.standaloneThemes, id: \.rawValue) { theme in
                            Button(menuItemTitle(for: theme, selectedIdentifier: selectedIdentifier)) {
                                setSelectedIdentifier(theme.rawValue)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sepiaModeSelection: Binding<FollowThemeSepiaMode> {
        Binding(
            get: { settingsStore.followThemeSepiaMode },
            set: { settingsStore.setFollowThemeSepiaMode($0) }
        )
    }

    private func selectedThemeTitle(for identifier: String) -> String {
        HighlightJSThemeCatalog.displayName(for: identifier)
    }

    private func menuItemTitle(for theme: SyntaxHighlightTheme, selectedIdentifier: String) -> String {
        if theme.rawValue == selectedIdentifier {
            return "✓ \(theme.displayName)"
        }

        return theme.displayName
    }

    private var themeMenuModel: SyntaxHighlightThemeMenuModel {
        let themes = settingsStore.availableThemes.map { definition in
            SyntaxHighlightTheme(rawValue: definition.identifier)
        }
        return SyntaxHighlightThemeMenuModel(themes: themes)
    }
}
