import Foundation
import Observation

/// The app's UI language — follow the system or a concrete language
/// the bundle ships. Applied to the views via the environment locale
/// (Text keys) and to programmatic strings via `string(_:)`.
/// Nonisolated by design — UserDefaults is thread-safe and the
/// service layer reads the store from Sendable error types.
@Observable
public final class LanguageStore {
    public enum Language: String, CaseIterable {
        case en
        case ru

        /// The language's own name — a picker lists languages the way
        /// macOS does, each in its own spelling.
        public var displayName: String {
            switch self {
            case .en: "English"
            case .ru: "Русский"
            }
        }
    }

    /// The one instance — UserDefaults is already global, the store
    /// is its thin typed wrapper.
    public static let shared = LanguageStore()

    private static let storageKey = "appLanguage"

    /// The chosen language; nil follows the system.
    public var language: Language? {
        didSet {
            UserDefaults.standard.set(language?.rawValue ?? "", forKey: Self.storageKey)
        }
    }

    private init() {
        language = Language(rawValue: UserDefaults.standard.string(forKey: Self.storageKey) ?? "")
    }

    /// The locale the windows apply — autoupdating when the system
    /// language leads, fixed otherwise.
    public var locale: Locale {
        language.map { Locale(identifier: $0.rawValue) } ?? .autoupdatingCurrent
    }

    /// The languages the picker offers — only what the bundle ships.
    public var availableLanguages: [Language] {
        Language.allCases.filter { lprojBundle($0.rawValue) != nil }
    }

    /// A localized string for a key, honoring the chosen language
    /// with the chosen → English → key fallback chain, so a missing
    /// translation never leaks the key as text.
    public func string(_ key: String) -> String {
        guard let language else {
            return String(localized: String.LocalizationValue(key))
        }
        for lang in [language.rawValue, "en"] {
            guard let bundle = lprojBundle(lang) else { continue }
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        return key
    }

    private func lprojBundle(_ language: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
