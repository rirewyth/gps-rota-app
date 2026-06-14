import UIKit
import Flutter
import MessageUI
import flutter_local_notifications
import flutter_background_service_ios

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, MFMessageComposeViewControllerDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // KRİTİK: flutter_background_service_ios'un iOS'ta ikinci bir Flutter motoru
    // açmasını engelle. Bu olmadan SIGSEGV (swift_getObjectType) çökmesi yaşanır.
    // Dart tarafında IosConfiguration(autoStart: false) olsa bile, eski bir build'de
    // UserDefaults'a "auto_start = true" yazıldıysa ikinci motor açılabilir.
    // Bu satır her açılışta bunu sıfırlar.
    UserDefaults.standard.set(false, forKey: "auto_start")
    UserDefaults.standard.synchronize()
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let smsChannel = FlutterMethodChannel(name: "com.rotaplus.emniyetteyim/sms",
                                          binaryMessenger: controller.binaryMessenger)
    
    smsChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      if call.method == "sendSms" {
        guard let args = call.arguments as? [String: Any],
              let phone = args["phone"] as? String,
              let message = args["message"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
          return
        }
        self?.sendSms(phone: phone, message: message, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private var flutterResult: FlutterResult?

  func sendSms(phone: String, message: String, result: @escaping FlutterResult) {
    if !MFMessageComposeViewController.canSendText() {
      result(FlutterError(code: "UNAVAILABLE", message: "SMS services are not available", details: nil))
      return
    }
    
    let composeVC = MFMessageComposeViewController()
    composeVC.messageComposeDelegate = self
    composeVC.recipients = [phone]
    composeVC.body = message
    
    self.flutterResult = result
    
    DispatchQueue.main.async {
      let rootVC = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap { $0.windows }
          .first { $0.isKeyWindow }?.rootViewController
          
      if let rootVC = rootVC ?? self.window?.rootViewController {
        rootVC.present(composeVC, animated: true, completion: nil)
      } else {
        self.flutterResult?(false)
        self.flutterResult = nil
      }
    }
  }
  
  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    controller.dismiss(animated: true, completion: nil)
    if result == .sent {
        self.flutterResult?(true)
    } else {
        self.flutterResult?(false)
    }
    self.flutterResult = nil
  }
}
