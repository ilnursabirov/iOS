//
//  ImageProcessor.swift
//  ImageGallery
//
//  Created by Сабиров Мльнур Марсович on 21.11.2024.
//

import UIKit

class ImageProcessor {
    static func applyFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CIPhotoEffectMono") else { return nil }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        if let outputImage = filter.outputImage,
           let cgImage = CIContext().createCGImage(outputImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

