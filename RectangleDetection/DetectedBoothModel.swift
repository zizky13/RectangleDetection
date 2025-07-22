//
//  DetectedBoothModel.swift
//  RectangleDetection
//
//  Created by Zikar Nurizky on 22/07/25.
//

import Foundation

// MARK: - Data Models
struct DetectedBooth: Identifiable {
    let id = UUID()
    let corners: [CGPoint]
    let boundingBox: CGRect
    let confidence: Float
    let area: CGFloat
}
