import Foundation

public enum DivoConfig {
    public static let baseURL = URL(string: "https://api-stage.divo.fashion/api")!

    public static let agencyToken = "Ccw5cQAMFzxCttzgpUu69NuJARelHshG78LOAHiPQEjKeMSP93OWsbc110MKc6mf"
    public static let modelToken = "GxelyeqTBVrPAJLWXRXUH4XktoUhu2QLTFfxIvgnvDD9jKBLolF6GDVQQsSzChSF"

    private static let tokenKey = "DivoConfig.customAccessToken"
    private static let delayKey = "DivoConfig.simulatedDelay"

    public static let tokenDidChangeNotification = Notification.Name("DivoConfig.tokenDidChange")

    public static var accessToken: String {
        get {
            return UserDefaults.standard.string(forKey: tokenKey) ?? agencyToken
        }
        set {
            let oldValue = UserDefaults.standard.string(forKey: tokenKey) ?? agencyToken
            UserDefaults.standard.set(newValue, forKey: tokenKey)
            if newValue != oldValue {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: tokenDidChangeNotification, object: nil)
                }
            }
        }
    }

    public static func resetToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    public static var simulatedDelay: TimeInterval {
        get {
            return UserDefaults.standard.double(forKey: delayKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: delayKey)
        }
    }

    /// true для dev/TF сборок, false для App Store (Apple удаляет mobileprovision при публикации)
    public static let isDebugEnabled: Bool = {
        return Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
    }()

    public static let appPlatform = "ios"
    public static let appVersion = "1.1.1 (912)"
}
