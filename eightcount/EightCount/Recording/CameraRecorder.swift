@preconcurrency import AVFoundation
import CoreMedia
import Observation
import UIKit

/// Controls the front or back camera: shows a live preview and records
/// video-only movie files (no microphone at all, so no microphone permission
/// needed; the music comes from the tutorial video).
///
/// How AVFoundation camera recording works, in short:
///  - `AVCaptureSession` is the "pipeline". Inputs (the camera) go in,
///    outputs (a movie file writer) come out.
///  - Starting/stopping the session and changing its setup can take a while,
///    so Apple wants it done on a background queue, never on the main thread.
///    That is what `sessionQueue` is for.
@MainActor
@Observable
final class CameraRecorder {
    // MARK: - State the UI reads

    /// The capture pipeline. The preview view displays it.
    let session = AVCaptureSession()

    /// Camera permission (`.notDetermined` until the user answered).
    private(set) var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    /// True once the camera is delivering pictures.
    private(set) var isRunning = false
    /// True from the moment recording is requested until the file is finished.
    private(set) var isRecording = false
    /// Front or back. Remembered for the next recording (`cameraPosition` in
    /// UserDefaults). Anything other than the back camera counts as front.
    private(set) var position: AVCaptureDevice.Position = .front
    /// True after setup when this device has both a front and a back camera.
    private(set) var canSwitchCamera = false
    /// A readable problem, if the camera could not be set up.
    private(set) var errorMessage: String? = nil

    // MARK: - Private bookkeeping (not observed by SwiftUI)

    /// All slow session work happens on this serial queue.
    private let sessionQueue = DispatchQueue(label: "EightCount.CameraRecorder.session")
    private let movieOutput = AVCaptureMovieFileOutput()

    @ObservationIgnored private var isConfigured = false
    /// Set by `start()`, cleared by `stop()`. Lets a slow `start()` notice
    /// that the screen was closed meanwhile.
    @ObservationIgnored private var wantsRunning = false
    @ObservationIgnored private var device: AVCaptureDevice? = nil
    @ObservationIgnored private weak var previewLayer: AVCaptureVideoPreviewLayer? = nil
    /// Tells us how to rotate preview and file so you are always upright.
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator? = nil
    /// Must be kept alive, otherwise the observation stops immediately.
    @ObservationIgnored private var rotationObservation: NSKeyValueObservation? = nil
    @ObservationIgnored private var runtimeErrorObserver: NSObjectProtocol? = nil
    /// The recording delegate must be kept alive until the file is finished.
    @ObservationIgnored private var recordingDelegate: MovieRecordingDelegate? = nil
    @ObservationIgnored private var stopRequested = false
    /// A second tap must wait until the swap on `sessionQueue` has finished.
    /// A recording must not start during that wait either: the file would use
    /// the new camera while the take still remembered the old one.
    private(set) var isSwitching = false

    init() {
        let raw = UserDefaults.standard.integer(forKey: "cameraPosition")
        if AVCaptureDevice.Position(rawValue: raw) == .back {
            position = .back
        }
    }

    // MARK: - Camera on / off

    /// Asks for permission (first time only), sets the camera up (once) and
    /// starts the live picture.
    func start() async {
        wantsRunning = true
        errorMessage = nil

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            // Shows the system "Allow camera?" question.
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        authorization = AVCaptureDevice.authorizationStatus(for: .video)
        guard authorization == .authorized else { return }
        guard wantsRunning else { return }

        if !isConfigured {
            let session = self.session
            let output = self.movieOutput
            let preferredPosition = position
            let result: ConfigurationResult = await withCheckedContinuation { continuation in
                sessionQueue.async {
                    continuation.resume(returning: CameraRecorder.configure(
                        session: session, output: output, position: preferredPosition))
                }
            }
            if let message = result.errorMessage {
                errorMessage = message
                return
            }
            device = result.device
            position = result.device?.position == .back ? .back : .front
            canSwitchCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
                && AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            isConfigured = true
            rebuildRotationCoordinator()
        }
        guard wantsRunning else { return }

        registerRuntimeErrorObserver()

        let session = self.session
        let running: Bool = await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume(returning: session.isRunning)
            }
        }

        if wantsRunning {
            isRunning = running
            applyPreviewRotation()
        } else {
            // The screen was closed while the camera was starting up.
            sessionQueue.async {
                if session.isRunning { session.stopRunning() }
            }
            isRunning = false
        }
    }

    /// Stops the camera (and a running recording). Safe to call repeatedly.
    func stop() {
        wantsRunning = false
        stopRecording()
        if let token = runtimeErrorObserver {
            NotificationCenter.default.removeObserver(token)
            runtimeErrorObserver = nil
        }
        let session = self.session
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
        isRunning = false
    }

    /// Swaps between the front and the back camera. Does nothing while a
    /// recording is running, or when the device has only one camera.
    func switchCamera() async {
        guard isConfigured, !isRecording, canSwitchCamera, !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }

        let target: AVCaptureDevice.Position = position == .back ? .front : .back
        let session = self.session
        let output = self.movieOutput
        let result: ConfigurationResult = await withCheckedContinuation { continuation in
            sessionQueue.async {
                continuation.resume(returning: CameraRecorder.replaceCamera(
                    session: session, output: output, with: target))
            }
        }

        if let newDevice = result.device {
            device = newDevice
            position = newDevice.position == .back ? .back : .front
            UserDefaults.standard.set(position.rawValue, forKey: "cameraPosition")
            errorMessage = nil
            rebuildRotationCoordinator()
            applyPreviewRotation()
        } else {
            errorMessage = "The camera could not be switched."
        }
    }

    // MARK: - Recording

    /// Starts writing a movie file to `url`.
    /// - `onStarted`: called when the first frame is really being written.
    ///   It receives the iPhone's "host clock" time of that moment, which
    ///   can be used to start the tutorial at an exact time.
    /// - `onFinished`: called once with the finished file (or an error).
    /// Both callbacks run on the main actor.
    func startRecording(to url: URL,
                        onStarted: @escaping @MainActor (CMTime) -> Void,
                        onFinished: @escaping @MainActor (Result<URL, Error>) -> Void) {
        guard isConfigured, isRunning, !isRecording else {
            onFinished(.failure(CameraRecorderError.notReady))
            return
        }

        // The Videos folder might not exist yet (e.g. first launch).
        do {
            try FileManager.default.createDirectory(at: VideoStorage.directory,
                                                    withIntermediateDirectories: true)
        } catch {
            onFinished(.failure(error))
            return
        }
        try? FileManager.default.removeItem(at: url)   // never overwrite by accident

        // How much to rotate the file so it is upright (portrait or landscape).
        let captureAngle: CGFloat? = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture

        let delegate = MovieRecordingDelegate(
            started: onStarted,
            finished: { [weak self] result in
                self?.isRecording = false
                self?.stopRequested = false
                self?.recordingDelegate = nil
                onFinished(result)
            }
        )
        recordingDelegate = delegate
        isRecording = true
        stopRequested = false

        let output = movieOutput
        sessionQueue.async {
            if let connection = output.connection(with: .video),
               let angle = captureAngle,
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            output.startRecording(to: url, recordingDelegate: delegate)
        }
    }

    /// Asks the movie file to finish. `onFinished` of `startRecording`
    /// is called when the file is complete.
    func stopRecording() {
        guard isRecording, !stopRequested else { return }
        stopRequested = true
        let output = movieOutput
        sessionQueue.async {
            output.stopRecording()
        }
    }

    // MARK: - Rotation (portrait / landscape)

    /// Called by the preview view. Keeps preview and recording upright when
    /// the phone is turned.
    func attach(previewLayer layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        rebuildRotationCoordinator()
    }

    /// (Re)creates the `RotationCoordinator`. It needs BOTH the camera and
    /// the preview layer, which become available at different moments, so
    /// this is called from both places.
    private func rebuildRotationCoordinator() {
        rotationObservation?.invalidate()
        rotationObservation = nil
        rotationCoordinator = nil

        guard let device, let layer = previewLayer else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        rotationCoordinator = coordinator

        // Whenever the phone is turned, the coordinator's suggested preview
        // angle changes; apply it to the preview layer.
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            guard let self else { return }
            Task { @MainActor in
                self.applyPreviewRotation()
            }
        }
    }

    private func applyPreviewRotation() {
        guard let coordinator = rotationCoordinator,
              let connection = previewLayer?.connection else { return }
        let angle = coordinator.videoRotationAngleForHorizonLevelPreview
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    // MARK: - Errors while running

    private func registerRuntimeErrorObserver() {
        guard runtimeErrorObserver == nil else { return }
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let message = (notification.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription
            guard let self else { return }
            MainActor.assumeIsolated {
                self.errorMessage = message ?? "The camera stopped unexpectedly."
            }
        }
    }

    // MARK: - One-time setup (runs on the session queue)

    /// Builds the pipeline: the chosen camera in, movie file out. No audio input.
    /// If that camera is missing, the other one is used (an iPad or a Mac
    /// may have only one).
    nonisolated private static func configure(session: AVCaptureSession,
                                              output: AVCaptureMovieFileOutput,
                                              position: AVCaptureDevice.Position) -> ConfigurationResult {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Full HD (1920×1080) — the most TikTok/Instagram keep — falling back
        // to the camera's "high" setting if a phone can't do it.
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        // We never record sound, so the capture session must not touch the
        // app's audio setup (the tutorial's music plays through it).
        session.automaticallyConfiguresApplicationAudioSession = false
        // iPad: keep the camera running when the app shares the screen with
        // another app (Split View / Stage Manager).
        if session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }

        let other: AVCaptureDevice.Position = position == .back ? .front : .back
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: other) else {
            return ConfigurationResult(device: nil, errorMessage: "No camera was found on this device.")
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                return ConfigurationResult(device: nil, errorMessage: "The camera could not be added to the recording.")
            }
            session.addInput(input)
        } catch {
            return ConfigurationResult(device: nil, errorMessage: error.localizedDescription)
        }

        guard session.canAddOutput(output) else {
            return ConfigurationResult(device: nil, errorMessage: "The video file output could not be added.")
        }
        session.addOutput(output)
        setUpFileConnection(output)

        return ConfigurationResult(device: camera, errorMessage: nil)
    }

    /// The saved file is never mirrored (the compare screen flips it on
    /// screen). Changing the camera input builds a new connection, so this
    /// has to run again after a switch.
    nonisolated private static func setUpFileConnection(_ output: AVCaptureMovieFileOutput) {
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    /// Replaces the session's camera input. Runs on the session queue.
    /// If the new camera cannot be added, the previous one is put back and
    /// the result's device is nil.
    nonisolated private static func replaceCamera(session: AVCaptureSession,
                                                  output: AVCaptureMovieFileOutput,
                                                  with position: AVCaptureDevice.Position) -> ConfigurationResult {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            return ConfigurationResult(device: nil, errorMessage: nil)
        }

        session.beginConfiguration()
        defer {
            setUpFileConnection(output)
            session.commitConfiguration()
        }

        let oldInputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
        for input in oldInputs {
            session.removeInput(input)
        }

        let newInput = try? AVCaptureDeviceInput(device: camera)
        if let newInput, session.canAddInput(newInput) {
            session.addInput(newInput)
            return ConfigurationResult(device: camera, errorMessage: nil)
        }

        for input in oldInputs where session.canAddInput(input) {
            session.addInput(input)
        }
        return ConfigurationResult(device: nil, errorMessage: nil)
    }
}

/// What `CameraRecorder.configure` reports back to the main actor.
private struct ConfigurationResult: @unchecked Sendable {
    var device: AVCaptureDevice?
    var errorMessage: String?
}

enum CameraRecorderError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady: "The camera is not ready yet."
        }
    }
}

/// Receives "recording started / finished" from AVFoundation. Those calls
/// arrive on arbitrary background queues, so we hop to the main queue
/// before calling the closures.
private final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let started: @MainActor (CMTime) -> Void
    private let finished: @MainActor (Result<URL, Error>) -> Void

    init(started: @escaping @MainActor (CMTime) -> Void,
         finished: @escaping @MainActor (Result<URL, Error>) -> Void) {
        self.started = started
        self.finished = finished
        super.init()
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        // Take the time right here, as close to the real start as possible.
        let hostTime = CMClockGetTime(CMClockGetHostTimeClock())
        let handler = started
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(hostTime)
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // AVFoundation sometimes reports an "error" although the file is
        // fine (e.g. disk almost full, but everything was written). It says
        // so in the error's userInfo.
        var realError = error
        if let nsError = error as NSError?,
           let savedOK = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool,
           savedOK {
            realError = nil
        }

        let result: Result<URL, Error>
        if let realError {
            result = .failure(realError)
        } else {
            result = .success(outputFileURL)
        }
        let handler = finished
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(result)
            }
        }
    }
}
