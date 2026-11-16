import AppKit
import CoreGraphics
import Darwin
import IOKit.pwr_mgt

/// Ekranı gerçekten kilitler ve kullanıcının son girdiden beri boşta kalma süresini verir.
enum ScreenLocker {
    /// Önce `login.framework` içindeki SACLockScreenImmediate (özel API, hemen kilitler),
    /// olmazsa/başarısız olursa ekranı uyutur (bu Mac'te "şifre: hemen" ayarı kilidi sağlar).
    static func lock() {
        typealias LockFn = @convention(c) () -> Int32
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_NOW),
           let symbol = dlsym(handle, "SACLockScreenImmediate") {
            let fn = unsafeBitCast(symbol, to: LockFn.self)
            if fn() == 0 { return }
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    /// Bir uygulama ekranın uyumasını engelliyor mu? (video izleme, görüntülü görüşme, sunum)
    static func displayHeldAwake() -> Bool {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&unmanaged) == kIOReturnSuccess,
              let dict = unmanaged?.takeRetainedValue() as? [String: Int] else { return false }
        return (dict["PreventUserIdleDisplaySleep"] ?? 0) > 0 || (dict["NoDisplaySleepAssertion"] ?? 0) > 0
    }

    /// Kullanıcı bilgisayarı kullanıyor mu? Son girdi `threshold` sn içindeyse evet; ayrıca ekranı
    /// açık tutan bir şey (video, görüşme) varsa ve son girdi 2 dakikadan yeniyse de evet sayılır.
    static func userIsEngaged(threshold: Double) -> Bool {
        let idle = idleSeconds()
        return idle < threshold || (idle < 120 && displayHeldAwake())
    }

    /// Klavye/fare/trackpad'den beri geçen saniye.
    static func idleSeconds() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}
