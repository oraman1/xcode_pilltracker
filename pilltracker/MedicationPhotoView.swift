import SwiftUI
import PhotosUI
import UIKit

struct MedicationPhotoView: View {
    @Environment(MedicationStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let medicationID: Medication.ID

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingRemoveConfirm = false
    @State private var imageRefreshToken = UUID()

    private var medication: Medication? {
        store.medications.first(where: { $0.id == medicationID })
    }

    private var image: UIImage? {
        guard let filename = medication?.photoFilename else { return nil }
        _ = imageRefreshToken  // recompute when token changes
        return PhotoStorage.loadImage(filename: filename)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                } else {
                    placeholder
                }

                actions
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .navigationTitle(medication?.name ?? "Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: pickerItem) { _, newValue in
                guard let newValue else { return }
                Task { await loadFromPicker(newValue) }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { uiImage in
                    if let uiImage {
                        store.setPhoto(uiImage, for: medicationID)
                        imageRefreshToken = UUID()
                    }
                }
                .ignoresSafeArea()
            }
            .confirmationDialog(
                "Remove this photo?",
                isPresented: $showingRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    store.clearPhoto(for: medicationID)
                    imageRefreshToken = UUID()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No photo yet")
                .font(.headline)
            Text("Add a photo so you can identify this medication at a glance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button {
                showingPhotoPicker = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if medication?.photoFilename != nil {
                Button(role: .destructive) {
                    showingRemoveConfirm = true
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.red)
            }
        }
    }

    private func loadFromPicker(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        await MainActor.run {
            store.setPhoto(uiImage, for: medicationID)
            imageRefreshToken = UUID()
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage?) -> Void
        init(onPicked: @escaping (UIImage?) -> Void) { self.onPicked = onPicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { [onPicked] in onPicked(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { [onPicked] in onPicked(nil) }
        }
    }
}
