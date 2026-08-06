import Foundation

actor ForgeEngine {
    func forge(
        job: ForgeJob,
        outputDirectory: URL,
        cookies: BrowserCookies.Status,
        onUpdate: @escaping @Sendable (ForgeJob.Patch) -> Void
    ) async throws {
        let cookieArgs = BrowserCookies.arguments(for: cookies)

        onUpdate(.init(
            phase: .prospecting,
            progress: 0.08,
            status: cookies.ok
                ? "Reading ore with \(cookies.browserLabel) cookies…"
                : "Prospecting without a strong cookie jar…"
        ))

        let meta = try await probe(url: job.url, cookieArgs: cookieArgs)
        onUpdate(.init(
            phase: .smelting,
            progress: 0.22,
            status: "Smelting best streams…",
            title: meta.title
        ))

        let downloaded = try await download(
            url: job.url,
            alloy: job.alloy,
            title: meta.title,
            outputDirectory: outputDirectory,
            cookieArgs: cookieArgs,
            onLine: { line in
                if let p = Self.parseProgress(line) {
                    onUpdate(.init(progress: 0.22 + p * 0.55, status: line))
                } else {
                    onUpdate(.init(status: line))
                }
            }
        )

        onUpdate(.init(phase: .quenching, progress: 0.82, status: "Quenching on the anvil…"))
        let forged = try await quench(
            input: downloaded,
            alloy: job.alloy,
            outputDirectory: outputDirectory,
            onLine: { line in onUpdate(.init(status: line)) }
        )

        onUpdate(.init(
            phase: .finished,
            progress: 1,
            status: "Ready",
            title: meta.title,
            outputPath: forged.path
        ))
    }

    private struct Meta {
        var title: String
    }

    private func probe(url: String, cookieArgs: [String]) async throws -> Meta {
        var args = [
            "--no-update",
            "--ffmpeg-location", ToolPaths.home.path,
            "--dump-single-json",
            "--no-playlist",
            "--no-warnings",
            "--skip-download"
        ]
        args += cookieArgs
        args.append(url)

        let text: String
        do {
            text = try await run(executable: ToolPaths.ytDlp, arguments: args)
        } catch let ForgeError.processFailed(message) {
            throw ForgeError.processFailed(BrowserCookies.friendlyError(message))
        }

        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ForgeError.badMetadata
        }
        return Meta(title: (json["title"] as? String) ?? "Untitled")
    }

    private func download(
        url: String,
        alloy: Alloy,
        title: String,
        outputDirectory: URL,
        cookieArgs: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        let safe = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: " -")
        let template = outputDirectory.appendingPathComponent("\(safe).%(ext)s").path

        var args = [
            "--no-update",
            "--ffmpeg-location", ToolPaths.home.path,
            "--no-playlist",
            "--newline",
            "--progress",
            "-f", alloy.formatSelector,
            "-o", template,
            "--print", "after_move:filepath",
            "--no-mtime",
            "--no-part"
        ]
        args += cookieArgs

        switch alloy {
        case .archivePure:
            args += ["--merge-output-format", "mkv", "--remux-video", "mkv"]
        case .crystal, .tempered:
            args += ["--merge-output-format", "mkv"]
        case .audioIngot:
            args += ["-x", "--audio-format", "flac", "--audio-quality", "0"]
        }
        args.append(url)

        let before = Set(contents(of: outputDirectory))
        let stdout: String
        do {
            stdout = try await run(executable: ToolPaths.ytDlp, arguments: args, onLine: onLine)
        } catch let ForgeError.processFailed(message) {
            throw ForgeError.processFailed(BrowserCookies.friendlyError(message))
        }

        if let printed = stdout
            .split(separator: "\n")
            .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty && !$0.hasPrefix("[") })
            .last,
           FileManager.default.fileExists(atPath: printed) {
            return URL(fileURLWithPath: printed)
        }

        let newcomers = contents(of: outputDirectory).filter { !before.contains($0) }
        if let newest = newcomers.max(by: { modDate($0) < modDate($1) }) {
            return newest
        }
        throw ForgeError.missingOutput
    }

    private func quench(
        input: URL,
        alloy: Alloy,
        outputDirectory: URL,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        let stem = input.deletingPathExtension().lastPathComponent

        switch alloy {
        case .archivePure:
            let output = outputDirectory.appendingPathComponent("\(stem) — Archive Pure.mkv")
            if input.pathExtension.lowercased() == "mkv" {
                try replaceCopy(from: input, to: output)
                return output
            }
            try await run(
                executable: ToolPaths.ffmpeg,
                arguments: ["-y", "-hide_banner", "-i", input.path, "-map", "0", "-c", "copy", output.path],
                onLine: onLine
            )
            return output

        case .crystal:
            let output = outputDirectory.appendingPathComponent("\(stem) — Crystal.mp4")
            try await run(
                executable: ToolPaths.ffmpeg,
                arguments: [
                    "-y", "-hide_banner", "-i", input.path,
                    "-map", "0:v:0", "-map", "0:a?",
                    "-c:v", "libx265", "-crf", "16", "-preset", "slow", "-tag:v", "hvc1",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "320k",
                    "-movflags", "+faststart",
                    output.path
                ],
                onLine: onLine
            )
            try? FileManager.default.removeItem(at: input)
            return output

        case .tempered:
            let output = outputDirectory.appendingPathComponent("\(stem) — Tempered.mp4")
            try await run(
                executable: ToolPaths.ffmpeg,
                arguments: [
                    "-y", "-hide_banner", "-i", input.path,
                    "-map", "0:v:0", "-map", "0:a?",
                    "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-profile:v", "high",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "320k",
                    "-movflags", "+faststart",
                    output.path
                ],
                onLine: onLine
            )
            try? FileManager.default.removeItem(at: input)
            return output

        case .audioIngot:
            if ["flac", "wav", "m4a", "opus", "mp3"].contains(input.pathExtension.lowercased()) {
                let output = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.\(input.pathExtension)")
                try replaceCopy(from: input, to: output)
                return output
            }
            let output = outputDirectory.appendingPathComponent("\(stem) — Audio Ingot.flac")
            try await run(
                executable: ToolPaths.ffmpeg,
                arguments: ["-y", "-hide_banner", "-i", input.path, "-vn", "-c:a", "flac", output.path],
                onLine: onLine
            )
            return output
        }
    }

    @discardableResult
    private func run(
        executable: URL,
        arguments: [String],
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = executable
                    process.arguments = arguments
                    process.environment = [
                        "PATH": ToolPaths.home.path,
                        "YTDLP_NO_UPDATE": "1"
                    ]

                    let out = Pipe()
                    let err = Pipe()
                    process.standardOutput = out
                    process.standardError = err

                    let lock = NSLock()
                    var collected = Data()

                    let handle: (FileHandle) -> Void = { handle in
                        let chunk = handle.availableData
                        guard !chunk.isEmpty else { return }
                        lock.lock(); collected.append(chunk); lock.unlock()
                        if let text = String(data: chunk, encoding: .utf8) {
                            text.split(whereSeparator: \.isNewline).forEach { onLine?(String($0)) }
                        }
                    }

                    out.fileHandleForReading.readabilityHandler = handle
                    err.fileHandleForReading.readabilityHandler = handle

                    try process.run()
                    process.waitUntilExit()
                    out.fileHandleForReading.readabilityHandler = nil
                    err.fileHandleForReading.readabilityHandler = nil

                    lock.lock()
                    let text = String(data: collected, encoding: .utf8) ?? ""
                    lock.unlock()

                    if process.terminationStatus != 0 {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(throwing: ForgeError.processFailed(
                            trimmed.isEmpty ? "Process failed (\(process.terminationStatus))" : trimmed
                        ))
                        return
                    }
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func replaceCopy(from: URL, to: URL) throws {
        if from.standardizedFileURL == to.standardizedFileURL { return }
        if FileManager.default.fileExists(atPath: to.path) {
            try FileManager.default.removeItem(at: to)
        }
        try FileManager.default.copyItem(at: from, to: to)
    }

    private func contents(of directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
    }

    private func modDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private nonisolated static func parseProgress(_ line: String) -> Double? {
        guard let r = line.range(of: #"(\d{1,3}(?:\.\d+)?)%"#, options: .regularExpression) else { return nil }
        return Double(line[r].dropLast()).map { min(max($0 / 100, 0), 1) }
    }
}
