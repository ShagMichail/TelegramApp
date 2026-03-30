import Foundation

public enum DivoConfig {
    public static let baseURL = URL(string: "https://api-stage.divo.fashion/api")!

    public static let agencyToken = "Ccw5cQAMFzxCttzgpUu69NuJARelHshG78LOAHiPQEjKeMSP93OWsbc110MKc6mf"
    public static let modelToken = "GxelyeqTBVrPAJLWXRXUH4XktoUhu2QLTFfxIvgnvDD9jKBLolF6GDVQQsSzChSF"

    private static let tokenKey = "DivoConfig.customAccessToken"

    public static var accessToken: String {
        get {
            return UserDefaults.standard.string(forKey: tokenKey) ?? agencyToken
        }
        set {
            UserDefaults.standard.set(newValue, forKey: tokenKey)
        }
    }

    public static func resetToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    public static let appPlatform = "ios"
    public static let appVersion = "1.1.1 (912)"
}
