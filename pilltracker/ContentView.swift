//
//  ContentView.swift
//  pilltracker
//
//  Created by Imran Rahim on 26/04/2026.
//  My First IOS app
//

import SwiftUI

struct ContentView: View {
    @Environment(MedicationStore.self) private var store
    @State private var showingAdd = false
    @State private var editingMedication: Medication?
    @State private var photoMedication: Medication?

    var body: some View {
        NavigationStack {
            Group {
                if store.medications.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.medications) { medication in
                            MedicationRow(
                                medication: medication,
                                onToggleTime: { time in
                                    store.toggleCompletion(for: medication.id, time: time)
                                },
                                onEdit: { editingMedication = medication },
                                onPhoto: { photoMedication = medication }
                            )
                        }
                        .onDelete(perform: store.delete)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Pill Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MedicationFormView(mode: .add)
            }
            .sheet(item: $editingMedication) { medication in
                MedicationFormView(mode: .edit(medication))
            }
            .sheet(item: $photoMedication) { medication in
                MedicationPhotoView(medicationID: medication.id)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("No medications yet")
                .font(.headline)
            Text("Tap + to add your first medication.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct MedicationRow: View {
    let medication: Medication
    let onToggleTime: (TimeOfDay) -> Void
    let onEdit: () -> Void
    let onPhoto: () -> Void

    @State private var rowWidth: CGFloat = 0
    private let photoSpacing: CGFloat = 12

    private var photoSize: CGFloat {
        guard rowWidth > 0 else { return 110 }
        return max(80, (rowWidth - photoSpacing) / 3)
    }

    var body: some View {
        HStack(alignment: .top, spacing: photoSpacing) {
            PhotoPanel(medication: medication, action: onPhoto, size: photoSize)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Button(action: onEdit) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(medication.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            if !medication.dose.isEmpty {
                                Text(medication.dose)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            daysText
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(medication.currentStreak())")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                        Text("streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                FlowLayout(spacing: 6) {
                    ForEach(medication.times) { time in
                        TimeChip(
                            time: time,
                            isCompleted: medication.isCompleted(time: time, on: Date()),
                            isEnabled: medication.isScheduledToday(),
                            isNextDue: isNextDueToday(time: time)
                        ) {
                            onToggleTime(time)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: RowWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(RowWidthKey.self) { rowWidth = $0 }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Edit") { onEdit() }
                .tint(.blue)
        }
    }

    private var nextDue: (day: Date, time: TimeOfDay)? {
        medication.nextDue()
    }

    private func isNextDueToday(time: TimeOfDay) -> Bool {
        guard let next = nextDue else { return false }
        guard Calendar.current.isDateInToday(next.day) else { return false }
        return next.time == time
    }

    private var daysText: Text {
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]
        let weekends: Set<Int> = [1, 7]
        if medication.daysOfWeek.count == 7 {
            return Text("Every day").foregroundStyle(.secondary)
        }
        if medication.daysOfWeek == weekdays {
            return Text("Weekdays").foregroundStyle(.secondary)
        }
        if medication.daysOfWeek == weekends {
            return Text("Weekends").foregroundStyle(.secondary)
        }

        let nextWeekday = nextDue.map { Calendar.current.component(.weekday, from: $0.day) }
        let days = Weekday.allCases.filter { medication.daysOfWeek.contains($0.rawValue) }

        return days.enumerated().reduce(Text("")) { acc, pair in
            let (idx, day) = pair
            let isNext = day.rawValue == nextWeekday
            var dayText = Text(day.shortLabel)
            if isNext {
                dayText = dayText.foregroundColor(.blue).bold()
            } else {
                dayText = dayText.foregroundStyle(.secondary)
            }
            let separator = idx == 0 ? Text("") : Text(", ").foregroundStyle(.secondary)
            return acc + separator + dayText
        }
    }
}

private struct PhotoPanel: View {
    let medication: Medication
    let action: () -> Void
    let size: CGFloat

    var body: some View {
        Button(action: action) {
            ZStack {
                if let filename = medication.photoFilename,
                   let image = PhotoStorage.loadImage(filename: filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Add photo")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(medication.photoFilename == nil ? "Add photo" : "View photo")
    }
}

private struct RowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TimeChip: View {
    let time: TimeOfDay
    let isCompleted: Bool
    let isEnabled: Bool
    let isNextDue: Bool
    let action: () -> Void

    private var textColor: Color {
        if isCompleted { return .white }
        if isNextDue { return .blue }
        return .primary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                Text(timeString)
                    .font(.body.weight(isNextDue ? .bold : .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isCompleted ? Color.accentColor : Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time.date(on: Date()))
    }
}

// Wrap chips onto multiple lines when they overflow.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxX = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ContentView()
        .environment(MedicationStore())
}
