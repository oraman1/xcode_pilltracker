import Foundation
import UIKit

enum PhotoStorage {
    private static let folderName = "medication_photos"

    private static var folderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func url(for filename: String) -> URL {
        folderURL.appendingPathComponent(filename)
    }

    static func loadImage(filename: String) -> UIImage? {
        let url = url(for: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Saves the image as a JPEG, returning the filename used.
    static func save(_ image: UIImage, replacing oldFilename: String? = nil) -> String? {
        // Constrain very large originals to keep storage reasonable.
        let resized = image.resizedForStorage()
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = url(for: filename)
        do {
            try data.write(to: url, options: .atomic)
            if let oldFilename, oldFilename != filename {
                delete(filename: oldFilename)
            }
            return filename
        } catch {
            print("Failed to save photo: \(error)")
            return nil
        }
    }

    static func delete(filename: String) {
        let url = url(for: filename)
        try? FileManager.default.removeItem(at: url)
    }
}

private extension UIImage {
    func resizedForStorage(maxDimension: CGFloat = 1600) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
