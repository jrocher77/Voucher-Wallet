//
//  SharedModelContainer.swift
//  Voucher Wallet
//

import CloudKit
@preconcurrency import CoreData
import CryptoKit
import Foundation
#if !WIDGET_EXTENSION
import UIKit
#endif

/// Conteneur Core Data/CloudKit commun à l'application et au widget.
final class SharedModelContainer {
    nonisolated static let appGroupIdentifier = "group.com.jrocher77.voucherwallet"
    nonisolated static let cloudKitContainerIdentifier = "iCloud.jrocher.Voucher-Wallet"
    nonisolated static let privateConfigurationName = "Private"
    nonisolated static let sharedConfigurationName = "Shared"
    nonisolated static let cloudSyncStatusNotificationName = Notification.Name("voucherCloudSyncStatusDidChange")
    nonisolated private static let resetSharedStoreOnNextLaunchKey = "resetSharedCloudStoreOnNextLaunch"
    nonisolated private static let deletedLegacyVoucherIDsKey = "deletedLegacyVoucherIDs"
    nonisolated private static let deletedLegacyVoucherKeysKey = "deletedLegacyVoucherKeys"
    nonisolated private static let migratedLegacyVoucherIDsKey = "migratedLegacyVoucherIDs"
    nonisolated private static let migratedLegacyVoucherKeysKey = "migratedLegacyVoucherKeys"
    nonisolated private static let appGroupStoreFallbackWarningKey = "appGroupStoreFallbackWarningLogged"
    static weak var active: SharedModelContainer?

    let container: NSPersistentCloudKitContainer
    private(set) var cloudSyncCoordinator: CloudSyncCoordinator!
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private var pendingCloudRefreshWorkItem: DispatchWorkItem?
    private var lastCloudRefreshDate = Date.distantPast

    init(inMemory: Bool = false, enablesCloudSync: Bool = true) throws {
        container = NSPersistentCloudKitContainer(
            name: "VoucherWallet",
            managedObjectModel: Self.makeManagedObjectModel()
        )

        let descriptions = Self.makeStoreDescriptions(
            inMemory: inMemory,
            enablesCloudSync: enablesCloudSync
        )
        Self.allowStoreAccessAfterFirstUnlock(descriptions: descriptions, inMemory: inMemory)
        Self.resetSharedStoreOnNextLaunchIfNeeded(descriptions: descriptions, inMemory: inMemory)
        container.persistentStoreDescriptions = descriptions

        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        var completedStores = 0

        container.loadPersistentStores { [weak self] description, error in
            if let error {
                loadError = error
            } else if let store = self?.container.persistentStoreCoordinator.persistentStore(for: description.url!) {
                if description.configuration == Self.sharedConfigurationName {
                    self?.sharedStore = store
                } else {
                    self?.privateStore = store
                }
            }
            completedStores += 1
            if completedStores == descriptions.count {
                semaphore.signal()
            }
        }
        semaphore.wait()

        if let loadError {
            throw loadError
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "VoucherWalletApp"
        Self.migrateLegacyVoucherStoredKeysIfNeeded()
        cloudSyncCoordinator = CloudSyncCoordinator(persistence: self)
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.cloudSyncCoordinator.processPersistentHistory(reason: "remote-store-change")
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                  event.type == .import || event.type == .export else {
                return
            }

            let status: String
            if event.endDate == nil {
                status = "started"
            } else if event.succeeded {
                status = "finished"
            } else {
                status = "failed"
                if let error = event.error {
                    NSLog("[VoucherWallet][iCloud] Evenement CloudKit echoue (%@): %@", String(describing: event.type), error.localizedDescription)
                }
            }

            NotificationCenter.default.post(
                name: Self.cloudSyncStatusNotificationName,
                object: status,
                userInfo: ["error": event.error as Any]
            )

            if status == "finished", event.type == .import {
                Task { @MainActor [weak self] in
                    self?.cloudSyncCoordinator.processPersistentHistory(reason: "cloudkit-import-finished")
                }
            }
        }
#if !WIDGET_EXTENSION
        importLegacySwiftDataStoreIfNeeded()
#endif
        Self.active = self
    }

    static func create(inMemory: Bool = false, enablesCloudSync: Bool = true) throws -> NSPersistentCloudKitContainer {
        try SharedModelContainer(inMemory: inMemory, enablesCloudSync: enablesCloudSync).container
    }

    nonisolated static var appGroupKeyValueStore: AppGroupKeyValueStore {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            logAppGroupStoreFallbackIfNeeded()
            return .standardFallback
        }

        return AppGroupKeyValueStore(
            fileURL: containerURL.appendingPathComponent("VoucherWalletSharedPreferences.plist")
        )
    }

    nonisolated private static func logAppGroupStoreFallbackIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: appGroupStoreFallbackWarningKey) else { return }
        UserDefaults.standard.set(true, forKey: appGroupStoreFallbackWarningKey)
        debugLog("⚠️ App Group indisponible pour le stockage partagé. Fallback vers UserDefaults.standard.")
    }

    static func rememberDeletedVoucherForLegacyMigration(_ voucher: Voucher) {
        guard let voucherID = voucher.safeID else { return }
        let store = appGroupKeyValueStore

        var deletedIDs = Set(store.stringArray(forKey: deletedLegacyVoucherIDsKey) ?? [])
        deletedIDs.insert(voucherID.uuidString)
        store.setStringArray(Array(deletedIDs), forKey: deletedLegacyVoucherIDsKey)

        if let key = legacyVoucherPrivacyKey(for: voucher.voucherNumber) {
            var deletedKeys = legacyVoucherPrivacyKeys(
                from: store.stringArray(forKey: deletedLegacyVoucherKeysKey) ?? []
            )
            deletedKeys.insert(key)
            store.setStringArray(Array(deletedKeys), forKey: deletedLegacyVoucherKeysKey)
        }
    }

    static func forgetDeletedLegacyVoucherForUserImport(_ voucher: Voucher) {
        guard let voucherID = voucher.safeID else { return }
        let store = appGroupKeyValueStore

        var deletedIDs = Set(store.stringArray(forKey: deletedLegacyVoucherIDsKey) ?? [])
        deletedIDs.remove(voucherID.uuidString)
        store.setStringArray(Array(deletedIDs), forKey: deletedLegacyVoucherIDsKey)

        var deletedKeys = legacyVoucherPrivacyKeys(
            from: store.stringArray(forKey: deletedLegacyVoucherKeysKey) ?? []
        )
        let lookupKeys = legacyVoucherStorageLookupKeys(for: voucher.voucherNumber)
        if !lookupKeys.isEmpty {
            deletedKeys.subtract(lookupKeys)
            store.setStringArray(Array(deletedKeys), forKey: deletedLegacyVoucherKeysKey)
        }
    }

    static func isDeletedLegacyVoucher(_ voucher: Voucher) -> Bool {
        guard shouldApplyDeletedLegacyFilter(to: voucher) else { return false }
        guard let voucherID = voucher.safeID else { return false }

        let store = appGroupKeyValueStore
        let deletedIDs = Set(store.stringArray(forKey: deletedLegacyVoucherIDsKey) ?? [])
        let deletedKeys = legacyVoucherPrivacyKeys(
            from: store.stringArray(forKey: deletedLegacyVoucherKeysKey) ?? []
        )

        return deletedIDs.contains(voucherID.uuidString) ||
            !legacyVoucherStorageLookupKeys(for: voucher.voucherNumber).isDisjoint(with: deletedKeys)
    }

    @discardableResult
    static func purgeDeletedLegacyVouchers(in context: NSManagedObjectContext) -> Bool {
        do {
            let vouchers = try context.fetch(Voucher.fetchRequest())
            let deletedVouchers = vouchers.filter { voucher in
                voucher.managedObjectContext != nil &&
                    !voucher.isDeleted &&
                    isDeletedLegacyVoucher(voucher)
            }
            guard !deletedVouchers.isEmpty else { return false }

            for voucher in deletedVouchers {
                voucher.deletePersonalPreference(in: context)
                context.delete(voucher)
            }

            if context.hasChanges {
                try context.save()
            }
            return true
        } catch {
            debugLog("⚠️ Purge des anciens bons supprimés impossible : \(error.localizedDescription)")
            return false
        }
    }

    private static func shouldApplyDeletedLegacyFilter(to voucher: Voucher) -> Bool {
        guard voucher.managedObjectContext != nil,
              !voucher.isDeleted,
              let store = voucher.objectID.persistentStore else {
            return true
        }

        return store.configurationName != sharedConfigurationName
    }

    nonisolated private static func migrateLegacyVoucherStoredKeysIfNeeded() {
        let store = appGroupKeyValueStore

        for key in [deletedLegacyVoucherKeysKey, migratedLegacyVoucherKeysKey] {
            let storedValues = store.stringArray(forKey: key) ?? []
            let privacyValues = legacyVoucherPrivacyKeys(from: storedValues)
            if Set(storedValues) != privacyValues {
                store.setStringArray(Array(privacyValues), forKey: key)
            }
        }
    }

    nonisolated private static func normalizedVoucherNumberKey(_ voucherNumber: String) -> String? {
        let normalized = voucherNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    nonisolated private static func legacyVoucherPrivacyKey(for voucherNumber: String) -> String? {
        normalizedVoucherNumberKey(voucherNumber).map(legacyVoucherPrivacyKey(forNormalizedKey:))
    }

    nonisolated private static func legacyVoucherPrivacyKey(forNormalizedKey normalizedKey: String) -> String {
        let scopedValue = "VoucherWallet.LegacyVoucherKey.v1.\(normalizedKey)"
        let digest = SHA256.hash(data: Data(scopedValue.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "sha256:\(hash)"
    }

    nonisolated private static func legacyVoucherStorageLookupKeys(for voucherNumber: String) -> Set<String> {
        guard let normalizedKey = normalizedVoucherNumberKey(voucherNumber) else { return [] }
        return [
            normalizedKey,
            legacyVoucherPrivacyKey(forNormalizedKey: normalizedKey)
        ]
    }

    nonisolated private static func legacyVoucherPrivacyKeys(from storedValues: [String]) -> Set<String> {
        Set(storedValues.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.hasPrefix("sha256:") {
                return trimmed
            }
            return legacyVoucherPrivacyKey(forNormalizedKey: trimmed)
        })
    }

    func markSharedStoreForResetOnNextLaunch(reason: String) {
        UserDefaults.standard.set(true, forKey: Self.resetSharedStoreOnNextLaunchKey)
        NSLog("[VoucherWallet][iCloud] Store partagé marqué pour réinitialisation au prochain lancement (%@)", reason)
    }

    @MainActor
    func resetViewContextAndNotify() {
        reloadViewContextAndNotify(reason: "explicit-view-context-reset")
    }

    @MainActor
    func reloadViewContextAndNotify(reason: String) {
        NSLog("[VoucherWallet][iCloud] Relecture du store local (%@)", reason)
        container.viewContext.processPendingChanges()
        try? container.viewContext.setQueryGenerationFrom(.current)
        container.viewContext.reset()
        NotificationCenter.default.post(
            name: Notification.Name("voucherRemoteStoreDidChange"),
            object: nil,
            userInfo: ["reason": reason]
        )
    }

    @MainActor
    func requestCloudRefresh(minimumInterval: TimeInterval = 0.8) {
        let elapsed = Date().timeIntervalSince(lastCloudRefreshDate)
        guard elapsed >= minimumInterval else {
            scheduleDebouncedCloudRefresh(after: minimumInterval - elapsed)
            return
        }
        performCloudRefresh()
    }

    @MainActor
    private func scheduleDebouncedCloudRefresh(after delay: TimeInterval) {
        guard pendingCloudRefreshWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.pendingCloudRefreshWorkItem = nil
                self.performCloudRefresh()
            }
        }
        pendingCloudRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @MainActor
    private func performCloudRefresh() {
        pendingCloudRefreshWorkItem?.cancel()
        pendingCloudRefreshWorkItem = nil
        lastCloudRefreshDate = Date()
        cloudSyncCoordinator.processPersistentHistory(reason: "scheduled-history-merge")
    }

    @MainActor
    func scheduleCloudRefreshes(delays: [TimeInterval] = [0.0, 1.0, 3.0, 6.0]) {
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.requestCloudRefresh()
                }
            }
        }
    }

    @MainActor
    func scheduleCloudResets(delays: [TimeInterval] = [0.0, 1.0, 3.0, 6.0]) {
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.resetViewContextAndNotify()
                }
            }
        }
    }

    static func assignToPrivateStore(_ object: NSManagedObject, in context: NSManagedObjectContext) {
        guard let coordinator = context.persistentStoreCoordinator,
              let store = coordinator.persistentStores.first(where: {
                  $0.configurationName == privateConfigurationName
              }) else {
            return
        }
        context.assign(object, to: store)
    }

    static func assign(_ object: NSManagedObject, toStoreOf relatedObject: NSManagedObject) {
        guard let context = object.managedObjectContext,
              let store = relatedObject.objectID.persistentStore else {
            return
        }
        context.assign(object, to: store)
    }

    private static func makeStoreDescriptions(
        inMemory: Bool,
        enablesCloudSync: Bool
    ) -> [NSPersistentStoreDescription] {
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.configuration = privateConfigurationName
            return [description]
        }

        let root = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        let privateDescription = NSPersistentStoreDescription(
            url: root.appendingPathComponent("VoucherWallet-Private.sqlite")
        )
        privateDescription.configuration = privateConfigurationName

        let sharedDescription = NSPersistentStoreDescription(
            url: root.appendingPathComponent("VoucherWallet-Shared.sqlite")
        )
        sharedDescription.configuration = sharedConfigurationName

        for description in [privateDescription, sharedDescription] {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.setOption(
                FileProtectionType.completeUntilFirstUserAuthentication.rawValue as NSString,
                forKey: NSPersistentStoreFileProtectionKey
            )
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        if enablesCloudSync {
            let privateOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerIdentifier
            )
            privateOptions.databaseScope = .private
            privateDescription.cloudKitContainerOptions = privateOptions

            let sharedOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerIdentifier
            )
            sharedOptions.databaseScope = .shared
            sharedDescription.cloudKitContainerOptions = sharedOptions
        }

        return [privateDescription, sharedDescription]
    }

    private static func allowStoreAccessAfterFirstUnlock(
        descriptions: [NSPersistentStoreDescription],
        inMemory: Bool
    ) {
        guard !inMemory else { return }

        let fileManager = FileManager.default
        for description in descriptions {
            guard let storeURL = description.url else { continue }
            let candidates = [
                storeURL,
                URL(fileURLWithPath: storeURL.path + "-shm"),
                URL(fileURLWithPath: storeURL.path + "-wal")
            ]

            for url in candidates where fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.setAttributes(
                        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                        ofItemAtPath: url.path
                    )
                } catch {
                    debugLog("⚠️ Protection fichier du store inchangée (\(url.lastPathComponent)): \(error.localizedDescription)")
                }
            }
        }
    }

    private static func resetSharedStoreOnNextLaunchIfNeeded(
        descriptions: [NSPersistentStoreDescription],
        inMemory: Bool
    ) {
        guard !inMemory,
              UserDefaults.standard.bool(forKey: resetSharedStoreOnNextLaunchKey),
              let sharedURL = descriptions.first(where: { $0.configuration == sharedConfigurationName })?.url else {
            return
        }

        let fileManager = FileManager.default
        let candidates = [
            sharedURL,
            URL(fileURLWithPath: sharedURL.path + "-shm"),
            URL(fileURLWithPath: sharedURL.path + "-wal"),
            URL(fileURLWithPath: sharedURL.path + "_SUPPORT")
        ]

        for url in candidates where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                NSLog("[VoucherWallet][iCloud] Réinitialisation du store partagé impossible (%@): %@", url.lastPathComponent, error.localizedDescription)
            }
        }

        UserDefaults.standard.set(false, forKey: resetSharedStoreOnNextLaunchKey)
        NSLog("[VoucherWallet][iCloud] Store partagé local réinitialisé avant chargement")
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let voucher = entity("Voucher", className: "Voucher")
        let expense = entity("Expense", className: "Expense")
        let preference = entity("PersonalVoucherPreference", className: "PersonalVoucherPreference")

        voucher.properties = [
            attribute("id", .UUIDAttributeType, defaultValue: UUID()),
            attribute("storeName", .stringAttributeType, defaultValue: ""),
            attribute("amountValue", .doubleAttributeType, optional: true, renamedFrom: "amount"),
            attribute("voucherNumber", .stringAttributeType, defaultValue: ""),
            attribute("pinCode", .stringAttributeType, optional: true),
            attribute("codeTypeValue", .stringAttributeType, defaultValue: CodeType.barcode.rawValue, renamedFrom: "codeType"),
            attribute("codeImageData", .binaryDataAttributeType, optional: true, external: true),
            attribute("expirationDate", .dateAttributeType, optional: true),
            attribute("dateAdded", .dateAttributeType, defaultValue: Date()),
            attribute("pdfData", .binaryDataAttributeType, optional: true, external: true),
            attribute("imageData", .binaryDataAttributeType, optional: true, external: true),
            attribute("storeColor", .stringAttributeType, defaultValue: "#007AFF"),
            attribute("textColor", .stringAttributeType, defaultValue: "#FFFFFF"),
            attribute("spentBeforeCurrentShare", .doubleAttributeType, defaultValue: 0.0),
            attribute("activeSharingPeriodID", .UUIDAttributeType, optional: true),
            attribute("sharingStartedAt", .dateAttributeType, optional: true)
        ]

        expense.properties = [
            attribute("id", .UUIDAttributeType, defaultValue: UUID()),
            attribute("amount", .doubleAttributeType, defaultValue: 0.0),
            attribute("date", .dateAttributeType, defaultValue: Date()),
            attribute("note", .stringAttributeType, optional: true),
            attribute("authorDisplayName", .stringAttributeType, optional: true),
            attribute("authorRecordName", .stringAttributeType, optional: true),
            attribute("sharingPeriodID", .UUIDAttributeType, optional: true),
            attribute("archivedVoucherID", .UUIDAttributeType, optional: true)
        ]

        preference.properties = [
            attribute("id", .UUIDAttributeType, defaultValue: UUID()),
            attribute("voucherID", .UUIDAttributeType, defaultValue: UUID()),
            attribute("isFavorite", .booleanAttributeType, defaultValue: false),
            attribute("sortOrder", .integer64AttributeType, defaultValue: Int64(0))
        ]

        let voucherExpenses = NSRelationshipDescription()
        voucherExpenses.name = "expenses"
        voucherExpenses.destinationEntity = expense
        voucherExpenses.minCount = 0
        voucherExpenses.maxCount = 0
        voucherExpenses.deleteRule = .cascadeDeleteRule
        voucherExpenses.isOptional = true

        let expenseVoucher = NSRelationshipDescription()
        expenseVoucher.name = "voucher"
        expenseVoucher.destinationEntity = voucher
        expenseVoucher.minCount = 0
        expenseVoucher.maxCount = 1
        expenseVoucher.deleteRule = .nullifyDeleteRule
        expenseVoucher.isOptional = true

        voucherExpenses.inverseRelationship = expenseVoucher
        expenseVoucher.inverseRelationship = voucherExpenses
        voucher.properties.append(voucherExpenses)
        expense.properties.append(expenseVoucher)

        model.entities = [voucher, expense, preference]
        model.setEntities([voucher, expense, preference], forConfigurationName: privateConfigurationName)
        model.setEntities([voucher, expense], forConfigurationName: sharedConfigurationName)
        return model
    }

    private static func entity(_ name: String, className: String) -> NSEntityDescription {
        let value = NSEntityDescription()
        value.name = name
        value.managedObjectClassName = className
        return value
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil,
        external: Bool = false,
        renamedFrom: String? = nil
    ) -> NSAttributeDescription {
        let value = NSAttributeDescription()
        value.name = name
        value.attributeType = type
        value.isOptional = optional
        value.defaultValue = defaultValue
        value.allowsExternalBinaryDataStorage = external
        value.renamingIdentifier = renamedFrom
        return value
    }

#if !WIDGET_EXTENSION
    /// Reprend et repare une fois les objets du store SwiftData historique en lecture seule.
    /// Le fichier source est conserve afin de ne jamais detruire une sauvegarde existante.
    private func importLegacySwiftDataStoreIfNeeded() {
        let migrationVersionKey = "legacySwiftDataMigrationVersion"
        let migrationVersion = 7
        let store = Self.appGroupKeyValueStore
        let previousMigrationVersion = store.integer(forKey: migrationVersionKey)
        guard previousMigrationVersion < migrationVersion else { return }
        let alreadyRanLegacyMigration = previousMigrationVersion > 0

        guard let privateStore,
              let root = privateStore.url?.deletingLastPathComponent() else { return }

        let context = container.viewContext
        let snapshots: [LegacyVoucherSnapshot]
        do {
            snapshots = try readLegacySwiftDataSnapshots(near: root)
        } catch {
            snapshots = []
            debugLog("⚠️ Lecture du store SwiftData historique impossible, réparation Core Data seule : \(error.localizedDescription)")
        }

        do {
            try context.performAndWait {
                var createdCount = 0
                var repairedCount = 0
                var skippedDeletedCount = 0
                var skippedAlreadyMigratedCount = 0
                let deletedLegacyVoucherIDs = Set(store.stringArray(forKey: Self.deletedLegacyVoucherIDsKey) ?? [])
                let deletedLegacyVoucherKeys = Self.legacyVoucherPrivacyKeys(
                    from: store.stringArray(forKey: Self.deletedLegacyVoucherKeysKey) ?? []
                )
                var migratedLegacyVoucherIDs = Set(store.stringArray(forKey: Self.migratedLegacyVoucherIDsKey) ?? [])
                var migratedLegacyVoucherKeys = Self.legacyVoucherPrivacyKeys(
                    from: store.stringArray(forKey: Self.migratedLegacyVoucherKeysKey) ?? []
                )
                let existingVouchers = try context.fetch(Voucher.fetchRequest())
                var vouchersByID = Dictionary(
                    existingVouchers.compactMap { voucher -> (UUID, Voucher)? in
                        guard let voucherID = voucher.safeID else { return nil }
                        return (voucherID, voucher)
                    },
                    uniquingKeysWith: { existing, _ in existing }
                )
                var vouchersByLegacyKey = Dictionary(
                    existingVouchers.compactMap { voucher -> (String, Voucher)? in
                        guard let key = Self.legacyVoucherKey(for: voucher) else { return nil }
                        return (key, voucher)
                    },
                    uniquingKeysWith: { existing, candidate in
                        Self.preferredMigrationVoucher(existing, candidate)
                    }
                )
                for existingVoucher in existingVouchers where Self.isDeletedLegacyVoucher(
                    existingVoucher,
                    deletedIDs: deletedLegacyVoucherIDs,
                    deletedKeys: deletedLegacyVoucherKeys
                ) {
                    let existingVoucherID = existingVoucher.safeID
                    existingVoucher.deletePersonalPreference(in: context)
                    context.delete(existingVoucher)
                    if let existingVoucherID {
                        vouchersByID.removeValue(forKey: existingVoucherID)
                    }
                    if let key = Self.legacyVoucherKey(for: existingVoucher) {
                        vouchersByLegacyKey.removeValue(forKey: key)
                    }
                }
                if !snapshots.isEmpty {
                    let expenseIDs = Set(try context.fetch(Expense.fetchRequest()).compactMap(\.safeID))
                    var importedExpenseIDs = expenseIDs

                    for snapshot in snapshots {
                        if Self.isDeletedLegacyVoucher(
                            snapshot,
                            deletedIDs: deletedLegacyVoucherIDs,
                            deletedKeys: deletedLegacyVoucherKeys
                        ) {
                            if let existingVoucher = vouchersByID[snapshot.id]
                                ?? Self.legacyVoucherKey(for: snapshot).flatMap({ vouchersByLegacyKey[$0] }) {
                                existingVoucher.deletePersonalPreference(in: context)
                                context.delete(existingVoucher)
                                vouchersByID.removeValue(forKey: snapshot.id)
                                if let key = Self.legacyVoucherKey(for: snapshot) {
                                    vouchersByLegacyKey.removeValue(forKey: key)
                                }
                            }
                            skippedDeletedCount += 1
                            continue
                        }
                        let codeType = Self.normalizedLegacyCodeType(snapshot.codeType)
                        let voucher: Voucher
                        if let existingVoucher = vouchersByID[snapshot.id]
                            ?? Self.legacyVoucherKey(for: snapshot).flatMap({ vouchersByLegacyKey[$0] }) {
                            voucher = existingVoucher
                            if Self.update(voucher, from: snapshot, codeType: codeType) {
                                repairedCount += 1
                            }
                        } else if alreadyRanLegacyMigration || Self.isAlreadyMigratedLegacyVoucher(
                            snapshot,
                            migratedIDs: migratedLegacyVoucherIDs,
                            migratedKeys: migratedLegacyVoucherKeys
                        ) {
                            skippedAlreadyMigratedCount += 1
                            continue
                        } else {
                            voucher = Voucher(
                                context: context,
                                id: snapshot.id,
                                storeName: snapshot.storeName,
                                amount: snapshot.amount,
                                voucherNumber: snapshot.voucherNumber,
                                pinCode: snapshot.pinCode,
                                codeType: codeType,
                                codeImageData: snapshot.codeImageData,
                                expirationDate: snapshot.expirationDate,
                                dateAdded: snapshot.dateAdded,
                                sortOrder: snapshot.sortOrder,
                                pdfData: snapshot.pdfData,
                                storeColor: snapshot.storeColor,
                                textColor: snapshot.textColor
                            )
                            vouchersByID[snapshot.id] = voucher
                            if let key = Self.legacyVoucherKey(for: snapshot) {
                                vouchersByLegacyKey[key] = voucher
                            }
                            createdCount += 1
                        }
                        migratedLegacyVoucherIDs.insert(snapshot.id.uuidString)
                        if let key = Self.legacyVoucherPrivacyKey(for: snapshot.voucherNumber) {
                            migratedLegacyVoucherKeys.insert(key)
                        }

                        // Favoris et ordre sont personnels : on restaure ceux de la 1.1.1 sans effacer
                        // un choix déjà refait dans la 2.0.
                        if snapshot.isFavorite {
                            voucher.isFavorite = true
                            voucher.sortOrder = snapshot.sortOrder
                        }

                        for sourceExpense in snapshot.expenses {
                            guard !importedExpenseIDs.contains(sourceExpense.id) else { continue }
                            let expense = Expense(
                                context: context,
                                id: sourceExpense.id,
                                amount: sourceExpense.amount,
                                date: sourceExpense.date,
                                note: sourceExpense.note
                            )
                            SharedModelContainer.assign(expense, toStoreOf: voucher)
                            expense.voucher = voucher
                            importedExpenseIDs.insert(sourceExpense.id)
                        }
                    }
                }
                debugLog("🔁 Migration SwiftData v\(migrationVersion) (ancienne v\(previousMigrationVersion)) : snapshots=\(snapshots.count), créés=\(createdCount), réparés=\(repairedCount), supprimés ignorés=\(skippedDeletedCount), déjà migrés ignorés=\(skippedAlreadyMigratedCount)")
                Self.consolidateDuplicateLocalVouchers(in: context)
                Self.consolidatePersonalPreferences(in: context)
                if context.hasChanges {
                    try context.save()
                }
                store.setStringArray(Array(migratedLegacyVoucherIDs), forKey: Self.migratedLegacyVoucherIDsKey)
                store.setStringArray(Array(migratedLegacyVoucherKeys), forKey: Self.migratedLegacyVoucherKeysKey)
            }
            store.setInteger(migrationVersion, forKey: migrationVersionKey)
            WidgetReloader.reloadFavoriteVouchersWidget()
            debugLog("✅ Migration locale : \(snapshots.count) bon(s) repris ou repares depuis SwiftData")
        } catch {
            debugLog("⚠️ Import du store SwiftData existant impossible : \(error.localizedDescription)")
        }
    }

    private func readLegacySwiftDataSnapshots(near root: URL) throws -> [LegacyVoucherSnapshot] {
        if let snapshots = try? LegacySwiftDataImporter.readFromAppGroup(identifier: Self.appGroupIdentifier),
           !snapshots.isEmpty {
            return snapshots
        }

        var lastError: Error?
        for url in Self.legacySwiftDataStoreURLs(near: root) {
            do {
                let snapshots = try LegacySwiftDataImporter.read(from: url)
                if !snapshots.isEmpty {
                    return snapshots
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        return []
    }

    private static func normalizedLegacyCodeType(_ rawValue: String) -> CodeType {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalized.contains("qr") {
            return .qrCode
        }
        return .barcode
    }

    @discardableResult
    private static func update(
        _ voucher: Voucher,
        from snapshot: LegacyVoucherSnapshot,
        codeType: CodeType
    ) -> Bool {
        var didChange = false
        if voucher.storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            voucher.storeName = snapshot.storeName
            didChange = true
        }
        if voucher.amount == nil || ((voucher.amount ?? 0) <= 0 && (snapshot.amount ?? 0) > 0) {
            voucher.amount = snapshot.amount
            didChange = true
        }
        if voucher.voucherNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            voucher.voucherNumber = snapshot.voucherNumber
            didChange = true
        }
        if voucher.pinCode == nil {
            voucher.pinCode = snapshot.pinCode
            didChange = true
        }
        if voucher.codeType == .barcode && codeType == .qrCode {
            voucher.codeType = .qrCode
            voucher.codeImageData = snapshot.codeImageData
            didChange = true
        } else if voucher.codeImageData == nil {
            voucher.codeImageData = snapshot.codeImageData
            didChange = snapshot.codeImageData != nil
        }
        if voucher.expirationDate == nil {
            voucher.expirationDate = snapshot.expirationDate
            didChange = snapshot.expirationDate != nil
        }
        if voucher.pdfData == nil {
            voucher.pdfData = snapshot.pdfData
            didChange = snapshot.pdfData != nil
        }
        if voucher.storeColor == "#007AFF" {
            voucher.storeColor = snapshot.storeColor
            didChange = true
        }
        if voucher.textColor == "#FFFFFF" {
            voucher.textColor = snapshot.textColor
            didChange = true
        }
        return didChange
    }

    private static func legacyVoucherKey(for snapshot: LegacyVoucherSnapshot) -> String? {
        legacyVoucherKey(voucherNumber: snapshot.voucherNumber)
    }

    private static func isDeletedLegacyVoucher(
        _ snapshot: LegacyVoucherSnapshot,
        deletedIDs: Set<String>,
        deletedKeys: Set<String>
    ) -> Bool {
        deletedIDs.contains(snapshot.id.uuidString) ||
            !legacyVoucherStorageLookupKeys(for: snapshot.voucherNumber).isDisjoint(with: deletedKeys)
    }

    private static func isDeletedLegacyVoucher(
        _ voucher: Voucher,
        deletedIDs: Set<String>,
        deletedKeys: Set<String>
    ) -> Bool {
        guard shouldApplyDeletedLegacyFilter(to: voucher) else { return false }
        guard let voucherID = voucher.safeID else { return false }

        return deletedIDs.contains(voucherID.uuidString) ||
            !legacyVoucherStorageLookupKeys(for: voucher.voucherNumber).isDisjoint(with: deletedKeys)
    }

    private static func isAlreadyMigratedLegacyVoucher(
        _ snapshot: LegacyVoucherSnapshot,
        migratedIDs: Set<String>,
        migratedKeys: Set<String>
    ) -> Bool {
        migratedIDs.contains(snapshot.id.uuidString) ||
            !legacyVoucherStorageLookupKeys(for: snapshot.voucherNumber).isDisjoint(with: migratedKeys)
    }

    private static func legacyVoucherKey(for voucher: Voucher) -> String? {
        legacyVoucherKey(voucherNumber: voucher.voucherNumber)
    }

    private static func legacyVoucherKey(voucherNumber: String) -> String? {
        normalizedVoucherNumberKey(voucherNumber)
    }

    private static func preferredMigrationVoucher(_ lhs: Voucher, _ rhs: Voucher) -> Voucher {
        let lhsScore = migrationCompletenessScore(lhs)
        let rhsScore = migrationCompletenessScore(rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore ? lhs : rhs
        }
        return lhs.dateAdded <= rhs.dateAdded ? lhs : rhs
    }

    private static func migrationCompletenessScore(_ voucher: Voucher) -> Int {
        var score = 0
        if voucher.isFavorite { score += 16 }
        if voucher.amount != nil { score += 8 }
        if voucher.codeType == .qrCode { score += 4 }
        if voucher.codeImageData != nil { score += 2 }
        if voucher.pdfData != nil { score += 1 }
        if voucher.imageData != nil { score += 1 }
        return score
    }

    private static func consolidateDuplicateLocalVouchers(in context: NSManagedObjectContext) {
        do {
            let vouchers = try context.fetch(Voucher.fetchRequest()).filter { voucher in
                voucher.managedObjectContext != nil
                    && !voucher.isDeleted
                    && !voucher.isReceivedShare
            }
            let idGroups = Dictionary(grouping: vouchers, by: \.id)
            for (_, group) in idGroups where group.count > 1 {
                let canonical = group.reduce(group[0]) { preferredMigrationVoucher($0, $1) }
                let duplicates = group.filter { $0.objectID != canonical.objectID }

                for duplicate in duplicates {
                    merge(duplicateVoucher: duplicate, into: canonical)
                    context.delete(duplicate)
                }
            }

            let remainingVouchers = vouchers.filter { !$0.isDeleted }
            let grouped = Dictionary(grouping: remainingVouchers, by: { legacyVoucherKey(for: $0) })

            for case let (key?, group) in grouped where !key.isEmpty && group.count > 1 {
                let canonical = group.reduce(group[0]) { preferredMigrationVoucher($0, $1) }
                let duplicates = group.filter { $0.objectID != canonical.objectID }

                for duplicate in duplicates {
                    merge(duplicateVoucher: duplicate, into: canonical)
                    if duplicate.id != canonical.id {
                        deletePersonalPreferences(for: duplicate.id, in: context)
                    }
                    context.delete(duplicate)
                }
            }
        } catch {
            debugLog("⚠️ Consolidation des doublons locaux impossible : \(error.localizedDescription)")
        }
    }

    private static func deletePersonalPreferences(for voucherID: UUID, in context: NSManagedObjectContext) {
        let request = PersonalVoucherPreference.fetchRequest()
        request.predicate = NSPredicate(format: "voucherID == %@", voucherID as CVarArg)

        do {
            for preference in try context.fetch(request) {
                context.delete(preference)
            }
        } catch {
            debugLog("⚠️ Suppression des préférences du doublon impossible : \(error.localizedDescription)")
        }
    }

    private static func merge(duplicateVoucher duplicate: Voucher, into canonical: Voucher) {
        if canonical.storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canonical.storeName = duplicate.storeName
        }
        if canonical.amount == nil {
            canonical.amount = duplicate.amount
        }
        if canonical.pinCode == nil {
            canonical.pinCode = duplicate.pinCode
        }
        if canonical.codeType == .barcode && duplicate.codeType == .qrCode {
            canonical.codeType = .qrCode
            canonical.codeImageData = duplicate.codeImageData
        } else if canonical.codeImageData == nil {
            canonical.codeImageData = duplicate.codeImageData
        }
        if canonical.expirationDate == nil {
            canonical.expirationDate = duplicate.expirationDate
        }
        if canonical.pdfData == nil {
            canonical.pdfData = duplicate.pdfData
        }
        if canonical.imageData == nil {
            canonical.imageData = duplicate.imageData
        }
        if canonical.storeColor == "#007AFF" {
            canonical.storeColor = duplicate.storeColor
        }
        if canonical.textColor == "#FFFFFF" {
            canonical.textColor = duplicate.textColor
        }
        if duplicate.isFavorite {
            canonical.isFavorite = true
            canonical.sortOrder = min(canonical.sortOrder, duplicate.sortOrder)
        }

        let existingExpenseIDs = Set(canonical.activeExpensesList.compactMap(\.safeID))
        for expense in duplicate.activeExpensesList {
            guard let expenseID = expense.safeID, !existingExpenseIDs.contains(expenseID) else { continue }
            expense.voucher = canonical
        }
    }

    private static func consolidatePersonalPreferences(in context: NSManagedObjectContext) {
        do {
            let vouchers = try context.fetch(Voucher.fetchRequest())
            let existingVoucherIDs = Set(vouchers.compactMap(\.safeID))
            let preferences = try context.fetch(PersonalVoucherPreference.fetchRequest())
            let grouped = Dictionary(grouping: preferences, by: \.voucherID)

            for (voucherID, items) in grouped {
                guard existingVoucherIDs.contains(voucherID), items.count > 1 else {
                    if !existingVoucherIDs.contains(voucherID) {
                        items.forEach(context.delete)
                    }
                    continue
                }

                let keep = items.min {
                    if $0.isFavorite != $1.isFavorite {
                        return $0.isFavorite
                    }
                    return $0.sortOrder < $1.sortOrder
                }

                keep?.isFavorite = items.contains(where: \.isFavorite)
                keep?.sortOrder = items.map(\.sortOrder).min() ?? 0

                if let keep {
                    for item in items where item.objectID != keep.objectID {
                        context.delete(item)
                    }
                }
            }
        } catch {
            debugLog("⚠️ Consolidation des préférences favorites impossible : \(error.localizedDescription)")
        }
    }

    private static func legacySwiftDataStoreURLs(near root: URL) -> [URL] {
        let fileManager = FileManager.default
        var candidates: [URL] = [
            root.appendingPathComponent("default.store"),
            root.appendingPathComponent("Library/Application Support/default.store")
        ]

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(appSupport.appendingPathComponent("default.store"))
        }

        if let appGroupRoot = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            candidates.append(appGroupRoot.appendingPathComponent("default.store"))
            candidates.append(appGroupRoot.appendingPathComponent("Library/Application Support/default.store"))

            if let enumerator = fileManager.enumerator(
                at: appGroupRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let url as URL in enumerator where url.lastPathComponent == "default.store" {
                    candidates.append(url)
                }
            }
        }

        var seen = Set<String>()
        return candidates.filter { url in
            guard fileManager.fileExists(atPath: url.path), !seen.contains(url.path) else {
                return false
            }
            seen.insert(url.path)
            return true
        }
    }
#endif

}

struct AppGroupKeyValueStore: Sendable {
    private let fileURL: URL?

    nonisolated static let standardFallback = AppGroupKeyValueStore(fileURL: nil)

    nonisolated init(fileURL: URL) {
        self.fileURL = fileURL
    }

    private nonisolated init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    nonisolated func stringArray(forKey key: String) -> [String]? {
        if let fileURL {
            return readFileDictionary(from: fileURL)[key] as? [String]
        }
        return UserDefaults.standard.stringArray(forKey: key)
    }

    nonisolated func setStringArray(_ value: [String], forKey key: String) {
        set(value, forKey: key)
    }

    nonisolated func data(forKey key: String) -> Data? {
        if let fileURL {
            return readFileDictionary(from: fileURL)[key] as? Data
        }
        return UserDefaults.standard.data(forKey: key)
    }

    nonisolated func setData(_ value: Data, forKey key: String) {
        set(value, forKey: key)
    }

    nonisolated func string(forKey key: String) -> String? {
        if let fileURL {
            return readFileDictionary(from: fileURL)[key] as? String
        }
        return UserDefaults.standard.string(forKey: key)
    }

    nonisolated func setString(_ value: String, forKey key: String) {
        set(value, forKey: key)
    }

    nonisolated func integer(forKey key: String) -> Int {
        if let fileURL {
            return readFileDictionary(from: fileURL)[key] as? Int ?? 0
        }
        return UserDefaults.standard.integer(forKey: key)
    }

    nonisolated func setInteger(_ value: Int, forKey key: String) {
        set(value, forKey: key)
    }

    nonisolated func removeObject(forKey key: String) {
        if let fileURL {
            mutateFileDictionary(at: fileURL) { dictionary in
                dictionary.removeValue(forKey: key)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private nonisolated func set(_ value: Any, forKey key: String) {
        if let fileURL {
            mutateFileDictionary(at: fileURL) { dictionary in
                dictionary[key] = value
            }
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private nonisolated func readFileDictionary(from fileURL: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any] else {
            return [:]
        }
        return dictionary
    }

    private nonisolated func mutateFileDictionary(
        at fileURL: URL,
        update: (inout [String: Any]) -> Void
    ) {
        var dictionary = readFileDictionary(from: fileURL)
        update(&dictionary)

        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: dictionary,
                format: .xml,
                options: 0
            )
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            debugLog("⚠️ Écriture du stockage partagé impossible : \(error.localizedDescription)")
        }
    }
}

final class CloudSyncCoordinator: @unchecked Sendable {
    private let persistence: SharedModelContainer
    private let historyTokenKey = "cloudSyncCoordinator.historyToken"
    private var historyToken: NSPersistentHistoryToken?
    private var isProcessingHistory = false
    private var shouldProcessHistoryAgain = false

    init(persistence: SharedModelContainer) {
        self.persistence = persistence
        historyToken = Self.loadHistoryToken(forKey: historyTokenKey)
    }

    @MainActor
    func processPersistentHistory(reason: String) {
        guard !isProcessingHistory else {
            shouldProcessHistoryAgain = true
            cloudSyncLog("Historique déjà en cours, nouvelle passe demandée (\(reason))")
            return
        }

        isProcessingHistory = true
        shouldProcessHistoryAgain = false

        let token = historyToken
        let stores = [persistence.privateStore, persistence.sharedStore].compactMap { $0 }
        let backgroundContext = persistence.container.newBackgroundContext()
        backgroundContext.transactionAuthor = "VoucherWalletHistoryMerge"
        backgroundContext.shouldDeleteInaccessibleFaults = true
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        backgroundContext.perform { [weak self] in
            guard let coordinator = self else { return }
            do {
                let request = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
                request.resultType = .transactionsAndChanges
                if !stores.isEmpty {
                    request.affectedStores = stores
                }

                let result = try backgroundContext.execute(request) as? NSPersistentHistoryResult
                let transactions = result?.result as? [NSPersistentHistoryTransaction] ?? []
                let mergeResult = PersistentHistoryMergeResult(
                    notifications: transactions.map { $0.objectIDNotification() },
                    newToken: transactions.last?.token,
                    transactionCount: transactions.count
                )

                Task { @MainActor [coordinator] in
                    coordinator.finishProcessingHistory(
                        mergeResult: mergeResult,
                        reason: reason
                    )
                }
            } catch {
                Task { @MainActor [coordinator] in
                    coordinator.finishProcessingHistory(
                        mergeResult: PersistentHistoryMergeResult(
                            notifications: [],
                            newToken: nil,
                            transactionCount: 0
                        ),
                        reason: reason,
                        error: error
                    )
                }
            }
        }
    }

    @MainActor
    private func finishProcessingHistory(
        mergeResult: PersistentHistoryMergeResult,
        reason: String,
        error: Error? = nil
    ) {
        defer {
            isProcessingHistory = false
            if shouldProcessHistoryAgain {
                processPersistentHistory(reason: "pending-history-pass")
            }
        }

        if let error {
            cloudSyncLog("Lecture historique persistant échouée (\(reason)): \(error.localizedDescription)")
            return
        }

        guard mergeResult.transactionCount > 0 else {
            return
        }

        let context = persistence.container.viewContext
        mergeResult.notifications.forEach { notification in
            context.mergeChanges(fromContextDidSave: notification)
        }
        context.processPendingChanges()

        if let newToken = mergeResult.newToken {
            historyToken = newToken
            Self.saveHistoryToken(newToken, forKey: historyTokenKey)
        }

        cloudSyncLog("Historique persistant fusionné (\(reason)): \(mergeResult.transactionCount) transaction(s)")
#if !WIDGET_EXTENSION
        guard UIApplication.shared.applicationState == .active else {
            cloudSyncLog("Notification UI différée: app inactive (\(reason))")
            return
        }
#endif
        NotificationCenter.default.post(
            name: Notification.Name("voucherRemoteStoreDidChange"),
            object: nil,
            userInfo: ["reason": reason, "transactionCount": mergeResult.transactionCount]
        )
    }

    private static func loadHistoryToken(forKey key: String) -> NSPersistentHistoryToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSPersistentHistoryToken.self,
            from: data
        )
    }

    private static func saveHistoryToken(_ token: NSPersistentHistoryToken, forKey key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        ) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func cloudSyncLog(_ message: String) {
        NSLog("[VoucherWallet][iCloud] %@", message)
    }
}

private struct PersistentHistoryMergeResult: @unchecked Sendable {
    let notifications: [Notification]
    let newToken: NSPersistentHistoryToken?
    let transactionCount: Int
}
