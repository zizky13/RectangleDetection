//
//  BoothDetailView.swift
//  RectangleDetection
//
//  Created by Zikar Nurizky on 22/07/25.
//

import Foundation
import SwiftUI

struct BoothDetailsView: View {
    let booths: [DetectedBooth]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(booths.enumerated()), id: \.element.id) { index, booth in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Booth \(index + 1)")
                                .font(.headline)
                            Spacer()
                            Text("\(String(format: "%.1f%%", booth.confidence * 100))")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Area: \(String(format: "%.0f", booth.area)) px²")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Size: \(String(format: "%.0f", booth.boundingBox.width)) × \(String(format: "%.0f", booth.boundingBox.height)) px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Position: (\(String(format: "%.0f", booth.boundingBox.origin.x)), \(String(format: "%.0f", booth.boundingBox.origin.y)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Detected Booths")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
