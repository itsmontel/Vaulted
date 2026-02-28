import SwiftUI

// MARK: - Legal Policy Type
enum LegalPolicyType {
    case termsOfService
    case privacyPolicy

    var title: String {
        switch self {
        case .termsOfService: return "Terms of Service"
        case .privacyPolicy: return "Privacy Policy"
        }
    }

    var content: String {
        switch self {
        case .termsOfService: return Self.termsContent
        case .privacyPolicy: return Self.privacyContent
        }
    }

    // MARK: - Terms of Service
    private static let termsContent = """
    VAULTED – TERMS OF SERVICE

    Last updated: February 2025

    1. ACCEPTANCE OF TERMS

    By downloading, installing, or using the Vaulted application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.

    2. DESCRIPTION OF SERVICE

    Vaulted is a voice-first note-taking application that allows you to capture, transcribe, organise, and store voice notes and text notes. The App organises content into categories (Ideas, Work, Journal), provides on-device transcription with content filtering, daily prompts to encourage regular use, optional reminder notifications, optional biometric locking, and subscription-based access to Pro features.

    3. ACCOUNT AND ELIGIBILITY

    You must be at least 13 years of age to use the App. If you are under 18, you represent that you have your parent or guardian's permission to use the App. You are responsible for maintaining the confidentiality of any device passcode or biometric authentication used to access the App.

    4. SUBSCRIPTION AND PAYMENT

    Vaulted Pro is a subscription service that provides full access to the App's features. Subscription options include monthly and yearly plans. A 3-day free trial may be offered for new subscribers. Payment will be charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can manage and cancel subscriptions in your device Settings > Apple ID > Subscriptions. Refunds are handled in accordance with Apple's refund policy.

    5. ACCEPTABLE USE

    You agree not to use the App to:
    • Violate any applicable laws or regulations
    • Infringe on the intellectual property or privacy rights of others
    • Store, transmit, or facilitate illegal content
    • Attempt to circumvent security features, including biometric or passcode protection
    • Reverse engineer, decompile, or disassemble the App
    • Use the App for any purpose that could harm, disable, or overburden the service

    6. INTELLECTUAL PROPERTY

    The App, including its design, features, and content (excluding user-generated content), is owned by the developer and protected by copyright and other intellectual property laws. You retain ownership of your notes and content. By using the App, you grant a limited licence to process your content solely for providing the service (e.g. on-device transcription).

    7. ON-DEVICE PROCESSING

    Transcription and other processing of your voice and text content occurs on your device. This includes automatic content filtering for inappropriate language. The App is designed so that your notes remain under your control. However, you are responsible for backing up your data and understand that data loss may occur.

    8. DISCLAIMER OF WARRANTIES

    THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR SECURE. USE AT YOUR OWN RISK.

    9. LIMITATION OF LIABILITY

    TO THE FULLEST EXTENT PERMITTED BY LAW, THE DEVELOPER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING LOSS OF DATA, ARISING FROM YOUR USE OF THE APP. OUR TOTAL LIABILITY SHALL NOT EXCEED THE AMOUNT YOU PAID FOR THE APP IN THE TWELVE MONTHS PRECEDING THE CLAIM.

    10. CHANGES TO TERMS

    We may modify these Terms at any time. We will notify you of material changes by updating the "Last updated" date or through the App. Continued use of the App after changes constitutes acceptance.

    11. TERMINATION

    You may stop using the App at any time. We may suspend or terminate your access for violation of these Terms. Upon termination, your right to use the App ceases.

    12. GOVERNING LAW

    These Terms are governed by the laws of England and Wales. Any disputes shall be subject to the exclusive jurisdiction of the courts of England and Wales.

    13. CONTACT

    For questions about these Terms, contact us at the support email provided in the App Store listing.
    """

    // MARK: - Privacy Policy
    private static let privacyContent = """
    VAULTED – PRIVACY POLICY

    Last updated: February 2025

    1. INTRODUCTION

    Vaulted ("we", "our", or "the App") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, store, and protect your information when you use the Vaulted application.

    2. INFORMATION WE COLLECT

    • Voice Recordings: Audio you record within the App
    • Text Notes: Notes you type or create
    • Transcripts: On-device transcription of your voice recordings with automatic content filtering
    • Daily Prompt Responses: Your answers to daily prompts, stored with special tags
    • Reminder Data: Dates and times for optional reminder notifications
    • Preferences: Settings such as theme, default save location, security options, and daily prompt streaks
    • Usage Data: Anonymous analytics to improve the App (if enabled)

    3. ON-DEVICE PROCESSING

    Voice transcription is performed entirely on your device using Apple's Speech framework. Your audio and transcripts are not sent to our servers or third parties for processing. Processing happens locally on your iPhone or iPad. The App applies automatic content filtering to transcripts to replace inappropriate language with censored versions (e.g. "f*ck"). This filtering occurs on-device and no unfiltered content leaves your device.

    4. DATA STORAGE

    Your notes, voice recordings, transcripts, daily prompt responses, and reminder settings are stored locally on your device using Core Data. We do not operate cloud servers that store your content. Your data remains on your device unless you choose to export or share it. Daily prompt streaks and preferences are stored locally in your device's user defaults.

    5. BIOMETRIC DATA

    The App uses Face ID or Touch ID for optional locking of private content. Biometric data is managed entirely by Apple's Secure Enclave and is never accessed, stored, or transmitted by the App. We only receive a success/failure signal to grant or deny access.

    6. NOTIFICATIONS

    The App may request permission to send local reminder notifications for notes you choose to set reminders on. These notifications are scheduled locally on your device and do not involve sending data to external servers. You can disable notifications in your device Settings at any time.

    7. SUBSCRIPTION AND PAYMENT

    Subscription purchases are processed by Apple. We do not collect or store your payment details. Apple may provide us with transaction information (e.g. subscription status) necessary to grant access. Please refer to Apple's Privacy Policy for payment-related data handling.

    8. THIRD-PARTY SERVICES

    The App uses:
    • Apple Speech Recognition: For on-device transcription with enhanced accuracy features (audio stays on device)
    • UserNotifications: For optional local reminder notifications (no data sent to servers)
    • StoreKit: For subscription management (handled by Apple)
    • Core Data: For local storage (no third-party involvement)

    We do not sell or share your data with advertisers or data brokers.

    9. DATA RETENTION

    Your data remains on your device until you delete it or uninstall the App. Deleted content may persist in device backups until those backups are overwritten. We do not retain copies of your data on our systems.

    10. DATA SECURITY

    We implement appropriate measures to protect your data, including:
    • Optional biometric or passcode protection for sensitive content
    • Local-only storage (no transmission to external servers for your notes)
    • Secure handling of authentication tokens

    You are responsible for keeping your device secure and using a strong passcode.

    11. YOUR RIGHTS

    You have the right to:
    • Access your data (it is stored on your device)
    • Delete your data (delete notes within the App or uninstall the App)
    • Export your content (using App features if available)
    • Withdraw consent (stop using the App)

    For users in the EEA/UK, you may have additional rights under GDPR. Contact us to exercise these rights.

    12. CHILDREN'S PRIVACY

    The App is not directed at children under 13. We do not knowingly collect data from children. If you believe a child has provided us with personal information, please contact us and we will take steps to delete it.

    13. CHANGES TO THIS POLICY

    We may update this Privacy Policy from time to time. We will notify you of material changes by updating the "Last updated" date or through the App. Continued use constitutes acceptance.

    14. CONTACT

    For privacy-related questions or to exercise your rights, contact us at the support email provided in the App Store listing.
    """
}

// MARK: - Legal Policy Screen
struct LegalPolicyScreen: View {
    let policyType: LegalPolicyType
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(policyType.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeManager.theme.inkPrimary)
                    .lineSpacing(6)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(themeManager.theme.paperBackground)
        .navigationTitle(policyType.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
