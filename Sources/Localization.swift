import Foundation

private let legacyMessages: Bundle? = {
    guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else { return nil }
    return Bundle(path: path)
}()

func L(_ key: String) -> String {
    // Older helpers wrote translated text into their status and event files.
    // Normalize legacy messages before looking up the current UI language.
    let english = legacyMessages?.localizedString(forKey: key, value: key, table: "LegacyMessages") ?? key
    return NSLocalizedString(english, bundle: .main, comment: "")
}
func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: arguments)
}
