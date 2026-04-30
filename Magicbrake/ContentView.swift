//
//  ContentView.swift
//  Magicbrake
//
//  Created by Dd on 10/28/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct CompletionView: View {
    let outputFolder: URL?
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Complete")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Button("View files") {
                    if let folder = outputFolder {
                        NSWorkspace.shared.open(folder)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Convert more files") {
                    onBack()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView: View {
    @State private var droppedFiles: [URL] = []
    @State private var isConverting = false
    @State private var showCompletionView = false
    @State private var outputFolder: URL?
    @State private var hasPreviousFiles = false

    private let appFolder: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appFolder = documentsPath.appendingPathComponent("Magicbrake")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder
    }()

    var body: some View {
        Group {
            if showCompletionView {
                CompletionView(outputFolder: outputFolder) {
                    showCompletionView = false
                    droppedFiles = []
                    checkForPreviousFiles()
                }
            } else {
                MainConversionView(
                    droppedFiles: $droppedFiles,
                    isConverting: $isConverting,
                    showCompletionView: $showCompletionView,
                    outputFolder: $outputFolder,
                    appFolder: appFolder,
                    hasPreviousFiles: hasPreviousFiles
                )
            }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            checkForPreviousFiles()
        }
    }

    private func checkForPreviousFiles() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: appFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            hasPreviousFiles = false
            return
        }
        hasPreviousFiles = contents.contains { $0.pathExtension.lowercased() == "mp4" }
    }
}

struct MainConversionView: View {
    @Binding var droppedFiles: [URL]
    @Binding var isConverting: Bool
    @Binding var showCompletionView: Bool
    @Binding var outputFolder: URL?
    @State private var currentFileIndex: Int = 0
    @State private var rotationAngle: Double = 0
    @State private var spinTimer: Timer?
    @State private var conversionProgress: Double = 0.0
    let appFolder: URL
    let hasPreviousFiles: Bool

    var body: some View {
        VStack(spacing: 30) {
            if isConverting {
                // Conversion view - show simple message
                VStack(spacing: 40) {
                    Image(systemName: "gear")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            if isConverting {
                                startSpinning()
                            }
                        }
                        .onChange(of: isConverting) { newValue in
                            if newValue {
                                startSpinning()
                            } else {
                                stopSpinning()
                            }
                        }
                    
                    VStack(spacing: 10) {
                        Text("Converting...")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        if droppedFiles.count > 1 {
                            Text("File \(currentFileIndex + 1) of \(droppedFiles.count)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(Int(conversionProgress * 100))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                // Normal view - show drag/drop and button
                // Drag and drop area
                RoundedRectangle(cornerRadius: 20)
                    .stroke(style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .foregroundColor(.blue)
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            if droppedFiles.isEmpty {
                                Text("Drop video files here")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            } else {
                                VStack(spacing: 5) {
                                    Text("\(droppedFiles.count) file\(droppedFiles.count == 1 ? "" : "s") selected")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(droppedFiles.prefix(3), id: \.self) { file in
                                        Text(file.lastPathComponent)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    if droppedFiles.count > 3 {
                                        Text("... and \(droppedFiles.count - 3) more")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    )
                    .onDrop(of: [UTType.movie, UTType.video], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                    }
                
                // Convert button
                Button(action: startConversion) {
                    Text(buttonText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: 300)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(droppedFiles.isEmpty || isConverting)

                if hasPreviousFiles {
                    Button {
                        NSWorkspace.shared.open(appFolder)
                    } label: {
                        Text("View converted files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(40)
    }
    
    private func startSpinning() {
        spinTimer?.invalidate()
        spinTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                rotationAngle += 36 // 36 degrees per 0.1 seconds = 360 degrees per second
            }
        }
    }
    
    private func stopSpinning() {
        spinTimer?.invalidate()
        spinTimer = nil
        rotationAngle = 0
    }
    
    private var buttonText: String {
        if droppedFiles.isEmpty {
            return "Make small, fast, and compatible"
        } else if droppedFiles.count == 1 {
            return "Make small, fast, and compatible"
        } else {
            return "Make \(droppedFiles.count) small, fast, and compatible"
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let _: [URL] = []
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ||
               provider.hasItemConformingToTypeIdentifier(UTType.video.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { item, error in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            if !droppedFiles.contains(url) {
                                droppedFiles.append(url)
                            }
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    private func startConversion() {
        guard !droppedFiles.isEmpty else { return }
        
        isConverting = true
        currentFileIndex = 0
        conversionProgress = 0.0
        
        Task {
            await convertFiles()
        }
    }
    
    private func convertFiles() async {
        for (index, file) in droppedFiles.enumerated() {
            await MainActor.run {
                currentFileIndex = index
            }
            
            let outputURL = appFolder.appendingPathComponent("\(file.deletingPathExtension().lastPathComponent)_converted.mp4")
            await convertSingleFile(input: file, output: outputURL)
        }
        
        await MainActor.run {
            isConverting = false
            outputFolder = appFolder
            showCompletionView = true
        }
    }
    
    private func convertSingleFile(input: URL, output: URL) async {
        let process = Process()
        process.executableURL = Bundle.main.url(forResource: "HandBrakeCLI", withExtension: nil)
        process.arguments = [
            "-i", input.path,
            "-o", output.path,
            "--preset=Very Fast 1080p30"
        ]
        
        // Create pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            
            // Start async output reading
            Task {
                await readHandBrakeOutput(outputPipe: outputPipe, errorPipe: errorPipe)
            }
            
            // Wait for process to complete without blocking the main thread
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .background).async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }
        } catch {
            // Handle error silently
        }
    }
    
    private func readHandBrakeOutput(outputPipe: Pipe, errorPipe: Pipe) async {
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        // Read from both stdout and stderr
        Task {
            await readFromHandle(outputHandle)
        }
        
        Task {
            await readFromHandle(errorHandle)
        }
    }
    
    private func readFromHandle(_ handle: FileHandle) async {
        while true {
            let data = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .background).async {
                    let data = handle.readData(ofLength: 1024)
                    continuation.resume(returning: data)
                }
            }
            
            if data.isEmpty { break }
            
            if let line = String(data: data, encoding: .utf8) {
                await parseHandBrakeJSON(line)
            }
        }
    }
    
    private func parseHandBrakeJSON(_ line: String) async {
        // Try to parse as JSON first
        if let data = line.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let progress = json["Progress"] as? [String: Any],
           let percentComplete = progress["PercentComplete"] as? Double {
            
            await MainActor.run {
                conversionProgress = percentComplete / 100.0
            }
            return
        }
        
        // Fallback: try to parse the regular text output
        // HandBrake outputs: "Encoding: task 1 of 1, 52.91 % (1114.81 fps, avg 1207.25 fps, ETA 00h00m13s)"
        let pattern = #"Encoding: task \d+ of \d+, (\d+\.?\d*)\s*%"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            
            if let percentage = Double(String(line[range])) {
                await MainActor.run {
                    conversionProgress = percentage / 100.0
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
