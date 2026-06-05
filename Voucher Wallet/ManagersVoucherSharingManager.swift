//
//  ManagersVoucherSharingManager.swift
//  Voucher Wallet
//

import CloudKit
import CoreData
import SwiftUI
import UIKit

extension Notification.Name {
    static let voucherDidChange = Notification.Name("voucherDidChange")
    static let voucherSharingDidChange = Notification.Name("voucherSharingDidChange")
    static let voucherShareAccepted = Notification.Name("voucherShareAccepted")
    static let voucherRemoteStoreDidChange = Notification.Name("voucherRemoteStoreDidChange")
    static let voucherExpensesDidChange = Notification.Name("voucherExpensesDidChange")
}

private extension CKShare {
    var hasInvitedParticipants: Bool {
        participants.contains { $0.role != .owner }
    }
}

final class DismissAwareCloudSharingController: UICloudSharingController {
    var onDidDisappear: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onDidDisappear?()
    }
}

@MainActor
@Observable
final class VoucherSharingManager {
    let persistence: SharedModelContainer
    var lastErrorMessage: String?
    var sharingStatusMessage: String?
    private var pendingParticipantResolutionObjectIDs = Set<NSManagedObjectID>()
    private var isRemovingReceivedShare = false
    private var receivedShareRemovalQueue: [ReceivedShareRemoval] = []

    nonisolated static let identityDefaultsKey = "sharedExpenseDisplayName"
    nonisolated static let authorIdentifierKey = "sharedExpenseAuthorIdentifier"
    private let sharingDiagnosticKey = "lastCloudSharingDiagnostic"
    private let sharingOperationActiveKey = "cloudSharingOperationActive"
    private let shareMetadataRetryDelays: [TimeInterval] = [0.0, 1.0, 3.0, 6.0, 12.0]
    nonisolated private static let storedShareZonesKey = "voucherShareZonesByVoucherID"

    private struct ReceivedShareRemoval {
        let zoneID: CKRecordZone.ID
        let voucherID: UUID
        let sharedStore: NSPersistentStore
        let onFinished: (() -> Void)?
        var attempt: Int
    }

    private struct StoredShareZone: Codable {
        let zoneName: String
        let ownerName: String

        nonisolated init(zoneID: CKRecordZone.ID) {
            zoneName = zoneID.zoneName
            ownerName = zoneID.ownerName
        }

        nonisolated var zoneID: CKRecordZone.ID {
            CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        }
    }

    init(persistence: SharedModelContainer) {
        self.persistence = persistence
        if UserDefaults.standard.bool(forKey: sharingOperationActiveKey) {
            let diagnostic = UserDefaults.standard.string(forKey: sharingDiagnosticKey) ?? "étape inconnue"
            debugLog("Dernier partage interrompu. Dernière étape connue : \(diagnostic)")
            markSharingOperationEnded()
        }
    }

    var storedDisplayName: String {
        NSUbiquitousKeyValueStore.default.string(forKey: Self.identityDefaultsKey)
            ?? UserDefaults.standard.string(forKey: Self.identityDefaultsKey)
            ?? ""
    }

    var authorIdentifier: String {
        if let existing = NSUbiquitousKeyValueStore.default.string(forKey: Self.authorIdentifierKey) {
            return existing
        }
        let identifier = UUID().uuidString
        NSUbiquitousKeyValueStore.default.set(identifier, forKey: Self.authorIdentifierKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        return identifier
    }

    func saveDisplayName(_ value: String) {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(name, forKey: Self.identityDefaultsKey)
        NSUbiquitousKeyValueStore.default.set(name, forKey: Self.identityDefaultsKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func markSharingStep(_ step: String) {
        UserDefaults.standard.set(step, forKey: sharingDiagnosticKey)
        UserDefaults.standard.set(true, forKey: sharingOperationActiveKey)
    }

    func beginSharingInitialization() {
        sharingStatusMessage = "Configuration du partage"
        markSharingStep("configuration du partage")
    }

    func markSharingOperationEnded() {
        UserDefaults.standard.set(false, forKey: sharingOperationActiveKey)
    }

    func rememberShareZone(_ zoneID: CKRecordZone.ID, for voucherID: UUID) {
        Self.rememberShareZone(zoneID, for: voucherID)
    }

    nonisolated static func rememberShareZone(_ zoneID: CKRecordZone.ID, for voucherID: UUID) {
        var zones = storedShareZones()
        zones[voucherID.uuidString] = StoredShareZone(zoneID: zoneID)
        saveStoredShareZones(zones)
    }

    nonisolated static func storedShareZone(for voucherID: UUID) -> CKRecordZone.ID? {
        storedShareZones()[voucherID.uuidString]?.zoneID
    }

    nonisolated private static func forgetShareZone(for voucherID: UUID) {
        var zones = storedShareZones()
        zones.removeValue(forKey: voucherID.uuidString)
        saveStoredShareZones(zones)
    }

    nonisolated private static func storedShareZones() -> [String: StoredShareZone] {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: storedShareZonesKey),
              let zones = try? JSONDecoder().decode([String: StoredShareZone].self, from: data) else {
            return [:]
        }
        return zones
    }

    nonisolated private static func saveStoredShareZones(_ zones: [String: StoredShareZone]) {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
        if zones.isEmpty {
            defaults.removeObject(forKey: storedShareZonesKey)
            return
        }
        if let data = try? JSONEncoder().encode(zones) {
            defaults.set(data, forKey: storedShareZonesKey)
        }
    }

    nonisolated static func isCloudKitShareURL(_ url: URL) -> Bool {
        if let scheme = url.scheme?.lowercased(),
           scheme == "ckshare" || scheme == "cloudkit-share" {
            return true
        }

        if let host = url.host?.lowercased(),
           host == "icloud.com" || host.hasSuffix(".icloud.com") {
            let shareHint = [
                url.path,
                url.query,
                url.fragment
            ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

            return shareHint.contains("share") || shareHint.contains("ckshare")
        }

        return url.absoluteString.lowercased().contains("ckshare")
    }

    func share(for voucher: Voucher) -> CKShare? {
        guard !voucher.objectID.isTemporaryID else { return nil }
        let share = try? persistence.container.fetchShares(matching: [voucher.objectID])[voucher.objectID]
        if let share, let voucherID = voucher.safeID {
            rememberShareZone(share.recordID.zoneID, for: voucherID)
        }
        return share
    }

    func share(for objectID: NSManagedObjectID) async throws -> CKShare? {
        guard !objectID.isTemporaryID else { return nil }
        let container = persistence.container
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let share = try container.fetchShares(matching: [objectID])[objectID]
                    continuation.resume(returning: share)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func refreshShareState(for voucher: Voucher, delays: [TimeInterval] = [1.0, 3.0, 8.0]) {
        guard !voucher.isReceivedShare else { return }
        let objectID = voucher.objectID

        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    guard let voucher = try? self.persistence.container.viewContext.existingObject(with: objectID) as? Voucher else {
                        return
                    }
                    if let share = self.share(for: voucher), share.hasInvitedParticipants {
                        self.pendingParticipantResolutionObjectIDs.remove(voucher.objectID)
                        self.markSharingStarted(for: voucher)
                    }
                }
            }
        }
    }

    func reconcileOwnedSharingStates() {
        guard let privateStore = persistence.privateStore else { return }

        let request = Voucher.fetchRequest()
        request.affectedStores = [privateStore]
        request.predicate = NSPredicate(format: "sharingStartedAt != nil")

        guard let sharedVouchers = try? persistence.container.viewContext.fetch(request),
              !sharedVouchers.isEmpty else {
            return
        }

        let objectIDs = sharedVouchers.map(\.objectID)
        guard let shares = try? persistence.container.fetchShares(matching: objectIDs) else {
            return
        }
        var stoppedVoucherIDs: [UUID] = []

        for voucher in sharedVouchers {
            let voucherID = voucher.safeID
            if let share = shares[voucher.objectID], share.hasInvitedParticipants {
                pendingParticipantResolutionObjectIDs.remove(voucher.objectID)
                continue
            }

            if pendingParticipantResolutionObjectIDs.contains(voucher.objectID),
               let startedAt = voucher.sharingStartedAt,
               Date().timeIntervalSince(startedAt) < 120 {
                continue
            }

            if shares[voucher.objectID] != nil {
                voucher.sharingStartedAt = nil
                pendingParticipantResolutionObjectIDs.remove(voucher.objectID)
                if let voucherID {
                    stoppedVoucherIDs.append(voucherID)
                }
            } else {
                if let startedAt = voucher.sharingStartedAt,
                   Date().timeIntervalSince(startedAt) < 120 {
                    continue
                }
                voucher.sharingStartedAt = nil
                pendingParticipantResolutionObjectIDs.remove(voucher.objectID)
                if let voucherID {
                    stoppedVoucherIDs.append(voucherID)
                }
            }
        }

        guard !stoppedVoucherIDs.isEmpty else { return }

        try? persistence.container.viewContext.save()
        for voucherID in stoppedVoucherIDs {
            NotificationCenter.default.post(name: .voucherDidChange, object: voucherID)
            NotificationCenter.default.post(name: .voucherSharingDidChange, object: voucherID)
        }
        WidgetReloader.reloadAllWidgets()
    }

    func reconcileSharingStates() {
        reconcileOwnedSharingStates()
    }

    func accept(_ metadata: CKShare.Metadata) {
        guard let sharedStore = persistence.sharedStore else {
            lastErrorMessage = "Le stockage iCloud partagé n'est pas disponible."
            sharingStatusMessage = "Ajout impossible"
            return
        }
        let manager = self
        sharingStatusMessage = "Ajout du bon partagé..."
        persistence.container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            Task { @MainActor in
                if let error {
                    manager.handleShareAcceptanceError(error)
                    manager.sharingStatusMessage = "Acceptation échouée"
                } else {
                    manager.sharingStatusMessage = "Synchronisation du bon partagé..."
                    manager.refreshAfterAcceptedShare()
                    manager.waitForAcceptedShareImport()
                    WidgetReloader.reloadAllWidgets()
                }
            }
        }
    }

    private func handleShareAcceptanceError(_ error: Error) {
        debugLog("Erreur lors de l'acceptation du partage CloudKit: \(error.localizedDescription)")

        if isSharedDatabaseZoneInitializationError(error) {
            persistence.markSharedStoreForResetOnNextLaunch(reason: "acceptation-partage")
            lastErrorMessage = """
            Impossible d'accepter ce partage iCloud pour le moment.

            Le stockage iCloud partagé local doit être réinitialisé. Fermez puis relancez Mes bons d'achat, puis demandez à votre ami de renvoyer l'invitation.

            Vérifiez aussi que vous utilisez tous les deux la même version de l'app, par exemple toutes les deux via TestFlight/App Store ou toutes les deux via Xcode.
            """
            return
        }

        lastErrorMessage = "Impossible d'accepter le partage : \(error.localizedDescription)"
    }

    private func isSharedDatabaseZoneInitializationError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("only shared zones can be accessed in the shared db") ||
            message.contains("mirroring delegate never successfully initialized")
    }

    func acceptShareURLIfPossible(_ url: URL) -> Bool {
        guard Self.isCloudKitShareURL(url) else {
            return false
        }

        sharingStatusMessage = "Ouverture de l'invitation iCloud..."
        fetchShareMetadata(for: url, attempt: 0)
        return true
    }

    private func fetchShareMetadata(for url: URL, attempt: Int) {
        let delay = shareMetadataRetryDelays[min(attempt, shareMetadataRetryDelays.count - 1)]
        let work = { [weak self] in
            _ = Task { @MainActor in
                self?.performShareMetadataFetch(for: url, attempt: attempt)
            }
        }

        if delay > 0 {
            sharingStatusMessage = "Ouverture de l'invitation iCloud..."
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                work()
            }
        } else {
            work()
        }
    }

    private func performShareMetadataFetch(for url: URL, attempt: Int) {
        let container = CKContainer(identifier: SharedModelContainer.cloudKitContainerIdentifier)
        container.fetchShareMetadatas(for: [url]) { [weak self] result in
            guard let manager = self else { return }
            Task { @MainActor in
                manager.handleShareMetadataResult(result, for: url, attempt: attempt)
            }
        }
    }

    private func handleShareMetadataResult(
        _ result: Result<[URL: Result<CKShare.Metadata, Error>], Error>,
        for url: URL,
        attempt: Int
    ) {
        switch result {
        case .success(let values):
            guard let metadataResult = values[url] else {
                retryShareMetadataFetch(
                    for: url,
                    attempt: attempt,
                    finalMessage: "Lien iCloud reçu, mais aucune métadonnée de partage n'a été retournée."
                )
                return
            }
            switch metadataResult {
            case .success(let metadata):
                accept(metadata)
            case .failure(let error):
                retryShareMetadataFetch(
                    for: url,
                    attempt: attempt,
                    finalMessage: "Impossible de lire le partage iCloud : \(error.localizedDescription)"
                )
            }
        case .failure(let error):
            retryShareMetadataFetch(
                for: url,
                attempt: attempt,
                finalMessage: "Impossible de lire le lien iCloud : \(error.localizedDescription)"
            )
        }
    }

    private func retryShareMetadataFetch(for url: URL, attempt: Int, finalMessage: String) {
        let nextAttempt = attempt + 1
        guard nextAttempt < shareMetadataRetryDelays.count else {
            lastErrorMessage = finalMessage
            sharingStatusMessage = "Lecture du partage échouée"
            return
        }

        sharingStatusMessage = "Ouverture de l'invitation iCloud..."
        fetchShareMetadata(for: url, attempt: nextAttempt)
    }

    func refreshAfterAcceptedShare() {
        for delay in [0.0, 0.5, 1.5, 3.0, 6.0, 12.0, 25.0, 45.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.persistence.cloudSyncCoordinator.processPersistentHistory(reason: "accepted-share-history")
                    NotificationCenter.default.post(name: .voucherShareAccepted, object: nil)
                }
            }
        }
    }

    private func waitForAcceptedShareImport() {
        for delay in [0.5, 1.5, 3.0, 6.0, 12.0, 25.0, 45.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.notifyIfSharedStoreContainsVouchers(reason: "accepted-share-visible-\(delay)")
                }
            }
        }
    }

    private func notifyIfSharedStoreContainsVouchers(reason: String) {
        guard let sharedStore = persistence.sharedStore else { return }

        let context = persistence.container.viewContext
        let request = Voucher.fetchRequest()
        request.affectedStores = [sharedStore]
        request.includesPendingChanges = true
        request.fetchLimit = 1

        do {
            try context.setQueryGenerationFrom(.current)
            let count = try context.count(for: request)
            debugLog("Partage reçu - lecture store partagé (\(reason)): \(count) bon(s)")
            guard count > 0 else { return }
            sharingStatusMessage = nil
            context.processPendingChanges()
            NotificationCenter.default.post(name: .voucherShareAccepted, object: nil)
            NotificationCenter.default.post(name: .voucherRemoteStoreDidChange, object: nil)
            WidgetReloader.reloadAllWidgets()
        } catch {
            debugLog("Partage reçu - lecture store partagé impossible (\(reason)): \(error.localizedDescription)")
        }
    }

    func createShare(for objectID: NSManagedObjectID) async throws -> (share: CKShare, container: CKContainer) {
        markSharingStep("chargement du bon")
        let persistentContainer = persistence.container
        let cloudContainerIdentifier = SharedModelContainer.cloudKitContainerIdentifier

        markSharingStep("création du partage CloudKit")
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = persistentContainer.newBackgroundContext()
            backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            backgroundContext.transactionAuthor = "VoucherWalletSharePreparation"
            backgroundContext.perform {
                do {
                    guard let voucher = try backgroundContext.existingObject(with: objectID) as? Voucher else {
                        continuation.resume(throwing: CocoaError(.fileReadNoSuchFile))
                        return
                    }
                    guard let voucherID = voucher.safeID else {
                        continuation.resume(throwing: CocoaError(.fileReadCorruptFile))
                        return
                    }

                    let storeName = voucher.storeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let title = storeName.isEmpty ? "Bon d'achat" : "Bon \(storeName)"

                    if voucher.sharingStartedAt == nil {
                        let objectsNeedingPermanentIDs = ([voucher] + voucher.activeExpensesList).filter(\.objectID.isTemporaryID)
                        if !objectsNeedingPermanentIDs.isEmpty {
                            try backgroundContext.obtainPermanentIDs(for: objectsNeedingPermanentIDs)
                        }
                        try backgroundContext.save()
                    }

                    persistentContainer.share([voucher] + voucher.activeExpensesList, to: nil) { _, share, cloudContainer, error in
                        if let error {
                            debugLog("Erreur lors de la préparation du partage CloudKit: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                            return
                        }
                        guard let share else {
                            debugLog("Erreur lors de la préparation du partage CloudKit: CKShare absent")
                            continuation.resume(throwing: CocoaError(.fileWriteUnknown))
                            return
                        }
                        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
                        share.publicPermission = .none
                        Self.rememberShareZone(share.recordID.zoneID, for: voucherID)
                        let resolvedContainer = cloudContainer ?? CKContainer(identifier: cloudContainerIdentifier)
                        continuation.resume(returning: (share, resolvedContainer))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func shareTitle(for voucher: Voucher) -> String {
        let storeName = voucher.storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !storeName.isEmpty else { return "Bon d'achat" }
        return "Bon \(storeName)"
    }

    func configure(_ share: CKShare, for voucher: Voucher) {
        configure(share, title: shareTitle(for: voucher))
    }

    func configure(_ share: CKShare, title: String) {
        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
        share.publicPermission = .none
        debugLog("Titre du partage iCloud configuré: \(title)")
    }

    func persistShareTitleIfNeeded(_ share: CKShare, for voucher: Voucher) {
        configure(share, for: voucher)
        guard let privateStore = persistence.privateStore else { return }
        persistence.container.persistUpdatedShare(share, in: privateStore) { _, error in
            if let error {
                debugLog("Impossible d'enregistrer le titre du partage: \(error.localizedDescription)")
            }
        }
    }

    func removeReceivedVoucher(
        _ voucher: Voucher,
        after delay: TimeInterval = 0,
        onFinished: (() -> Void)? = nil
    ) {
        guard let share = share(for: voucher),
              let sharedStore = persistence.sharedStore,
              let voucherID = voucher.safeID else {
            return
        }
        let removal = ReceivedShareRemoval(
            zoneID: share.recordID.zoneID,
            voucherID: voucherID,
            sharedStore: sharedStore,
            onFinished: onFinished,
            attempt: 1
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.receivedShareRemovalQueue.append(removal)
            self.processNextReceivedShareRemoval()
        }
    }

    private func processNextReceivedShareRemoval() {
        guard !isRemovingReceivedShare, !receivedShareRemovalQueue.isEmpty else { return }

        isRemovingReceivedShare = true
        var removal = receivedShareRemovalQueue.removeFirst()
        persistence.container.purgeObjectsAndRecordsInZone(
            with: removal.zoneID,
            in: removal.sharedStore
        ) { _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRemovingReceivedShare = false

                if let error, self.isCloudKitPendingRequestError(error), removal.attempt < 4 {
                    removal.attempt += 1
                    let retryDelay = TimeInterval(removal.attempt * 2)
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                        guard let self else { return }
                        self.receivedShareRemovalQueue.insert(removal, at: 0)
                        self.processNextReceivedShareRemoval()
                    }
                    return
                }

                if let error {
                    self.lastErrorMessage = "Impossible de quitter le partage pour le moment. Réessayez dans quelques secondes."
                    debugLog("Erreur lors de la sortie du partage: \(error.localizedDescription)")
                } else {
                    FavoritesManager.deletePersonalPreference(for: removal.voucherID, in: self.persistence.container.viewContext)
                    Self.forgetShareZone(for: removal.voucherID)
                }
                self.persistence.requestCloudRefresh()
                NotificationCenter.default.post(name: .voucherDidChange, object: removal.voucherID)
                NotificationCenter.default.post(name: .voucherSharingDidChange, object: removal.voucherID)
                WidgetReloader.reloadAllWidgets()
                removal.onFinished?()
                self.processNextReceivedShareRemoval()
            }
        }
    }

    private func isCloudKitPendingRequestError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("already a pending request") ||
            message.contains("nscloudkitmirroringexportrequest") ||
            message.contains("was cancelled because there is already")
    }

    func revokeIfNeeded(for voucher: Voucher) {
        guard let privateStore = persistence.privateStore else { return }
        guard let voucherID = voucher.safeID else { return }
        let zoneID = share(for: voucher)?.recordID.zoneID ?? Self.storedShareZone(for: voucherID)
        guard let zoneID else { return }

        voucher.sharingStartedAt = nil
        try? persistence.container.viewContext.save()
        NotificationCenter.default.post(name: .voucherDidChange, object: voucherID)
        NotificationCenter.default.post(name: .voucherSharingDidChange, object: voucherID)
        persistence.container.purgeObjectsAndRecordsInZone(
            with: zoneID,
            in: privateStore
        ) { _, error in
            if let error {
                debugLog("Erreur lors de la purge de la zone CloudKit du bon supprimé: \(error.localizedDescription)")
            } else {
                Self.forgetShareZone(for: voucherID)
            }
            Task { @MainActor in
                WidgetReloader.reloadAllWidgets()
            }
        }
    }

    func markSharingStopped(for voucher: Voucher) {
        guard let voucherID = voucher.safeID else { return }
        voucher.sharingStartedAt = nil
        pendingParticipantResolutionObjectIDs.remove(voucher.objectID)
        try? persistence.container.viewContext.save()
        NotificationCenter.default.post(name: .voucherDidChange, object: voucherID)
        NotificationCenter.default.post(name: .voucherSharingDidChange, object: voucherID)
        WidgetReloader.reloadAllWidgets()
    }

    func markSharingStarted(for voucher: Voucher, pendingParticipants: Bool = false) {
        guard let voucherID = voucher.safeID else { return }
        voucher.sharingStartedAt = Date()
        if pendingParticipants {
            pendingParticipantResolutionObjectIDs.insert(voucher.objectID)
        }
        try? persistence.container.viewContext.save()
        NotificationCenter.default.post(name: .voucherDidChange, object: voucherID)
        NotificationCenter.default.post(name: .voucherSharingDidChange, object: voucherID)
        WidgetReloader.reloadAllWidgets()
    }

    func restrictParticipantsToOwnerManagedInvites(in share: CKShare) {
        var didChangeShare = false
        if share.publicPermission != .none {
            share.publicPermission = .none
            didChangeShare = true
        }
        for participant in share.participants where participant.role != .owner {
            if participant.permission != .readWrite {
                participant.permission = .readWrite
                didChangeShare = true
            }
            if participant.role != .privateUser {
                participant.role = .privateUser
                didChangeShare = true
            }
        }

        guard didChangeShare, let privateStore = persistence.privateStore else { return }
        persistence.container.persistUpdatedShare(share, in: privateStore) { _, error in
            if let error {
                debugLog("Impossible de restreindre les invitations du partage: \(error.localizedDescription)")
            }
        }
    }
}

struct CloudVoucherSharingPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var isPreparing: Bool
    let voucher: Voucher
    let manager: VoucherSharingManager

    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager, isPresented: $isPresented, isPreparing: $isPreparing)
    }

    func makeUIViewController(context: Context) -> CloudSharingHostController {
        let controller = CloudSharingHostController()
        controller.coordinator = context.coordinator
        context.coordinator.hostController = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: CloudSharingHostController, context: Context) {
        context.coordinator.manager = manager
        context.coordinator.isPresented = $isPresented
        context.coordinator.isPreparing = $isPreparing
        uiViewController.voucher = voucher
        uiViewController.manager = manager
        if !isPresented {
            uiViewController.didFinishPresentation()
        }
        uiViewController.presentIfNeeded(isPresented: isPresented)
    }

    final class CloudSharingHostController: UIViewController {
        var voucher: Voucher?
        var manager: VoucherSharingManager?
        weak var coordinator: Coordinator?
        private var isPresentingCloudSharing = false

        func presentIfNeeded(isPresented: Bool) {
            if isPresented, isPresentingCloudSharing, presentedViewController == nil {
                didFinishPresentation()
                coordinator?.activeCloudSharingController = nil
            }

            guard isViewLoaded,
                  view.window != nil,
                  isPresented,
                  !isPresentingCloudSharing,
                  presentedViewController == nil else { return }
            presentCloudSharingController()
        }

        private func presentCloudSharingController() {
            guard let voucher, let manager, let coordinator else { return }
            isPresentingCloudSharing = true
            coordinator.beginPresentation()

            let objectID = voucher.objectID
            if voucher.isInActiveShare {
                coordinator.isPreparing.wrappedValue = true
                manager.beginSharingInitialization()
                manager.markSharingStep("chargement du partage existant")
                Task { @MainActor [weak self, manager, coordinator, weak voucher] in
                    do {
                        guard let share = try await manager.share(for: objectID) else {
                            coordinator.isPreparing.wrappedValue = false
                            manager.lastErrorMessage = "Le partage iCloud n'est pas encore disponible. Réessayez dans quelques secondes."
                            coordinator.isPresented.wrappedValue = false
                            coordinator.didFinishPresentation()
                            return
                        }
                        guard let self, let voucher else { return }
                        coordinator.isPreparing.wrappedValue = false
                        manager.markSharingStep("ouverture du partage existant")
                        manager.configure(share, for: voucher)
                        let controller = DismissAwareCloudSharingController(
                            share: share,
                            container: CKContainer(identifier: SharedModelContainer.cloudKitContainerIdentifier)
                        )
                        self.configure(controller, coordinator: coordinator)
                    } catch {
                        coordinator.isPreparing.wrappedValue = false
                        manager.lastErrorMessage = "Impossible d'ouvrir le partage : \(error.localizedDescription)"
                        coordinator.isPresented.wrappedValue = false
                        coordinator.didFinishPresentation()
                    }
                }
            } else {
                coordinator.isPreparing.wrappedValue = true
                manager.beginSharingInitialization()
                manager.markSharingStep("préparation du nouveau partage")
                Task { @MainActor [weak self, manager, coordinator, weak voucher] in
                    do {
                        let preparedShare = try await manager.createShare(for: objectID)
                        guard let self else { return }
                        if let voucher {
                            manager.markSharingStarted(for: voucher, pendingParticipants: true)
                        }
                        coordinator.isPreparing.wrappedValue = false
                        manager.markSharingStep("ouverture du nouveau partage")
                        let controller = DismissAwareCloudSharingController(
                            share: preparedShare.share,
                            container: preparedShare.container
                        )
                        self.configure(controller, coordinator: coordinator)
                    } catch {
                        coordinator.isPreparing.wrappedValue = false
                        manager.lastErrorMessage = "Impossible de partager le bon : \(error.localizedDescription)"
                        coordinator.isPresented.wrappedValue = false
                        coordinator.didFinishPresentation()
                    }
                }
            }
        }

        private func configure(
            _ controller: DismissAwareCloudSharingController,
            coordinator: Coordinator
        ) {
            controller.delegate = coordinator
            coordinator.activeCloudSharingController = controller
            controller.availablePermissions = []
            controller.presentationController?.delegate = coordinator
            controller.popoverPresentationController?.sourceView = view
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 1,
                height: 1
            )
            controller.onDidDisappear = { [weak coordinator, weak controller] in
                guard let controller else { return }
                coordinator?.cloudSharingControllerDidTemporarilyDisappear(controller)
            }

            present(controller, animated: true) { [weak coordinator] in
                coordinator?.manager.markSharingStep("fenêtre de partage affichée")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self, weak coordinator] in
                guard let self, self.isPresentingCloudSharing else { return }
                coordinator?.manager.markSharingOperationEnded()
            }
        }

        func didFinishPresentation() {
            isPresentingCloudSharing = false
        }
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        var manager: VoucherSharingManager
        var isPresented: Binding<Bool>
        var isPreparing: Binding<Bool>
        weak var hostController: CloudSharingHostController?
        var activeCloudSharingController: UICloudSharingController?
        private var didCompletePresentation = false
        private var isUserDismissingPresentation = false

        init(
            manager: VoucherSharingManager,
            isPresented: Binding<Bool>,
            isPreparing: Binding<Bool>
        ) {
            self.manager = manager
            self.isPresented = isPresented
            self.isPreparing = isPreparing
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            guard let voucher = hostController?.voucher else {
                return "Bon d'achat"
            }
            let title = manager.shareTitle(for: voucher)
            debugLog("Titre demandé par UICloudSharingController: \(title)")
            return title
        }

        func itemType(for csc: UICloudSharingController) -> String? {
            "Bon d'achat de Mes bons d'achat"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            finishCloudSharingController(csc, didSaveShare: true)
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            finishCloudSharingController(csc, forceStopped: true)
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            debugLog("Erreur lors de l'enregistrement du partage CloudKit: \(error.localizedDescription)")
            manager.lastErrorMessage = "Impossible de partager le bon : \(error.localizedDescription)"
            finishCloudSharingController(csc)
        }

        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            isUserDismissingPresentation = true
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            finishCloudSharingController(activeCloudSharingController)
        }

        func cloudSharingControllerDidTemporarilyDisappear(_ csc: UICloudSharingController) {
            guard !didCompletePresentation, let voucher = hostController?.voucher else { return }
            manager.markSharingStarted(for: voucher, pendingParticipants: true)
            manager.refreshShareState(for: voucher)
            isPresented.wrappedValue = false
            isPreparing.wrappedValue = false
            manager.markSharingOperationEnded()
            didFinishPresentation()
        }

        func beginPresentation() {
            didCompletePresentation = false
            isUserDismissingPresentation = false
            activeCloudSharingController = nil
        }

        func didFinishPresentation() {
            hostController?.didFinishPresentation()
        }

        private func finishCloudSharingController(
            _ csc: UICloudSharingController?,
            forceStopped: Bool = false,
            didSaveShare: Bool = false
        ) {
            guard !didCompletePresentation else { return }
            didCompletePresentation = true

            let currentShare = csc?.share
            let hasInvitedParticipants = currentShare?.hasInvitedParticipants == true
            isPresented.wrappedValue = false
            isPreparing.wrappedValue = false
            manager.markSharingOperationEnded()

            if let share = currentShare {
                manager.restrictParticipantsToOwnerManagedInvites(in: share)
                if let voucher = hostController?.voucher, let voucherID = voucher.safeID {
                    manager.rememberShareZone(share.recordID.zoneID, for: voucherID)
                }
            }

            if let voucher = hostController?.voucher {
                if forceStopped {
                    manager.markSharingStopped(for: voucher)
                } else if didSaveShare || currentShare != nil {
                    manager.markSharingStarted(for: voucher)
                    manager.refreshShareState(for: voucher)
                }
            } else {
                WidgetReloader.reloadAllWidgets()
            }

            if didSaveShare || hasInvitedParticipants {
                manager.markSharingStep("partage enregistré, retour à la gestion")
            }
            activeCloudSharingController = nil
            didFinishPresentation()
        }
    }
}

final class CloudSharingAppDelegate: NSObject, UIApplicationDelegate {
    static weak var activeSharingManager: VoucherSharingManager?
    private static var pendingShareMetadata: [CKShare.Metadata] = []
    private static var pendingShareURLs: [URL] = []

    var sharingManager: VoucherSharingManager? {
        didSet {
            Self.activeSharingManager = sharingManager
            guard let sharingManager else { return }

            let pendingMetadata = Self.pendingShareMetadata
            let pendingURLs = Self.pendingShareURLs
            Self.pendingShareMetadata.removeAll()
            Self.pendingShareURLs.removeAll()

            for metadata in pendingMetadata {
                Task { @MainActor in
                    sharingManager.accept(metadata)
                }
            }
            for url in pendingURLs {
                Task { @MainActor in
                    _ = sharingManager.acceptShareURLIfPossible(url)
                }
            }
        }
    }

    @MainActor
    static func accept(_ metadata: CKShare.Metadata) {
        if let activeSharingManager {
            activeSharingManager.accept(metadata)
        } else {
            pendingShareMetadata.append(metadata)
        }
    }

    @MainActor
    static func acceptShareURLIfPossible(_ url: URL) -> Bool {
        guard VoucherSharingManager.isCloudKitShareURL(url) else { return false }
        guard let activeSharingManager else {
            pendingShareURLs.append(url)
            return true
        }
        return activeSharingManager.acceptShareURLIfPossible(url)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        queueLaunchShareURLIfNeeded(from: launchOptions)
        queueLaunchRemoteNotificationIfNeeded(from: launchOptions)
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await Self.handleCloudKitRemoteNotification(
                userInfo,
                reason: "remote-notification",
                manager: sharingManager
            )
            completionHandler(.newData)
        }
    }

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            sharingManager?.persistence.requestCloudRefresh()
            completionHandler(.noData)
        }
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        Task { @MainActor in
            _ = Self.acceptShareURLIfPossible(url)
        }
        return VoucherSharingManager.isCloudKitShareURL(url)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        Task { @MainActor in
            _ = Self.acceptShareURLIfPossible(url)
        }
        return VoucherSharingManager.isCloudKitShareURL(url)
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            Self.accept(cloudKitShareMetadata)
        }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = CloudSharingSceneDelegate.self
        return configuration
    }

    private func queueLaunchShareURLIfNeeded(from launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard let launchOptions else { return }

        if let url = launchOptions[.url] as? URL {
            Task { @MainActor in
                _ = Self.acceptShareURLIfPossible(url)
            }
        }

        guard let userActivityDictionary = launchOptions[.userActivityDictionary] as? [AnyHashable: Any] else {
            return
        }

        for value in userActivityDictionary.values {
            guard let userActivity = value as? NSUserActivity,
                  userActivity.activityType == NSUserActivityTypeBrowsingWeb,
                  let url = userActivity.webpageURL else {
                continue
            }
            Task { @MainActor in
                _ = Self.acceptShareURLIfPossible(url)
            }
        }
    }

    private func queueLaunchRemoteNotificationIfNeeded(from launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] else {
            return
        }

        Task { @MainActor in
            await Self.handleCloudKitRemoteNotification(
                userInfo,
                reason: "launch-remote-notification",
                manager: sharingManager
            )
        }
    }

    @MainActor
    private static func handleCloudKitRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        reason: String,
        manager: VoucherSharingManager?
    ) async {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            debugLog("Notification distante reçue sans payload CloudKit (\(reason))")
            return
        }

        debugLog("Notification CloudKit reçue (\(reason)): type=\(notification.notificationType.rawValue), subscription=\(notification.subscriptionID ?? "inconnue")")
        guard let manager else { return }
        manager.persistence.requestCloudRefresh(minimumInterval: 0)
        manager.persistence.scheduleCloudRefreshes(delays: [1.0, 3.0, 6.0])
        manager.persistence.scheduleCloudResets(delays: [2.0, 5.0])
    }
}

final class CloudSharingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        Task { @MainActor in
            if let metadata = connectionOptions.cloudKitShareMetadata {
                CloudSharingAppDelegate.accept(metadata)
                return
            }

            for userActivity in connectionOptions.userActivities {
                if handle(userActivity) { return }
            }
            for urlContext in connectionOptions.urlContexts {
                if CloudSharingAppDelegate.acceptShareURLIfPossible(urlContext.url) {
                    return
                }
            }
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        Task { @MainActor in
            _ = handle(userActivity)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        Task { @MainActor in
            for context in URLContexts {
                if CloudSharingAppDelegate.acceptShareURLIfPossible(context.url) {
                    return
                }
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            CloudSharingAppDelegate.accept(cloudKitShareMetadata)
        }
    }

    @MainActor
    private func handle(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        return CloudSharingAppDelegate.acceptShareURLIfPossible(url)
    }
}
