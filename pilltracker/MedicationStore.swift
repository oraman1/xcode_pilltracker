import Foundation
import Observation
import SwiftUI

@Observable
final class MedicationStore {
    var medications: [Medication] = [] {
        didSet { save() }
    }

    private let storageKey = "medications.v1"

    init() {
        load()
    }

    func add(_ medication: Medication) {
        medications.append(medication)
    }

    func update(_ medication: Medication) {
        guard let index = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        medications[index] = medication
    }

    func delete(at offsets: IndexSet) {
        medications.remove(atOffsets: offsets)
    }

    func delete(id: Medication.ID) {
        if let med = medications.first(where: { $0.id == id }), let photo = med.photoFilename {
            PhotoStorage.delete(filename: photo)
        }
        medications.removeAll { $0.id == id }
    }

    func setPhoto(_ image: UIImage, for medicationID: Medication.ID) {
        guard let index = medications.firstIndex(where: { $0.id == medicationID }) else { return }
        let oldFilename = medications[index].photoFilename
        guard let newFilename = PhotoStorage.save(image, replacing: oldFilename) else { return }
        medications[index].photoFilename = newFilename
    }

    func clearPhoto(for medicationID: Medication.ID) {
        guard let index = medications.firstIndex(where: { $0.id == medicationID }) else { return }
        if let filename = medications[index].photoFilename {
            PhotoStorage.delete(filename: filename)
        }
        medications[index].photoFilename = nil
    }

    func toggleCompletion(for medicationID: Medication.ID, time: TimeOfDay, on day: Date = Date()) {
        guard let index = medications.firstIndex(where: { $0.id == medicationID }) else { return }
        let doseDate = time.date(on: day)
        if medications[index].completions.contains(doseDate) {
            medications[index].completions.remove(doseDate)
        } else {
            medications[index].completions.insert(doseDate)
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(medications)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save medications: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            medications = try JSONDecoder().decode([Medication].self, from: data)
        } catch {
            print("Failed to load medications: \(error)")
        }
    }
}
