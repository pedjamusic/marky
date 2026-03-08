import SwiftUI

enum AppPreferenceKeys {
    static let appearanceMode = "settings.appearanceMode"
    static let markdownTypographyMode = "settings.markdownTypographyMode"
    static let markdownReaderTextSizePreset = "settings.markdownReaderTextSizePreset"
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    nonisolated var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

#if os(macOS)
struct MarkySettingsView: View {
    @AppStorage(AppPreferenceKeys.appearanceMode)
    private var appearanceModeRawValue = AppAppearanceMode.system.rawValue

    @AppStorage(AppPreferenceKeys.markdownTypographyMode)
    private var markdownTypographyModeRawValue = MarkdownTypographyMode.allSystem.rawValue

    @AppStorage(AppPreferenceKeys.markdownReaderTextSizePreset)
    private var markdownReaderTextSizePresetRawValue = MarkdownReaderTextSizePreset.default.rawValue

    private var appearanceMode: Binding<AppAppearanceMode> {
        Binding(
            get: { AppAppearanceMode(rawValue: appearanceModeRawValue) ?? .system },
            set: { appearanceModeRawValue = $0.rawValue }
        )
    }

    private var typographyMode: Binding<MarkdownTypographyMode> {
        Binding(
            get: { MarkdownTypographyMode(rawValue: markdownTypographyModeRawValue) ?? .allSystem },
            set: { markdownTypographyModeRawValue = $0.rawValue }
        )
    }

    private var textSizePreset: Binding<MarkdownReaderTextSizePreset> {
        Binding(
            get: {
                MarkdownReaderTextSizePreset(rawValue: markdownReaderTextSizePresetRawValue) ?? .default
            },
            set: { markdownReaderTextSizePresetRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Picker("Appearance", selection: appearanceMode) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Picker("Markdown Typography", selection: typographyMode) {
                ForEach(MarkdownTypographyMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Picker("Reader Text Size", selection: textSizePreset) {
                ForEach(MarkdownReaderTextSizePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .frame(width: 420)
    }
}
#endif
