//
//  SharedModelContainer.swift
//  Voucher Wallet
//

import CloudKit
@preconcurrency import CoreData
import Foundation

/// Conteneur Core Data/CloudKit commun à l'application et au widget.
final class SharedModelContainer {
    nonisolated static let appGroupIdentifier = "group.com.jrocher77.voucherwallet"
    nonisolated static let cloudKitContainerIdentifier = "iCloud.jrocher.Voucher-Wallet"
    nonisolated static let privateConfigurationName = "Private"
    nonisolated static let sharedConfigurationName = "Shared"
    nonisolated static let cloudSyncStatusNotificationName = Notification.Name("voucherCloudSyncStatusDidChange")
    private static let resetSharedStoreOnNextLaunchKey = "resetSharedCloudStoreOnNextLaunch"
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
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "VoucherWalletApp"
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
        let migrationVersion = 2
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
        guard defaults.integer(forKey: migrationVersionKey) < migrationVersion else { return }

        guard let privateStore,
              let root = privateStore.url?.deletingLastPathComponent() else { return }

        let context = container.viewContext
        do {
            let snapshots = try readLegacySwiftDataSnapshots(near: root)
            guard !snapshots.isEmpty else { return }

            try context.performAndWait {
                let existingVouchers = try context.fetch(Voucher.fetchRequest())
                var vouchersByID = Dictionary(
                    existingVouchers.map { ($0.id, $0) },
                    uniquingKeysWith: { existing, _ in existing }
                )
                let expenseIDs = Set(try context.fetch(Expense.fetchRequest()).map(\.id))
                var importedExpenseIDs = expenseIDs

                for snapshot in snapshots {
                    let codeType = CodeType(rawValue: snapshot.codeType) ?? .barcode
                    let voucher: Voucher
                    if let existingVoucher = vouchersByID[snapshot.id] {
                        voucher = existingVoucher
                        // Les anciens champs personnels/type de code ne sont pas repris par CloudKit.
                        voucher.codeType = codeType
                        voucher.codeImageData = snapshot.codeImageData
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
                    }

                    // Favoris et ordre sont personnels et doivent provenir du store local historique.
                    voucher.isFavorite = snapshot.isFavorite
                    voucher.sortOrder = snapshot.sortOrder

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
                try context.save()
            }
            defaults.set(migrationVersion, forKey: migrationVersionKey)
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
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        cloudSyncLog("Lecture historique persistant démarrée (\(reason))")

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
            cloudSyncLog("Aucune transaction distante à fusionner (\(reason))")
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
