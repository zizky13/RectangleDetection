//
//  ExpoFloorAnalyzer.swift
//  RectangleDetection
//
//  Created by Zikar Nurizky on 22/07/25.
//

import Foundation
import Vision
import UIKit


class ExpoFloorPlanAnalyzer: ObservableObject {
    @Published var detectedBooths: [DetectedBooth] = []
    @Published var isAnalyzing = false
    @Published var processedImage: UIImage?
    
    // Main function to detect rectangles in floor plan
    func detectBoothsInFloorPlan(image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Failed to convert UIImage to CGImage")
            return
        }
        
        isAnalyzing = true
        
        // Create the rectangle detection request
        let rectangleRequest = VNDetectRectanglesRequest { [weak self] (request, error) in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                
                if let error = error {
                    print("Rectangle detection error: \(error)")
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation] else {
                    print("No rectangle observations found")
                    return
                }
                
                // Convert observations to booth structure
                self?.processRectangleObservations(observations, imageSize: image.size)
                
                // Create processed image with rectangles
                self?.createProcessedImage(from: image, booths: self?.detectedBooths ?? [])
            }
        }
        
        // Configure the request parameters
        rectangleRequest.maximumObservations = 50
        rectangleRequest.minimumConfidence = 0.6
        rectangleRequest.minimumAspectRatio = 0.3
        rectangleRequest.minimumSize = 0.01
        
        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([rectangleRequest])
            } catch {
                print("Failed to perform rectangle detection: \(error)")
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    // Convert Vision observations to booth structure
    private func processRectangleObservations(_ observations: [VNRectangleObservation], imageSize: CGSize) {
        
        let booths = observations.compactMap { observation in
            // Convert normalized coordinates to actual image coordinates
            let topLeft = CGPoint(
                x: observation.topLeft.x * imageSize.width,
                y: (1 - observation.topLeft.y) * imageSize.height
            )
            let topRight = CGPoint(
                x: observation.topRight.x * imageSize.width,
                y: (1 - observation.topRight.y) * imageSize.height
            )
            let bottomLeft = CGPoint(
                x: observation.bottomLeft.x * imageSize.width,
                y: (1 - observation.bottomLeft.y) * imageSize.height
            )
            let bottomRight = CGPoint(
                x: observation.bottomRight.x * imageSize.width,
                y: (1 - observation.bottomRight.y) * imageSize.height
            )
            
            let corners = [topLeft, topRight, bottomRight, bottomLeft]
            
            // Calculate bounding box
            let boundingBox = CGRect(
                x: observation.boundingBox.origin.x * imageSize.width,
                y: (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * imageSize.height,
                width: observation.boundingBox.width * imageSize.width,
                height: observation.boundingBox.height * imageSize.height
            )
            
            // Calculate area
            let area = boundingBox.width * boundingBox.height
            
            return DetectedBooth(
                corners: corners,
                boundingBox: boundingBox,
                confidence: observation.confidence,
                area: area
            )
        }
        .sorted { $0.area > $1.area }
        
        // Filter relevant booths
        self.detectedBooths = filterRelevantBooths(booths, imageSize: imageSize)
    }
    
    // Filter booths based on size and position
    private func filterRelevantBooths(_ booths: [DetectedBooth], imageSize: CGSize) -> [DetectedBooth] {
        return booths.filter { booth in
            let minArea: CGFloat = (imageSize.width * imageSize.height) * 0.001
            let maxArea: CGFloat = (imageSize.width * imageSize.height) * 0.1
            let areaOK = booth.area >= minArea && booth.area <= maxArea
            
            let aspectRatio = booth.boundingBox.width / booth.boundingBox.height
            let aspectRatioOK = aspectRatio >= 0.3 && aspectRatio <= 3.0
            
            let confidenceOK = booth.confidence >= 0.7
            
            return areaOK && aspectRatioOK && confidenceOK
        }
    }
    
    // Create processed image with rectangles drawn
    private func createProcessedImage(from image: UIImage, booths: [DetectedBooth]) {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let imageWithBooths = renderer.image { context in
            image.draw(at: .zero)
            
            let cgContext = context.cgContext
            cgContext.setStrokeColor(UIColor.red.cgColor)
            cgContext.setLineWidth(3.0)
            
            for booth in booths {
                cgContext.addRect(booth.boundingBox)
                cgContext.strokePath()
                
                let confidenceText = String(format: "%.1f", booth.confidence)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.red,
                    .font: UIFont.systemFont(ofSize: 16, weight: .bold)
                ]
                
                confidenceText.draw(at: booth.boundingBox.origin, withAttributes: textAttributes)
            }
        }
        
        self.processedImage = imageWithBooths
    }
}
