import UIKit
import Flutter
import MessageUI
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, MFMessageComposeViewControllerDelegate {
    
    private var smsResult: FlutterResult?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // ✅ Google Maps API Key
        GMSServices.provideAPIKey("AIzaSyDTIOp1GOA-Fh0js8EkKvLukbm_HXmrEsM") // Replace with your actual API key
        
        // ✅ Flutter View Controller
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // ✅ SMS Channel
        let smsChannel = FlutterMethodChannel(
            name: "com.example.munir_app/sms",
            binaryMessenger: controller.binaryMessenger
        )
        
        smsChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard call.method == "sendSMS" else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            guard let args = call.arguments as? [String: Any],
                  let phoneNumber = args["phoneNumber"] as? String,
                  let message = args["message"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT",
                                    message: "Phone number or message is missing",
                                    details: nil))
                return
            }
            
            self?.sendSMS(phoneNumber: phoneNumber, message: message, result: result)
        }
        
        // ✅ Register plugins
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - SMS Sending Logic
    private func sendSMS(phoneNumber: String, message: String, result: @escaping FlutterResult) {
        if MFMessageComposeViewController.canSendText() {
            let messageController = MFMessageComposeViewController()
            messageController.messageComposeDelegate = self
            messageController.recipients = [phoneNumber]
            messageController.body = message
            
            self.smsResult = result
            
            if let rootViewController = window?.rootViewController {
                rootViewController.present(messageController, animated: true, completion: nil)
            } else {
                result(FlutterError(code: "NO_ROOT_CONTROLLER",
                                    message: "Could not find root view controller",
                                    details: nil))
            }
        } else {
            result(FlutterError(code: "SMS_NOT_AVAILABLE",
                                message: "SMS services are not available on this device",
                                details: nil))
        }
    }
    
    // MARK: - MFMessageComposeViewControllerDelegate
    func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                      didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
        
        switch result {
        case .cancelled:
            smsResult?(FlutterError(code: "SMS_CANCELLED",
                                    message: "SMS was cancelled by user",
                                    details: nil))
        case .sent:
            smsResult?("SMS sent successfully")
        case .failed:
            smsResult?(FlutterError(code: "SMS_SEND_FAILED",
                                    message: "Failed to send SMS",
                                    details: nil))
        @unknown default:
            smsResult?(FlutterError(code: "SMS_UNKNOWN_ERROR",
                                    message: "Unknown SMS error occurred",
                                    details: nil))
        }
        
        smsResult = nil
    }
}
