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

    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "dev.flutter.background.refresh"
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

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
      // Find the correct root view controller (iOS 13+ support)
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
