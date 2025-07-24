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
    @Published var searchText = ""
    @Published var highlightedBoothId: UUID?
    
    private var originalImage: UIImage?
    
    // MARK: - Enhanced Detection with Multiple Strategies
    func detectBoothsInFloorPlan(image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Failed to convert UIImage to CGImage")
            return
        }
        
        originalImage = image
        isAnalyzing = true
        
        // Strategy 1: Preprocess image for better edge detection
        let preprocessedImage = preprocessForBetterDetection(image)
        
        // Strategy 2: Multiple detection passes with different parameters
        detectWithMultipleStrategies(preprocessedImage ?? image, cgImage: cgImage)
    }
    
    private func preprocessForBetterDetection(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let context = CIContext()
        
        // 1. Increase contrast significantly for faint booth boundaries
        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(2.0, forKey: kCIInputContrastKey) // High contrast
        contrastFilter.setValue(0.2, forKey: kCIInputBrightnessKey) // Slight brightness
        contrastFilter.setValue(1.3, forKey: kCIInputSaturationKey) // Enhance color separation
        
        guard let contrastOutput = contrastFilter.outputImage else { return nil }
        
        // 2. Apply edge enhancement to make boundaries more visible
        let sharpenFilter = CIFilter(name: "CIUnsharpMask")!
        sharpenFilter.setValue(contrastOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(1.0, forKey: kCIInputIntensityKey) // Strong sharpening
        sharpenFilter.setValue(3.0, forKey: kCIInputRadiusKey)
        
        guard let sharpenOutput = sharpenFilter.outputImage else { return nil }
        
        // 3. Optional: Convert to grayscale for better edge detection
        let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono")!
        grayscaleFilter.setValue(sharpenOutput, forKey: kCIInputImageKey)
        
        guard let finalOutput = grayscaleFilter.outputImage,
              let cgImage = context.createCGImage(finalOutput, from: finalOutput.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func detectWithMultipleStrategies(_ image: UIImage, cgImage: CGImage) {
        var allBooths: [DetectedBooth] = []
        let group = DispatchGroup()
        
        // Strategy 1: High sensitivity detection (for edge booths)
        group.enter()
        let highSensitivityRequest = createHighSensitivityRequest { booths in
            allBooths.append(contentsOf: booths)
            group.leave()
        }
        
        // Strategy 2: Standard detection
        group.enter()
        let standardRequest = createStandardRequest { booths in
            allBooths.append(contentsOf: booths)
            group.leave()
        }
        
        // Strategy 3: Small booth detection
        group.enter()
        let smallBoothRequest = createSmallBoothRequest { booths in
            allBooths.append(contentsOf: booths)
            group.leave()
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([highSensitivityRequest, standardRequest, smallBoothRequest])
                
                group.notify(queue: .main) {
                    // Merge all detections and remove duplicates
                    let mergedBooths = self.mergeDetections(allBooths, imageSize: image.size)
                    let boothsWithText = mergedBooths // Skip text detection for now to focus on rectangle accuracy
                    self.finishProcessing(booths: boothsWithText, image: image)
                }
            } catch {
                print("Failed to perform detection: \(error)")
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func createHighSensitivityRequest(_ completion: @escaping ([DetectedBooth]) -> Void) -> VNDetectRectanglesRequest {
        let request = VNDetectRectanglesRequest { [weak self] (request, error) in
            let booths = self?.processDetectionRequest(request, error: error, imageSize: self?.originalImage?.size ?? .zero) ?? []
            completion(booths)
        }
        
        // Very sensitive parameters for edge booths
        request.minimumConfidence = 0.1  // Very low confidence threshold
        request.minimumSize = 0.002      // Very small minimum size
        request.maximumObservations = 200 // Allow many detections
        request.minimumAspectRatio = 0.1  // Very flexible aspect ratio
        
        return request
    }
    
    private func createStandardRequest(_ completion: @escaping ([DetectedBooth]) -> Void) -> VNDetectRectanglesRequest {
        let request = VNDetectRectanglesRequest { [weak self] (request, error) in
            let booths = self?.processDetectionRequest(request, error: error, imageSize: self?.originalImage?.size ?? .zero) ?? []
            completion(booths)
        }
        
        // Standard parameters
        request.minimumConfidence = 0.4
        request.minimumSize = 0.005
        request.maximumObservations = 100
        request.minimumAspectRatio = 0.2
        
        return request
    }
    
    private func createSmallBoothRequest(_ completion: @escaping ([DetectedBooth]) -> Void) -> VNDetectRectanglesRequest {
        let request = VNDetectRectanglesRequest { [weak self] (request, error) in
            let booths = self?.processDetectionRequest(request, error: error, imageSize: self?.originalImage?.size ?? .zero) ?? []
            completion(booths)
        }
        
        // Optimized for small booths
        request.minimumConfidence = 0.2
        request.minimumSize = 0.001      // Very small
        request.maximumObservations = 150
        request.minimumAspectRatio = 0.15
        
        return request
    }
    
    private func processDetectionRequest(_ request: VNRequest, error: Error?, imageSize: CGSize) -> [DetectedBooth] {
        if let error = error {
            print("Rectangle detection error: \(error)")
            return []
        }
        
        guard let observations = request.results as? [VNRectangleObservation] else {
            print("No rectangle observations found")
            return []
        }
        
        return processRectangleObservations(observations, imageSize: imageSize)
    }
    
    private func mergeDetections(_ allBooths: [DetectedBooth], imageSize: CGSize) -> [DetectedBooth] {
        // Sort by confidence and area
        let sortedBooths = allBooths.sorted { booth1, booth2 in
            // Prioritize smaller booths with decent confidence
            let score1 = booth1.confidence * 0.7 + (1.0 - Float(booth1.area / (imageSize.width * imageSize.height))) * 0.3
            let score2 = booth2.confidence * 0.7 + (1.0 - Float(booth2.area / (imageSize.width * imageSize.height))) * 0.3
            return score1 > score2
        }
        
        // Apply intelligent filtering
        let filteredBooths = intelligentFilter(sortedBooths, imageSize: imageSize)
        
        // Remove composite boxes
        return removeCompositeBoxes(filteredBooths)
    }
    
    private func intelligentFilter(_ booths: [DetectedBooth], imageSize: CGSize) -> [DetectedBooth] {
        return booths.filter { booth in
            // More flexible filtering for edge cases
            let imageArea = imageSize.width * imageSize.height
            let relativeArea = booth.area / imageArea
            
            // Allow very small booths (for edge cases) but filter out huge ones
            let areaOK = relativeArea >= 0.0003 && relativeArea <= 0.15
            
            // More flexible aspect ratio
            let aspectRatio = booth.boundingBox.width / booth.boundingBox.height
            let aspectOK = aspectRatio >= 0.1 && aspectRatio <= 10.0
            
            // Lower confidence threshold for small booths
            let minConfidence: Float = relativeArea < 0.001 ? 0.1 : 0.2
            let confidenceOK = booth.confidence >= minConfidence
            
            // Don't filter out edge positions - allow booths at image boundaries
            let edgeMargin: CGFloat = 2.0 // Very small margin
            let positionOK = booth.boundingBox.origin.x >= -edgeMargin &&
                           booth.boundingBox.origin.y >= -edgeMargin &&
                           booth.boundingBox.maxX <= imageSize.width + edgeMargin &&
                           booth.boundingBox.maxY <= imageSize.height + edgeMargin
            
            return areaOK && aspectOK && confidenceOK && positionOK
        }
    }
    
    // MARK: - Text Detection
    private func detectTextInBooths(_ booths: [DetectedBooth], image: UIImage, cgImage: CGImage) {
        let textRequest = VNRecognizeTextRequest { [weak self] (request, error) in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                
                if let error = error {
                    print("Text detection error: \(error)")
                    self?.finishProcessing(booths: booths, image: image)
                    return
                }
                
                guard let textObservations = request.results as? [VNRecognizedTextObservation] else {
                    print("No text observations found")
                    self?.finishProcessing(booths: booths, image: image)
                    return
                }
                
                let boothsWithText = self?.matchTextToBooths(booths: booths, textObservations: textObservations, imageSize: image.size) ?? booths
                self?.finishProcessing(booths: boothsWithText, image: image)
            }
        }
        
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([textRequest])
            } catch {
                print("Failed to perform text detection: \(error)")
                DispatchQueue.main.async {
                    self.finishProcessing(booths: booths, image: image)
                }
            }
        }
    }
    
    // MARK: - Processing Helpers
    private func processRectangleObservations(_ observations: [VNRectangleObservation], imageSize: CGSize) -> [DetectedBooth] {
        let booths = observations.compactMap { observation in
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
            let boundingBox = CGRect(
                x: observation.boundingBox.origin.x * imageSize.width,
                y: (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * imageSize.height,
                width: observation.boundingBox.width * imageSize.width,
                height: observation.boundingBox.height * imageSize.height
            )
            let area = boundingBox.width * boundingBox.height
            
            return DetectedBooth(
                corners: corners,
                boundingBox: boundingBox,
                confidence: observation.confidence,
                area: area
            )
        }
        .sorted { $0.area > $1.area }
        
        return filterRelevantBooths(booths, imageSize: imageSize)
    }
    
    private func matchTextToBooths(booths: [DetectedBooth], textObservations: [VNRecognizedTextObservation], imageSize: CGSize) -> [DetectedBooth] {
        return booths.map { booth in
            var updatedBooth = booth
            var boothTexts: [String] = []
            
            for textObservation in textObservations {
                let textBoundingBox = CGRect(
                    x: textObservation.boundingBox.origin.x * imageSize.width,
                    y: (1 - textObservation.boundingBox.origin.y - textObservation.boundingBox.height) * imageSize.height,
                    width: textObservation.boundingBox.width * imageSize.width,
                    height: textObservation.boundingBox.height * imageSize.height
                )
                
                if booth.boundingBox.intersects(textBoundingBox) {
                    if let recognizedText = textObservation.topCandidates(1).first {
                        boothTexts.append(recognizedText.string)
                    }
                }
            }
            
            updatedBooth.detectedText = boothTexts.joined(separator: " ")
            updatedBooth.boothName = extractBoothName(from: updatedBooth.detectedText)
            return updatedBooth
        }
    }
    
    private func extractBoothName(from text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filteredWords = words.filter { word in
            let commonWords = ["booth", "hall", "floor", "level", "room", "area", "zone"]
            return !commonWords.contains(word.lowercased()) && word.count > 1
        }
        return filteredWords.prefix(3).joined(separator: " ")
    }
    
    private func filterRelevantBooths(_ booths: [DetectedBooth], imageSize: CGSize) -> [DetectedBooth] {
        // First apply basic filtering
        let basicFiltered = booths.filter { booth in
            let minArea: CGFloat = (imageSize.width * imageSize.height) * 0.001
            let maxArea: CGFloat = (imageSize.width * imageSize.height) * 0.1
            let areaOK = booth.area >= minArea && booth.area <= maxArea
            
            let aspectRatio = booth.boundingBox.width / booth.boundingBox.height
            let aspectRatioOK = aspectRatio >= 0.3 && aspectRatio <= 3.0
            
            let confidenceOK = booth.confidence >= 0.4 // Lowered to catch more small booths
            
            return areaOK && aspectRatioOK && confidenceOK
        }
        
        // Remove composite boxes that contain other boxes
        return removeCompositeBoxes(basicFiltered)
    }
    
    private func removeCompositeBoxes(_ booths: [DetectedBooth]) -> [DetectedBooth] {
        var validBooths: [DetectedBooth] = []
        
        // Sort by area (smallest first) to prioritize smaller boxes
        let sortedBooths = booths.sorted { $0.area < $1.area }
        
        for currentBooth in sortedBooths {
            var isComposite = false
            
            // Check if this booth contains any smaller booths that are already validated
            for existingBooth in validBooths {
                if boothContains(currentBooth, existingBooth) {
                    // Current booth contains a smaller booth, so it's composite
                    isComposite = true
                    break
                }
            }
            
            // If it's not composite, check if it's contained by any existing booth
            var isContained = false
            for existingBooth in validBooths {
                if boothContains(existingBooth, currentBooth) {
                    // Current booth is contained by existing booth, skip it
                    isContained = true
                    break
                }
            }
            
            // Only add if it's not composite and not contained
            if !isComposite && !isContained {
                validBooths.append(currentBooth)
            }
        }
        
        // Final pass: remove any booths that are too close to each other (potential duplicates)
        return removeDuplicateBooths(validBooths)
    }
    
    private func boothContains(_ outerBooth: DetectedBooth, _ innerBooth: DetectedBooth) -> Bool {
        let outer = outerBooth.boundingBox
        let inner = innerBooth.boundingBox
        
        // Add small tolerance for floating point precision
        let tolerance: CGFloat = 5.0
        
        // Check if inner box is completely contained within outer box
        let containsLeft = outer.minX <= inner.minX + tolerance
        let containsRight = outer.maxX >= inner.maxX - tolerance
        let containsTop = outer.minY <= inner.minY + tolerance
        let containsBottom = outer.maxY >= inner.maxY - tolerance
        
        let fullyContained = containsLeft && containsRight && containsTop && containsBottom
        
        // Also check if the inner box takes up a significant portion of outer box
        // If inner is > 80% of outer area, they might be duplicates rather than composite
        let areaRatio = inner.width * inner.height / (outer.width * outer.height)
        let isDuplicate = areaRatio > 0.8
        
        return fullyContained && !isDuplicate
    }
    
    private func removeDuplicateBooths(_ booths: [DetectedBooth]) -> [DetectedBooth] {
        var uniqueBooths: [DetectedBooth] = []
        
        for booth in booths {
            var isDuplicate = false
            
            for existingBooth in uniqueBooths {
                // Check if booths are very similar (potential duplicates)
                if areBoothsSimilar(booth, existingBooth) {
                    isDuplicate = true
                    break
                }
            }
            
            if !isDuplicate {
                uniqueBooths.append(booth)
            }
        }
        
        return uniqueBooths
    }
    
    private func areBoothsSimilar(_ booth1: DetectedBooth, _ booth2: DetectedBooth) -> Bool {
        let box1 = booth1.boundingBox
        let box2 = booth2.boundingBox
        
        // Calculate overlap percentage
        let intersection = box1.intersection(box2)
        if intersection.isNull { return false }
        
        let intersectionArea = intersection.width * intersection.height
        let box1Area = box1.width * box1.height
        let box2Area = box2.width * box2.height
        
        // If overlap is more than 70% of either box, consider them similar
        let overlapRatio1 = intersectionArea / box1Area
        let overlapRatio2 = intersectionArea / box2Area
        
        return overlapRatio1 > 0.7 || overlapRatio2 > 0.7
    }
    
    private func finishProcessing(booths: [DetectedBooth], image: UIImage) {
        self.detectedBooths = booths
        self.createProcessedImage(from: image, booths: booths)
    }
    
    // MARK: - Search Functionality
    func searchBooth(query: String) {
        searchText = query
        highlightedBoothId = nil
        
        guard !query.isEmpty else {
            updateBoothHighlights(highlightedId: nil)
            return
        }
        
        if let matchingBooth = detectedBooths.first(where: { booth in
            booth.boothName.localizedCaseInsensitiveContains(query) ||
            booth.detectedText.localizedCaseInsensitiveContains(query)
        }) {
            highlightedBoothId = matchingBooth.id
            updateBoothHighlights(highlightedId: matchingBooth.id)
        } else {
            updateBoothHighlights(highlightedId: nil)
        }
    }
    
    private func updateBoothHighlights(highlightedId: UUID?) {
        detectedBooths = detectedBooths.map { booth in
            var updatedBooth = booth
            updatedBooth.isHighlighted = (booth.id == highlightedId)
            return updatedBooth
        }
        
        if let originalImage = originalImage {
            createProcessedImage(from: originalImage, booths: detectedBooths)
        }
    }
    
    // MARK: - Image Processing
    private func createProcessedImage(from image: UIImage, booths: [DetectedBooth]) {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let imageWithBooths = renderer.image { context in
            image.draw(at: .zero)
            let cgContext = context.cgContext
            
            for booth in booths {
                if booth.isHighlighted {
                    // Highlighted booth
                    cgContext.setStrokeColor(UIColor.systemYellow.cgColor)
                    cgContext.setFillColor(UIColor.systemYellow.withAlphaComponent(0.3).cgColor)
                    cgContext.setLineWidth(6.0)
                    
                    cgContext.addRect(booth.boundingBox)
                    cgContext.fillPath()
                    cgContext.addRect(booth.boundingBox)
                    cgContext.strokePath()
                    
                    let foundText = "FOUND"
                    let foundAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: UIColor.systemYellow,
                        .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                        .backgroundColor: UIColor.black.withAlphaComponent(0.7)
                    ]
                    let foundLabelOrigin = CGPoint(x: booth.boundingBox.origin.x, y: booth.boundingBox.origin.y - 25)
                    foundText.draw(at: foundLabelOrigin, withAttributes: foundAttributes)
                } else {
                    // Regular booth
                    cgContext.setStrokeColor(UIColor.red.cgColor)
                    cgContext.setLineWidth(3.0)
                    cgContext.addRect(booth.boundingBox)
                    cgContext.strokePath()
                }
                
                // Draw confidence and booth name
                let confidenceText = String(format: "%.1f", booth.confidence)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: booth.isHighlighted ? UIColor.systemYellow : UIColor.red,
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .backgroundColor: UIColor.black.withAlphaComponent(0.5)
                ]
                confidenceText.draw(at: booth.boundingBox.origin, withAttributes: textAttributes)
                
                if !booth.boothName.isEmpty {
                    let boothNameOrigin = CGPoint(x: booth.boundingBox.origin.x, y: booth.boundingBox.origin.y + 20)
                    let nameAttributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: booth.isHighlighted ? UIColor.systemYellow : UIColor.blue,
                        .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                        .backgroundColor: UIColor.white.withAlphaComponent(0.8)
                    ]
                    booth.boothName.draw(at: boothNameOrigin, withAttributes: nameAttributes)
                }
            }
        }
        
        self.processedImage = imageWithBooths
    }
}
