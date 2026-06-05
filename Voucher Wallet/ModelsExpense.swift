//
//  ModelsExpense.swift
//  Voucher Wallet
//

import CoreData
import Foundation

@objc(Expense)
final class Expense: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var amount: Double
    @NSManaged var date: Date
    @NSManaged var note: String?
    @NSManaged var authorDisplayName: String?
    @NSManaged var authorRecordName: String?
    @NSManaged var sharingPeriodID: UUID?
    @NSManaged var archivedVoucherID: UUID?
    @NSManaged var voucher: Voucher?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.init(context: context)
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
    }
}

extension Expense {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Expense> {
        NSFetchRequest<Expense>(entityName: "Expense")
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

@objc(PersonalVoucherPreference)
final class PersonalVoucherPreference: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var voucherID: UUID
    @NSManaged var isFavorite: Bool
    @NSManaged var sortOrder: Int64
}

extension PersonalVoucherPreference {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PersonalVoucherPreference> {
        NSFetchRequest<PersonalVoucherPreference>(entityName: "PersonalVoucherPreference")
    }
}
