//
//  ModelsVoucher.swift
//  Voucher Wallet
//

import CoreData
import Foundation

nonisolated enum VoucherSharingRole {
    case none
    case owner
    case recipient
}

@objc(Voucher)
final class Voucher: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var storeName: String
    @NSManaged var amountValue: NSNumber?
    @NSManaged var voucherNumber: String
    @NSManaged var pinCode: String?
    @NSManaged var codeTypeValue: String
    @NSManaged var codeImageData: Data?
    @NSManaged var expirationDate: Date?
    @NSManaged var dateAdded: Date
    @NSManaged var pdfData: Data?
    @NSManaged var imageData: Data?
    @NSManaged var storeColor: String
    @NSManaged var textColor: String
    @NSManaged var spentBeforeCurrentShare: Double
    @NSManaged var activeSharingPeriodID: UUID?
    @NSManaged var sharingStartedAt: Date?
    @NSManaged var expenses: Set<Expense>?

    var amount: Double? {
        get { amountValue?.doubleValue }
        set { amountValue = newValue.map(NSNumber.init(value:)) }
    }

    var codeType: CodeType {
        get { CodeType(rawValue: codeTypeValue) ?? .barcode }
        set { codeTypeValue = newValue.rawValue }
    }

    var activeExpensesList: [Expense] {
        var seenIDs = Set<UUID>()
        return Array(expenses ?? []).filter { expense in
            guard expense.managedObjectContext != nil, !expense.isDeleted else { return false }
            guard let expenseID = expense.safeID else { return false }
            return seenIDs.insert(expenseID).inserted
        }
    }

    var expensesList: [Expense] {
        activeExpensesList
    }

    var remainingBalance: Double {
        guard let initialAmount = amount else { return 0 }
        let balance = initialAmount - expensesList.reduce(0) { $0 + $1.amount }
        let cents = Int((balance * 100).rounded())
        return cents == 0 ? 0 : Double(cents) / 100
    }

    var totalExpenses: Double {
        guard let initialAmount = amount else {
            return expensesList.reduce(0) { $0 + $1.amount }
        }
        return initialAmount - remainingBalance
    }

    var sharingRole: VoucherSharingRole {
        guard managedObjectContext != nil,
              let store = objectID.persistentStore else {
            return sharingStartedAt == nil ? .none : .owner
        }
        if store.configurationName == SharedModelContainer.sharedConfigurationName {
            return .recipient
        }
        return sharingStartedAt == nil ? .none : .owner
    }

    var isReceivedShare: Bool { sharingRole == .recipient }
    var isInActiveShare: Bool { sharingRole != .none }

    var isFavorite: Bool {
        get { preference?.isFavorite ?? false }
        set {
            let preference = preference ?? createPreference()
            preference?.isFavorite = newValue
        }
    }

    var sortOrder: Int {
        get { Int(preference?.sortOrder ?? 0) }
        set {
            let preference = preference ?? createPreference()
            preference?.sortOrder = Int64(newValue)
        }
    }

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        storeName: String,
        amount: Double? = nil,
        voucherNumber: String,
        pinCode: String? = nil,
        codeType: CodeType,
        codeImageData: Data? = nil,
        expirationDate: Date? = nil,
        dateAdded: Date = Date(),
        sortOrder: Int = 0,
        pdfData: Data? = nil,
        imageData: Data? = nil,
        storeColor: String = "#007AFF",
        textColor: String = "#FFFFFF"
    ) {
        self.init(context: context)
        SharedModelContainer.assignToPrivateStore(self, in: context)
        self.id = id
        self.storeName = storeName
        self.amount = amount
        self.voucherNumber = voucherNumber
        self.pinCode = pinCode
        self.codeType = codeType
        self.codeImageData = codeImageData
        self.expirationDate = expirationDate
        self.dateAdded = dateAdded
        self.pdfData = pdfData
        self.imageData = imageData
        self.storeColor = storeColor
        self.textColor = textColor
        self.spentBeforeCurrentShare = 0
        self.sortOrder = sortOrder
    }

    private var preference: PersonalVoucherPreference? {
        guard let context = managedObjectContext else { return nil }
        let request = PersonalVoucherPreference.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "voucherID == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    private func createPreference() -> PersonalVoucherPreference? {
        guard let context = managedObjectContext else { return nil }
        let item = PersonalVoucherPreference(context: context)
        item.id = UUID()
        item.voucherID = id
        item.isFavorite = false
        item.sortOrder = 0
        SharedModelContainer.assignToPrivateStore(item, in: context)
        return item
    }

    func deletePersonalPreference(in context: NSManagedObjectContext? = nil) {
        guard let context = context ?? managedObjectContext else { return }
        let request = PersonalVoucherPreference.fetchRequest()
        request.predicate = NSPredicate(format: "voucherID == %@", id as CVarArg)

        do {
            for item in try context.fetch(request) {
                context.delete(item)
            }
        } catch {
            debugLog("Impossible de supprimer les préférences du bon: \(error)")
        }
    }

}

extension Voucher {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Voucher> {
        NSFetchRequest<Voucher>(entityName: "Voucher")
    }

    var safeID: UUID? {
        guard managedObjectContext != nil, !isDeleted else { return nil }
        if let value = primitiveValue(forKey: "id") as? UUID {
            return value
        }
        if let value = primitiveValue(forKey: "id") as? NSUUID {
            return value as UUID
        }
        return nil
    }
}

enum CodeType: String, Codable, CaseIterable {
    case barcode
    case qrCode
}
