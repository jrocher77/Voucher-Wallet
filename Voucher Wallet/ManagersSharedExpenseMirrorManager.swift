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
        isDeleted,
        modifiedAt
    ]
}

extension VoucherSharingManager {
    private var sharedExpenseMirrorRetryDelays: [TimeInterval] {
        [0.7, 2.0, 5.0, 10.0]
    }

    func mirrorSharedExpense(_ expense: Expense, for voucher: Voucher, isDeleted: Bool = false) {
        let payload = sharedExpenseMirrorPayload(for: expense, voucher: voucher, isDeleted: isDeleted)
        let voucherObjectID = voucher.objectID
        let voucherID = voucher.id
        let shouldAttemptImmediately = voucher.isInActiveShare || Self.storedShareZone(for: voucherID) != nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            if !shouldAttemptImmediately {
                guard let share = try? await self.share(for: voucherObjectID) else { return }
                self.rememberShareZone(share.recordID.zoneID, for: voucherID)
            }
            await self.saveSharedExpenseMirror(payload, voucherObjectID: voucherObjectID, attempt: 0)
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

    func refreshSharedExpenseMirrors(
        for vouchers: [Voucher],
        retryDelays: [TimeInterval]
    ) async -> Bool {
        var didChange = await refreshSharedExpenseMirrors(for: vouchers)
        for delay in retryDelays where !didChange {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            didChange = await refreshSharedExpenseMirrors(for: vouchers)
        }
        return didChange
    }

    private func saveSharedExpenseMirror(
        _ payload: SharedExpenseMirrorPayload,
        voucherObjectID: NSManagedObjectID,
        attempt: Int
    ) async {
        guard let voucher = try? persistence.container.viewContext.existingObject(with: voucherObjectID) as? Voucher else {
            debugLog("[Partage][Miroir] Sauvegarde ignorée: bon introuvable")
            return
        }

        guard let zoneID = await shareZoneID(for: voucher) else {
            scheduleSharedExpenseMirrorRetry(
                payload,
                voucherObjectID: voucherObjectID,
                attempt: attempt,
                reason: "zone du partage introuvable"
            )
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
        record[SharedExpenseMirrorRecord.isDeleted] = (payload.isDeleted ? 1 : 0) as CKRecordValue
        record[SharedExpenseMirrorRecord.modifiedAt] = Date() as CKRecordValue

        do {
            _ = try await database.save(record)
            debugLog("[Partage][Miroir] Dépense miroir sauvegardée (tentative \(attempt + 1))")
        } catch {
            if shouldRetrySharedExpenseMirrorSave(after: error) {
                scheduleSharedExpenseMirrorRetry(
                    payload,
                    voucherObjectID: voucherObjectID,
                    attempt: attempt,
                    reason: error.localizedDescription
                )
            } else {
                debugLog("[Partage][Miroir] Sauvegarde CloudKit impossible: \(error.localizedDescription)")
            }
        }
    }

    private func scheduleSharedExpenseMirrorRetry(
        _ payload: SharedExpenseMirrorPayload,
        voucherObjectID: NSManagedObjectID,
        attempt: Int,
        reason: String
    ) {
        guard attempt < sharedExpenseMirrorRetryDelays.count else {
            debugLog("[Partage][Miroir] Sauvegarde abandonnée après \(attempt + 1) tentative(s): \(reason)")
            return
        }

        let delay = sharedExpenseMirrorRetryDelays[attempt]
        debugLog("[Partage][Miroir] Nouvelle tentative dans \(delay)s: \(reason)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.saveSharedExpenseMirror(
                    payload,
                    voucherObjectID: voucherObjectID,
                    attempt: attempt + 1
                )
            }
        }
    }

    private func shouldRetrySharedExpenseMirrorSave(after error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("not authenticated") == false &&
            description.contains("permission") == false &&
            description.contains("not authorized") == false
    }

    private func importSharedExpenseMirrors(for voucher: Voucher) async -> Bool {
        guard let zoneID = await shareZoneID(for: voucher) else { return false }

        let query = CKQuery(
            recordType: SharedExpenseMirrorRecord.recordType,
            predicate: NSPredicate(format: "%K == %@", SharedExpenseMirrorRecord.voucherID, voucher.id.uuidString)
        )
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
                into: voucher
            )

            while let cursor = result.queryCursor {
                result = try await database.records(
                    continuingMatchFrom: cursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: 100
                )
                didChange = importSharedExpenseMirrorResults(
                    result.matchResults,
                    into: voucher
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
        into voucher: Voucher
    ) -> Bool {
        var didChange = false
        for (_, recordResult) in results {
            guard case .success(let record) = recordResult else {
                continue
            }
            didChange = importSharedExpenseMirror(record, into: voucher) || didChange
        }
        return didChange
    }

    private func importSharedExpenseMirror(_ record: CKRecord, into voucher: Voucher) -> Bool {
        guard isImportableSharedVoucher(voucher),
              stringValue(record[SharedExpenseMirrorRecord.voucherID]) == voucher.id.uuidString else {
            return false
        }

        guard let expenseIDString = stringValue(record[SharedExpenseMirrorRecord.expenseID]),
              let expenseID = UUID(uuidString: expenseIDString) else {
            return false
        }

        let isDeleted = boolValue(record[SharedExpenseMirrorRecord.isDeleted])
        let context = persistence.container.viewContext

        guard let recordAmount = doubleValue(record[SharedExpenseMirrorRecord.amount]),
              let date = record[SharedExpenseMirrorRecord.date] as? Date else {
            return false
        }
        let amount = isDeleted ? 0 : recordAmount

        let matchingExpenses = fetchExpenses(with: expenseID, in: context)
        let existing = preferredExistingExpense(from: matchingExpenses, for: voucher)
        guard existing != nil || !isDeleted else {
            return false
        }

        let expense = existing ?? Expense(context: context, id: expenseID, amount: amount, date: date)
        if existing == nil {
            SharedModelContainer.assign(expense, toStoreOf: voucher)
            expense.voucher = voucher
        } else if expense.voucher == nil {
            expense.voucher = voucher
        }

        var didChange = existing == nil
        didChange = mergeDuplicateExpenses(
            matchingExpenses.filter {
                $0.objectID != expense.objectID && canMergeExpense($0, into: expense, for: voucher)
            },
            into: expense,
            in: context
        ) || didChange
        didChange = update(&expense.amount, amount) || didChange
        didChange = update(&expense.date, date) || didChange
        didChange = update(&expense.note, stringValue(record[SharedExpenseMirrorRecord.note])) || didChange
        didChange = update(&expense.authorDisplayName, stringValue(record[SharedExpenseMirrorRecord.authorDisplayName])) || didChange
        didChange = update(&expense.authorRecordName, stringValue(record[SharedExpenseMirrorRecord.authorRecordName])) || didChange
        return didChange
    }

    private func isImportableSharedVoucher(_ voucher: Voucher) -> Bool {
        voucher.managedObjectContext != nil &&
            !voucher.isDeleted &&
            voucher.objectID.persistentStore != nil &&
            voucher.isInActiveShare
    }

    private func fetchExpenses(with id: UUID, in context: NSManagedObjectContext) -> [Expense] {
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? context.fetch(request)) ?? []
    }

    private func preferredExistingExpense(from expenses: [Expense], for voucher: Voucher) -> Expense? {
        expenses.first { expense in
            isReusableExpense(expense, for: voucher) &&
                expense.voucher?.id == voucher.id
        } ?? expenses.first { expense in
            isReusableExpense(expense, for: voucher) &&
                expense.voucher == nil
        }
    }

    private func isReusableExpense(_ expense: Expense, for voucher: Voucher) -> Bool {
        guard expense.managedObjectContext != nil,
              !expense.isDeleted,
              expense.objectID.persistentStore == voucher.objectID.persistentStore else {
            return false
        }
        return expense.voucher == nil || expense.voucher?.id == voucher.id
    }

    private func canMergeExpense(_ expense: Expense, into canonical: Expense, for voucher: Voucher) -> Bool {
        isReusableExpense(expense, for: voucher) &&
            expense.objectID.persistentStore == canonical.objectID.persistentStore
    }

    private func mergeDuplicateExpenses(
        _ duplicates: [Expense],
        into canonical: Expense,
        in context: NSManagedObjectContext
    ) -> Bool {
        var didChange = false
        for duplicate in duplicates where duplicate.managedObjectContext != nil && !duplicate.isDeleted {
            if canonical.note == nil {
                canonical.note = duplicate.note
            }
            if canonical.authorDisplayName == nil {
                canonical.authorDisplayName = duplicate.authorDisplayName
            }
            if canonical.authorRecordName == nil {
                canonical.authorRecordName = duplicate.authorRecordName
            }
            context.delete(duplicate)
            didChange = true
        }
        return didChange
    }

    private func shareZoneID(for voucher: Voucher) async -> CKRecordZone.ID? {
        if let storedZoneID = Self.storedShareZone(for: voucher.id) {
            return storedZoneID
        }
        if let share = try? await share(for: voucher.objectID) {
            rememberShareZone(share.recordID.zoneID, for: voucher.id)
            return share.recordID.zoneID
        }
        return nil
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
