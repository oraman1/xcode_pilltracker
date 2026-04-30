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
    @State private var dayOffset: Int = 0

    private let dayRange = -60...60

    private var viewedDate: Date {
        Self.date(forOffset: dayOffset)
    }

    private static func date(forOffset offset: Int) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: offset, to: start) ?? start
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateHeader
                Divider()

                if store.medications.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $dayOffset) {
                        ForEach(dayRange, id: \.self) { offset in
                            DayPage(
                                date: Self.date(forOffset: offset),
                                onEdit: { editingMedication = $0 },
                                onPhoto: { photoMedication = $0 }
                            )
                            .tag(offset)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
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

    private var dateHeader: some View {
        HStack(spacing: 8) {
            Button {
                dayOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(dayOffset <= dayRange.lowerBound)

            Spacer()

            Button {
                if dayOffset != 0 { dayOffset = 0 }
            } label: {
                VStack(spacing: 2) {
                    Text(weekdayString)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(isToday ? Color.blue : Color.primary)
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !isToday {
                        Text("Tap to return to today")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                dayOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(dayOffset >= dayRange.upperBound)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(viewedDate)
    }

    private var weekdayString: String {
        viewedDate.formatted(.dateTime.weekday(.wide))
    }

    private var dateString: String {
        viewedDate.formatted(.dateTime.month(.wide).day().year())
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct DayPage: View {
    @Environment(MedicationStore.self) private var store
    let date: Date
    let onEdit: (Medication) -> Void
    let onPhoto: (Medication) -> Void

    private var scheduledMeds: [Medication] {
        let weekday = Calendar.current.component(.weekday, from: date)
        return store.medications.filter { $0.daysOfWeek.contains(weekday) }
    }

    var body: some View {
        Group {
            if scheduledMeds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No medications scheduled")
                        .font(.headline)
                    Text("Nothing is due on this day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(scheduledMeds) { medication in
                        MedicationRow(
                            medication: medication,
                            viewedDate: date,
                            onToggleTime: { time in
                                store.toggleCompletion(for: medication.id, time: time, on: date)
                            },
                            onEdit: { onEdit(medication) },
                            onPhoto: { onPhoto(medication) }
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

private struct MedicationRow: View {
    let medication: Medication
    let viewedDate: Date
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

                if let warning = medication.lowSupplyMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(warning)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                FlowLayout(spacing: 6) {
                    ForEach(medication.times) { time in
                        let status = medication.doseStatus(time: time, on: viewedDate)
                        TimeChip(
                            time: time,
                            status: status,
                            isNextDue: isNextDue(time: time),
                            action: { onToggleTime(time) }
                        )
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

    private func isNextDue(time: TimeOfDay) -> Bool {
        guard let next = nextDue else { return false }
        guard Calendar.current.isDate(next.day, inSameDayAs: viewedDate) else { return false }
        return next.time == time
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
    let status: Medication.DoseStatus
    let isNextDue: Bool
    let action: () -> Void

    private var textColor: Color {
        switch status {
        case .completed: return .white
        case .missed: return .red
        case .pending: return isNextDue ? .blue : .primary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .completed: return .accentColor
        case .missed: return Color.red.opacity(0.15)
        case .pending: return Color(.systemGray6)
        }
    }

    private var iconName: String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .pending: return "circle"
        }
    }

    private var fontWeight: Font.Weight {
        if status == .missed { return .bold }
        return isNextDue ? .bold : .semibold
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.body)
                Text(timeString)
                    .font(.body.weight(fontWeight))
                    .monospacedDigit()
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
