//
//  ManagersSharedExpenseMirrorManager.swift
//  Voucher Wallet
//

import CloudKit
import CoreData
import Foundation

private struct SharedExpenseMirrorPayload {
    let voucherID: UUID
    let expenseID: UUID
    let amount: Double
    let date: Date
    let note: String?
    let authorDisplayName: String?
    let authorRecordName: String?
    let sharingPeriodID: UUID?
    let isDeleted: Bool
}

private enum SharedExpenseMirrorRecord {
    static let recordType = "SharedExpenseMirror"
    static let voucherID = "voucherID"
    static let expenseID = "expenseID"
    static let amount = "amount"
    static let date = "date"
    static let note = "note"
    static let authorDisplayName = "authorDisplayName"
    static let authorRecordName = "authorRecordName"
    static let sharingPeriodID = "sharingPeriodID"
    static let isDeleted = "isDeleted"
    static let modifiedAt = "modifiedAt"

    static let importDesiredKeys = [
        voucherID,
        expenseID,
        amount,
        date,
        note,
        authorDisplayName,
        authorRecordName,
        sharingPeriodID,
        isDeleted,
        modifiedAt
    ]
}

extension VoucherSharingManager {
    private var locallyDeletedSharedExpenseDefaultsKey: String {
        "locallyDeletedSharedExpenseIDs"
    }

    @discardableResult
    func purgeLocallyDeletedSharedExpenses(for vouchers: [Voucher]) -> Bool {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
        guard defaults.stringArray(forKey: locallyDeletedSharedExpenseDefaultsKey)?.isEmpty == false else {
            return false
        }
        defaults.removeObject(forKey: locallyDeletedSharedExpenseDefaultsKey)
        return false
    }

    func mirrorSharedExpense(_ expense: Expense, for voucher: Voucher, isDeleted: Bool = false) {
        guard voucher.isInActiveShare else { return }
        let payload = sharedExpenseMirrorPayload(for: expense, voucher: voucher, isDeleted: isDeleted)
        let voucherObjectID = voucher.objectID

        Task { @MainActor [weak self] in
            await self?.saveSharedExpenseMirror(payload, voucherObjectID: voucherObjectID)
        }
    }

    private func sharedExpenseMirrorPayload(
        for expense: Expense,
        voucher: Voucher,
        isDeleted: Bool
    ) -> SharedExpenseMirrorPayload {
        SharedExpenseMirrorPayload(
            voucherID: voucher.id,
            expenseID: expense.id,
            amount: expense.amount,
            date: expense.date,
            note: expense.note,
            authorDisplayName: expense.authorDisplayName,
            authorRecordName: expense.authorRecordName,
            sharingPeriodID: expense.sharingPeriodID,
            isDeleted: isDeleted
        )
    }

    func refreshSharedExpenseMirrors(for vouchers: [Voucher]) async -> Bool {
        var didChange = false
        for voucher in vouchers where voucher.isInActiveShare && voucher.managedObjectContext != nil && !voucher.isDeleted {
            didChange = await importSharedExpenseMirrors(for: voucher) || didChange
        }
        guard didChange else { return false }

        do {
            try persistence.container.viewContext.save()
            persistence.container.viewContext.processPendingChanges()
            WidgetReloader.reloadAllWidgets()
            return true
        } catch {
            debugLog("[Partage][Miroir] Import sauvegarde locale impossible: \(error.localizedDescription)")
            return false
        }
    }

    private func saveSharedExpenseMirror(
        _ payload: SharedExpenseMirrorPayload,
        voucherObjectID: NSManagedObjectID
    ) async {
        guard let voucher = try? persistence.container.viewContext.existingObject(with: voucherObjectID) as? Voucher,
              let zoneID = await shareZoneID(for: voucher) else {
            debugLog("[Partage][Miroir] Sauvegarde ignoree: zone du partage introuvable")
            return
        }

        let recordID = CKRecord.ID(
            recordName: "SharedExpenseMirror-\(payload.expenseID.uuidString)",
            zoneID: zoneID
        )
        let database = cloudDatabase(for: voucher)
        let record = (try? await database.record(for: recordID))
            ?? CKRecord(recordType: SharedExpenseMirrorRecord.recordType, recordID: recordID)

        record[SharedExpenseMirrorRecord.voucherID] = payload.voucherID.uuidString as CKRecordValue
        record[SharedExpenseMirrorRecord.expenseID] = payload.expenseID.uuidString as CKRecordValue
        record[SharedExpenseMirrorRecord.amount] = payload.amount as CKRecordValue
        record[SharedExpenseMirrorRecord.date] = payload.date as CKRecordValue
        record[SharedExpenseMirrorRecord.note] = payload.note as CKRecordValue?
        record[SharedExpenseMirrorRecord.authorDisplayName] = payload.authorDisplayName as CKRecordValue?
        record[SharedExpenseMirrorRecord.authorRecordName] = payload.authorRecordName as CKRecordValue?
        record[SharedExpenseMirrorRecord.sharingPeriodID] = payload.sharingPeriodID?.uuidString as CKRecordValue?
        record[SharedExpenseMirrorRecord.isDeleted] = (payload.isDeleted ? 1 : 0) as CKRecordValue
        record[SharedExpenseMirrorRecord.modifiedAt] = Date() as CKRecordValue

        do {
            _ = try await database.save(record)
        } catch {
            debugLog("[Partage][Miroir] Sauvegarde CloudKit impossible: \(error.localizedDescription)")
        }
    }

    private func importSharedExpenseMirrors(for voucher: Voucher) async -> Bool {
        guard let zoneID = await shareZoneID(for: voucher) else { return false }

        let query = CKQuery(
            recordType: SharedExpenseMirrorRecord.recordType,
            predicate: NSPredicate(format: "%K == %@", SharedExpenseMirrorRecord.voucherID, voucher.id.uuidString)
        )
        let currentSharingPeriodID = voucher.activeSharingPeriodID
        let desiredKeys = SharedExpenseMirrorRecord.importDesiredKeys
        let database = cloudDatabase(for: voucher)

        do {
            var result = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                desiredKeys: desiredKeys,
                resultsLimit: 100
            )
            var didChange = importSharedExpenseMirrorResults(
                result.matchResults,
                into: voucher,
                currentSharingPeriodID: currentSharingPeriodID,
                sharingStartedAt: voucher.sharingStartedAt
            )

            while let cursor = result.queryCursor {
                result = try await database.records(
                    continuingMatchFrom: cursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: 100
                )
                didChange = importSharedExpenseMirrorResults(
                    result.matchResults,
                    into: voucher,
                    currentSharingPeriodID: currentSharingPeriodID,
                    sharingStartedAt: voucher.sharingStartedAt
                ) || didChange
            }

            if didChange {
                NotificationCenter.default.post(name: .voucherExpensesDidChange, object: voucher.id)
                NotificationCenter.default.post(name: .voucherDidChange, object: voucher.id)
            }
            return didChange
        } catch {
            debugLog("[Partage][Miroir] Lecture CloudKit impossible: \(error.localizedDescription)")
            return false
        }
    }

    private func importSharedExpenseMirrorResults(
        _ results: [(CKRecord.ID, Result<CKRecord, any Error>)],
        into voucher: Voucher,
        currentSharingPeriodID: UUID?,
        sharingStartedAt: Date?
    ) -> Bool {
        var didChange = false
        for (_, recordResult) in results {
            guard case .success(let record) = recordResult,
                  mirrorRecord(record, belongsTo: currentSharingPeriodID, sharingStartedAt: sharingStartedAt) else {
                continue
            }
            didChange = importSharedExpenseMirror(record, into: voucher) || didChange
        }
        return didChange
    }

    private func mirrorRecord(
        _ record: CKRecord,
        belongsTo currentSharingPeriodID: UUID?,
        sharingStartedAt: Date?
    ) -> Bool {
        guard let recordSharingPeriodIDString = stringValue(record[SharedExpenseMirrorRecord.sharingPeriodID]) else {
            guard currentSharingPeriodID != nil else { return true }
            guard let sharingStartedAt else { return true }
            let modifiedAt = record[SharedExpenseMirrorRecord.modifiedAt] as? Date ?? record.modificationDate
            guard let modifiedAt else { return false }
            return modifiedAt >= sharingStartedAt.addingTimeInterval(-5)
        }

        guard let currentSharingPeriodID,
              let recordSharingPeriodID = UUID(uuidString: recordSharingPeriodIDString) else {
            return false
        }
        return recordSharingPeriodID == currentSharingPeriodID
    }

    private func importSharedExpenseMirror(_ record: CKRecord, into voucher: Voucher) -> Bool {
        guard let expenseIDString = stringValue(record[SharedExpenseMirrorRecord.expenseID]),
              let expenseID = UUID(uuidString: expenseIDString) else {
            return false
        }

        let isDeleted = boolValue(record[SharedExpenseMirrorRecord.isDeleted])
        let context = persistence.container.viewContext
        let existing = voucher.activeExpensesList.first { $0.id == expenseID }

        guard let recordAmount = doubleValue(record[SharedExpenseMirrorRecord.amount]),
              let date = record[SharedExpenseMirrorRecord.date] as? Date else {
            return false
        }
        let amount = isDeleted ? 0 : recordAmount

        let expense = existing ?? Expense(context: context, id: expenseID, amount: amount, date: date)
        if existing == nil {
            SharedModelContainer.assign(expense, toStoreOf: voucher)
            expense.voucher = voucher
        }

        var didChange = existing == nil
        didChange = update(&expense.amount, amount) || didChange
        didChange = update(&expense.date, date) || didChange
        didChange = update(&expense.note, stringValue(record[SharedExpenseMirrorRecord.note])) || didChange
        didChange = update(&expense.authorDisplayName, stringValue(record[SharedExpenseMirrorRecord.authorDisplayName])) || didChange
        didChange = update(&expense.authorRecordName, stringValue(record[SharedExpenseMirrorRecord.authorRecordName])) || didChange
        let sharingPeriodID = stringValue(record[SharedExpenseMirrorRecord.sharingPeriodID]).flatMap(UUID.init(uuidString:))
        didChange = update(&expense.sharingPeriodID, sharingPeriodID) || didChange
        return didChange
    }

    private func shareZoneID(for voucher: Voucher) async -> CKRecordZone.ID? {
        if let share = try? await share(for: voucher.objectID) {
            return share.recordID.zoneID
        }
        return share(for: voucher)?.recordID.zoneID
    }

    private func cloudDatabase(for voucher: Voucher) -> CKDatabase {
        let container = CKContainer(identifier: SharedModelContainer.cloudKitContainerIdentifier)
        return voucher.isReceivedShare ? container.sharedCloudDatabase : container.privateCloudDatabase
    }

    private func stringValue(_ value: CKRecordValue?) -> String? {
        value as? String
    }

    private func doubleValue(_ value: CKRecordValue?) -> Double? {
        if let value = value as? Double { return value }
        return (value as? NSNumber)?.doubleValue
    }

    private func boolValue(_ value: CKRecordValue?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? Int64 { return value != 0 }
        if let value = value as? NSNumber { return value.boolValue }
        return false
    }

    private func update<T: Equatable>(_ value: inout T, _ newValue: T) -> Bool {
        guard value != newValue else { return false }
        value = newValue
        return true
    }
}
