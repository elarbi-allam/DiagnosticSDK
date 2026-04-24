import SwiftUI
import UIKit

struct DiagnosticPasswordPrompt: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    
    let title: String
    let message: String
    let placeholder: String
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coordinator = context.coordinator
        
        if !isPresented {
            if uiViewController.presentedViewController != nil {
                uiViewController.dismiss(animated: true)
            }
            coordinator.activeAlert = nil
            coordinator.wasPresented = false
            return
        }
        
        guard !coordinator.wasPresented, coordinator.activeAlert == nil else { return }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = placeholder
            textField.isSecureTextEntry = true
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
        }
        
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { [weak coordinator] _ in
            coordinator?.activeAlert = nil
            coordinator?.wasPresented = false
            isPresented = false
            onCancel()
        }
        
        let confirmAction = UIAlertAction(title: confirmTitle, style: .default) { [weak coordinator] _ in
            let password = alert.textFields?.first?.text ?? ""
            coordinator?.activeAlert = nil
            coordinator?.wasPresented = false
            isPresented = false
            onConfirm(password)
        }
        
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        coordinator.activeAlert = alert
        coordinator.wasPresented = true
        
        DispatchQueue.main.async { [weak coordinator] in
            guard let coordinator else { return }
            guard isPresented, uiViewController.presentedViewController == nil else {
                coordinator.wasPresented = false
                coordinator.activeAlert = nil
                return
            }
            uiViewController.present(alert, animated: true)
        }
    }
    
    final class Coordinator {
        var activeAlert: UIAlertController?
        var wasPresented = false
    }
}
