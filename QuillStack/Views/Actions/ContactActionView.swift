import SwiftUI
import ContactsUI

struct ContactActionView: UIViewControllerRepresentable {
    let extraction: ContactExtraction
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()

        if let name = extraction.name {
            let parts = name.split(separator: " ", maxSplits: 1)
            contact.givenName = String(parts.first ?? "")
            if parts.count > 1 { contact.familyName = String(parts[1]) }
        }

        if let phone = extraction.phone {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))]
        }

        if let email = extraction.email {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }

        if let company = extraction.company {
            contact.organizationName = company
        }

        if let jobTitle = extraction.jobTitle {
            contact.jobTitle = jobTitle
        }

        if let url = extraction.url {
            contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: url as NSString)]
        }

        let vc = CNContactViewController(forNewContact: contact)
        vc.delegate = context.coordinator

        let nav = UINavigationController(rootViewController: vc)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, CNContactViewControllerDelegate {
        let parent: ContactActionView

        init(_ parent: ContactActionView) { self.parent = parent }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            parent.onDismiss()
        }
    }
}
