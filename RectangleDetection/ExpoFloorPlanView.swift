//
//  ExpoFloorPlanView.swift
//  RectangleDetection
//
//  Created by Zikar Nurizky on 22/07/25.
//

import Foundation
import SwiftUI

struct ExpoFloorPlanView: View {
    @StateObject private var analyzer = ExpoFloorPlanAnalyzer()
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingBooths = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text("Expo Floor Plan Analyzer")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Detect booth rectangles in floor plans")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Image Display
                if let processedImage = analyzer.processedImage {
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        Image(uiImage: processedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 400)
                    }
                    .border(Color.gray, width: 1)
                } else if let selectedImage = selectedImage {
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 400)
                    }
                    .border(Color.gray, width: 1)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("Select a floor plan image")
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                // Controls
                HStack(spacing: 15) {
                    Button("Select Image") {
                        showingImagePicker = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Analyze Floor Plan") {
                        if let image = selectedImage {
                            analyzer.detectBoothsInFloorPlan(image: image)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedImage == nil || analyzer.isAnalyzing)
                    
                    if analyzer.detectedBooths.count > 0 {
                        Button("Show Details") {
                            showingBooths = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Loading indicator
                if analyzer.isAnalyzing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyzing floor plan...")
                            .font(.caption)
                    }
                }
                
                // Results summary
                if analyzer.detectedBooths.count > 0 && !analyzer.isAnalyzing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection Results")
                            .font(.headline)
                        
                        Text("Found \(analyzer.detectedBooths.count) potential booths")
                            .font(.subheadline)
                        
                        let avgConfidence = analyzer.detectedBooths.reduce(0) { $0 + $1.confidence } / Float(analyzer.detectedBooths.count)
                        Text("Average confidence: \(String(format: "%.1f%%", avgConfidence * 100))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingBooths) {
            BoothDetailsView(booths: analyzer.detectedBooths)
        }
    }
}
