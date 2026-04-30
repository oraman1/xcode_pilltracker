import SwiftUI

struct MedicationFormView: View {
    enum Mode {
        case add
        case edit(Medication)
    }

    @Environment(MedicationStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String
    @State private var selectedDays: Set<Int>
    @State private var times: [TimeOfDay]
    @State private var dose: String
    @State private var dosesAvailableText: String
    @State private var notes: String
    @State private var showingDeleteConfirm = false

    init(mode: Mode = .add) {
        self.mode = mode
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _selectedDays = State(initialValue: [])
            _times = State(initialValue: [TimeOfDay(hour: 9, minute: 0)])
            _dose = State(initialValue: "")
            _dosesAvailableText = State(initialValue: "")
            _notes = State(initialValue: "")
        case .edit(let med):
            _name = State(initialValue: med.name)
            _selectedDays = State(initialValue: med.daysOfWeek)
            _times = State(initialValue: med.times)
            _dose = State(initialValue: med.dose)
            _dosesAvailableText = State(initialValue: med.dosesAvailable.map(String.init) ?? "")
            _notes = State(initialValue: med.notes)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("e.g. Paracetamol", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Dose") {
                        TextField("e.g. 1 tablet", text: $dose)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Remaining Doses") {
                        TextField("0", text: $dosesAvailableText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Medication")
                } footer: {
                    Text("Assumes the dosage is the same at every dose. The amount available will count down by one each time you mark a dose complete.")
                }

                Section("Days of week") {
                    HStack(spacing: 6) {
                        ForEach(Weekday.allCases) { day in
                            DayToggle(
                                label: day.shortLabel,
                                isSelected: selectedDays.contains(day.rawValue)
                            ) {
                                if selectedDays.contains(day.rawValue) {
                                    selectedDays.remove(day.rawValue)
                                } else {
                                    selectedDays.insert(day.rawValue)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach($times) { $time in
                        HStack {
                            DatePicker(
                                "Time",
                                selection: dateBinding(for: $time),
                                displayedComponents: .hourAndMinute
                            )
                            if times.count > 1 {
                                Button {
                                    times.removeAll { $0.id == time.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Delete time")
                            }
                        }
                    }
                    .onDelete { offsets in
                        guard times.count - offsets.count >= 1 else { return }
                        times.remove(atOffsets: offsets)
                    }
                    Button {
                        addTime()
                    } label: {
                        Label("Add time", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Times")
                } footer: {
                    Text("Add every time of day this medication should be taken. At least one is required.")
                }

                Section("Notes") {
                    TextField("Add notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if case .edit = mode {
                    Section {
                        Button {
                            dose = ""
                            dosesAvailableText = ""
                        } label: {
                            HStack {
                                Spacer()
                                Label("Reset Medication", systemImage: "arrow.counterclockwise")
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("Use this when a repeat prescription arrives. Re-enter the dose and amount available, then save.")
                    }

                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Medication")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Delete this medication?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteMedication() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the medication and its streak history. This can't be undone.")
            }
        }
    }

    private func deleteMedication() {
        guard case .edit(let med) = mode else { return }
        store.delete(id: med.id)
        dismiss()
    }

    private func dateBinding(for time: Binding<TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: time.wrappedValue.hour,
                    minute: time.wrappedValue.minute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                time.wrappedValue.hour = comps.hour ?? 0
                time.wrappedValue.minute = comps.minute ?? 0
            }
        )
    }

    private func addTime() {
        // Default to one hour after the latest time, or noon if there are none.
        let next: TimeOfDay
        if let last = times.max() {
            let totalMinutes = (last.hour * 60 + last.minute + 60) % (24 * 60)
            next = TimeOfDay(hour: totalMinutes / 60, minute: totalMinutes % 60)
        } else {
            next = TimeOfDay(hour: 12, minute: 0)
        }
        times.append(next)
    }

    private var navigationTitle: String {
        switch mode {
        case .add: return "New Medication"
        case .edit: return "Edit Medication"
        }
    }

    private var parsedDosesAvailable: Int? {
        let trimmed = dosesAvailableText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !selectedDays.isEmpty
            && !times.isEmpty
            && !dose.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedDosesAvailable != nil
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDose = dose.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortedTimes = times.sorted()
        let supply = parsedDosesAvailable

        switch mode {
        case .add:
            let med = Medication(
                name: trimmedName,
                daysOfWeek: selectedDays,
                times: sortedTimes,
                dose: trimmedDose,
                dosesAvailable: supply,
                notes: trimmedNotes
            )
            store.add(med)
        case .edit(let original):
            var updated = original
            updated.name = trimmedName
            updated.daysOfWeek = selectedDays
            updated.times = sortedTimes
            updated.dose = trimmedDose
            updated.dosesAvailable = supply
            updated.notes = trimmedNotes
            store.update(updated)
        }
        dismiss()
    }
}

private struct DayToggle: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Add") {
    MedicationFormView(mode: .add)
        .environment(MedicationStore())
}

#Preview("Edit") {
    MedicationFormView(mode: .edit(Medication(name: "Vitamin D", daysOfWeek: [2, 4, 6], times: [TimeOfDay(hour: 8, minute: 30), TimeOfDay(hour: 20, minute: 0)])))
        .environment(MedicationStore())
}
