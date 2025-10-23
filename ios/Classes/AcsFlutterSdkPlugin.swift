import AVFoundation
import Flutter
import UIKit
import AzureCommunicationCommon
import AzureCommunicationCalling
import AzureCommunicationChat

public class AcsFlutterSdkPlugin: NSObject, FlutterPlugin, CallDelegate, RemoteParticipantDelegate, CallAgentDelegate {
    private var channel: FlutterMethodChannel?

    private let callClient = CallClient()
    private let viewManager = VideoViewManager()
    private let remoteVideoRegistry = RemoteVideoRegistry()

    private var tokenCredential: CommunicationTokenCredential?
    private var callAgent: CallAgent?
    private var deviceManager: DeviceManager?
    private var call: Call?
    private var localVideoStream: LocalVideoStream?
    private var currentCamera: VideoDeviceInfo?
    private var incomingCall: IncomingCall?

    private var chatClient: ChatClient?
    private var chatThreadClient: ChatThreadClient?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "acs_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = AcsFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(AcsVideoViewFactory(viewManager: instance.viewManager), withId: "acs_video_view")
        instance.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "getPlatformVersion":
            result("iOS \(UIDevice.current.systemVersion)")

        case "initializeIdentity":
            initializeIdentity(args: args, result: result)

        case "initializeCalling":
            initializeCalling(args: args, result: result)
        case "requestPermissions":
            requestPermissions(result: result)
        case "startCall":
            startCall(args: args, result: result)
        case "joinCall":
            joinCall(args: args, result: result)
        case "endCall":
            endCall(result: result)
        case "muteAudio":
            muteAudio(result: result)
        case "unmuteAudio":
            unmuteAudio(result: result)
        case "startVideo":
            startVideo(result: result)
        case "stopVideo":
            stopVideo(result: result)
        case "switchCamera":
            switchCamera(result: result)

        case "createUser", "getToken", "revokeToken":
            result(FlutterError(
                code: "NOT_IMPLEMENTED",
                message: "Identity management should be implemented on your backend.",
                details: nil
            ))

        case "initializeChat":
            initializeChat(args: args, result: result)
        case "createChatThread":
            createChatThread(args: args, result: result)
        case "joinChatThread":
            joinChatThread(args: args, result: result)
        case "sendMessage":
            sendMessage(args: args, result: result)
        case "getMessages":
            getMessages(args: args, result: result)
        case "sendTypingNotification":
            sendTypingNotification(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Identity

    private func initializeIdentity(args: [String: Any], result: FlutterResult) {
        guard let connection = args["connectionString"] as? String, !connection.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Connection string is required", details: nil))
            return
        }
        result(["status": "initialized"])
    }

    // MARK: - Calling

    private func initializeCalling(args: [String: Any], result: @escaping FlutterResult) {
        guard let accessToken = args["accessToken"] as? String, !accessToken.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Access token is required", details: nil))
            return
        }

        do {
            tokenCredential = try CommunicationTokenCredential(token: accessToken)
        } catch {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
            return
        }

        callClient.createCallAgent(userCredential: tokenCredential!) { [weak self] agent, error in
            guard let self = self else { return }
            if let error = error {
                result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            self.callAgent = agent
            self.callAgent?.delegate = self
            do {
                self.deviceManager = try self.callClient.getDeviceManager()
            } catch {
                // Device manager is optional; ignore failures and continue.
            }
            result(["status": "initialized"])
        }
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var cameraGranted = false
        var audioGranted = false

        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            cameraGranted = granted
            group.leave()
        }

        group.enter()
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            audioGranted = granted
            group.leave()
        }

        group.notify(queue: .main) {
            result(cameraGranted && audioGranted)
        }
    }

    private func startCall(args: [String: Any], result: @escaping FlutterResult) {
        guard let participants = args["participants"] as? [String], !participants.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Participants list is required", details: nil))
            return
        }
        guard let agent = callAgent else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call agent not initialized", details: nil))
            return
        }

        let withVideo = args["withVideo"] as? Bool ?? false

        DispatchQueue.main.async {
            do {
                let options = StartCallOptions()
                if withVideo, let stream = try self.ensureLocalVideoStream() {
                    options.videoOptions = VideoOptions(localVideoStreams: [stream])
                    try self.viewManager.showLocalPreview(stream: stream)
                }

                let callees = participants.map { CommunicationUserIdentifier($0) }
                guard let newCall = agent.startCall(participants: callees, options: options) else {
                    result(FlutterError(code: "CALL_START_FAILED", message: "Failed to start call", details: nil))
                    return
                }

                self.attachCall(newCall)
                result(["id": newCall.id, "state": self.callStateToString(newCall.state)])
            } catch {
                result(FlutterError(code: "CALL_START_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func joinCall(args: [String: Any], result: @escaping FlutterResult) {
        guard let groupIdString = args["groupCallId"] as? String,
              let uuid = UUID(uuidString: groupIdString) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Valid group call ID is required", details: nil))
            return
        }
        guard let agent = callAgent else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Call agent not initialized", details: nil))
            return
        }

        let withVideo = args["withVideo"] as? Bool ?? false

        DispatchQueue.main.async {
            do {
                let locator = GroupCallLocator(groupId: uuid)
                let options = JoinCallOptions()
                if withVideo, let stream = try self.ensureLocalVideoStream() {
                    options.videoOptions = VideoOptions(localVideoStreams: [stream])
                    try self.viewManager.showLocalPreview(stream: stream)
                }

                guard let joinedCall = agent.join(with: locator, options: options) else {
                    result(FlutterError(code: "CALL_JOIN_FAILED", message: "Failed to join call", details: nil))
                    return
                }

                self.attachCall(joinedCall)
                result(["id": joinedCall.id, "state": self.callStateToString(joinedCall.state)])
            } catch {
                result(FlutterError(code: "CALL_JOIN_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func endCall(result: @escaping FlutterResult) {
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call to end", details: nil))
            return
        }

        activeCall.hangUp(options: HangUpOptions()) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "HANGUP_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    self?.cleanupCallResources()
                    result(nil)
                }
            }
        }
    }

    private func muteAudio(result: @escaping FlutterResult) {
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call", details: nil))
            return
        }

        activeCall.muteOutgoingAudio { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "MUTE_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        }
    }

    private func unmuteAudio(result: @escaping FlutterResult) {
        guard let activeCall = call else {
            result(FlutterError(code: "NO_ACTIVE_CALL", message: "No active call", details: nil))
            return
        }

        activeCall.unmuteOutgoingAudio { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "UNMUTE_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        }
    }

    private func startVideo(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            do {
                guard let stream = try self.ensureLocalVideoStream() else {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "Camera not available", details: nil))
                    return
                }

                try self.viewManager.showLocalPreview(stream: stream)

                guard let activeCall = self.call else {
                    result(nil)
                    return
                }

                activeCall.startVideo(stream: stream) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
                        } else {
                            result(nil)
                        }
                    }
                }
            } catch {
                result(FlutterError(code: "VIDEO_START_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func stopVideo(result: @escaping FlutterResult) {
        guard let stream = localVideoStream else {
            DispatchQueue.main.async {
                self.viewManager.clearLocalPreview()
                result(nil)
            }
            return
        }

        guard let activeCall = call else {
            DispatchQueue.main.async {
                self.viewManager.clearLocalPreview()
                result(nil)
            }
            return
        }

        activeCall.stopVideo(stream: stream) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "VIDEO_STOP_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    self?.viewManager.clearLocalPreview()
                    result(nil)
                }
            }
        }
    }

    private func switchCamera(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            do {
                guard let manager = try self.ensureDeviceManager(),
                      let stream = self.localVideoStream else {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "No active camera stream", details: nil))
                    return
                }

                let cameras = manager.cameras
                guard !cameras.isEmpty else {
                    result(FlutterError(code: "VIDEO_UNAVAILABLE", message: "No cameras detected", details: nil))
                    return
                }

                let current = self.currentCamera ?? cameras.first!
                let currentIndex = cameras.firstIndex { $0.id == current.id } ?? 0
                let nextCamera = cameras[(currentIndex + 1) % cameras.count]
                try stream.switchSource(with: nextCamera)
                self.currentCamera = nextCamera
                result(nil)
            } catch {
                result(FlutterError(code: "SWITCH_CAMERA_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func attachCall(_ newCall: Call) {
        cleanupCallResources()
        call = newCall
        newCall.delegate = self
        handleAddedParticipants(newCall.remoteParticipants)
    }

    private func cleanupCallResources() {
        call?.delegate = nil
        call = nil
        incomingCall = nil

        DispatchQueue.main.async {
            self.remoteVideoRegistry.clear()
            self.viewManager.clearLocalPreview()
            self.viewManager.removeAllRemote()
        }

        localVideoStream = nil
        currentCamera = nil
    }

    private func handleAddedParticipants(_ participants: [RemoteParticipant]) {
        participants.forEach { participant in
            participant.delegate = self
            participant.videoStreams.forEach { subscribeRemoteStream($0) }
        }
    }

    private func handleRemovedParticipants(_ participants: [RemoteParticipant]) {
        participants.forEach { participant in
            participant.videoStreams.forEach { stream in
                removeRemoteStream(streamId: Int(stream.id))
            }
            participant.delegate = nil
        }
    }

    private func subscribeRemoteStream(_ stream: RemoteVideoStream) {
        DispatchQueue.main.async {
            do {
                let view = try self.remoteVideoRegistry.start(stream: stream)
                self.viewManager.addRemote(view: view, streamId: Int(stream.id))
            } catch {
                // Ignore renderer errors for remote streams.
            }
        }
    }

    private func removeRemoteStream(streamId: Int) {
        DispatchQueue.main.async {
            self.remoteVideoRegistry.stop(streamId: streamId)
            self.viewManager.removeRemote(streamId: streamId)
        }
    }

    private func answerIncomingCall() {
        guard let incoming = incomingCall else { return }

        DispatchQueue.main.async {
            let options = AcceptCallOptions()
            var previewStream: LocalVideoStream?
            if let stream = try? self.ensureLocalVideoStream() {
                previewStream = stream
            }

            if let previewStream = previewStream {
                options.videoOptions = VideoOptions(localVideoStreams: [previewStream])
                try? self.viewManager.showLocalPreview(stream: previewStream)
            }

            incoming.accept(options: options) { [weak self] call, _ in
                guard let self = self else { return }
                if let call = call {
                    self.attachCall(call)
                }
                self.incomingCall = nil
            }
        }
    }

    private func ensureDeviceManager() throws -> DeviceManager? {
        if let manager = deviceManager {
            return manager
        }
        let manager = try callClient.getDeviceManager()
        deviceManager = manager
        return manager
    }

    private func ensureLocalVideoStream() throws -> LocalVideoStream? {
        if let stream = localVideoStream {
            return stream
        }
        guard let manager = try ensureDeviceManager(),
              let camera = manager.cameras.first else {
            return nil
        }
        let stream = try LocalVideoStream(camera: camera)
        localVideoStream = stream
        currentCamera = camera
        return stream
    }

    private func callStateToString(_ state: CallState) -> String {
        switch state {
        case .none: return "none"
        case .connecting: return "connecting"
        case .ringing: return "ringing"
        case .connected: return "connected"
        case .localHold: return "onHold"
        case .disconnecting: return "disconnecting"
        case .disconnected: return "disconnected"
        case .earlyMedia: return "earlyMedia"
        case .remoteHold: return "remoteHold"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Chat

    private func initializeChat(args: [String: Any], result: @escaping FlutterResult) {
        guard let token = args["accessToken"] as? String, !token.isEmpty,
              let endpoint = args["endpoint"] as? String, !endpoint.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Access token and endpoint are required", details: nil))
            return
        }

        do {
            tokenCredential = try CommunicationTokenCredential(token: token)
            let options = AzureCommunicationChatClientOptions()
            chatClient = try ChatClient(endpoint: endpoint, credential: tokenCredential!, withOptions: options)
            result(["status": "initialized"])
        } catch {
            result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func createChatThread(args: [String: Any], result: @escaping FlutterResult) {
        guard let topic = args["topic"] as? String, !topic.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Topic is required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        let participants = (args["participants"] as? [String] ?? []).map { id -> ChatParticipant in
            ChatParticipant(
                id: CommunicationUserIdentifier(id),
                displayName: nil,
                shareHistoryTime: nil
            )
        }

        let request = CreateChatThreadRequest(topic: topic, participants: participants)

        client.create(thread: request) { response, error in
            if let error = error {
                result(FlutterError(code: "CREATE_THREAD_FAILED", message: error.localizedDescription, details: nil))
                return
            }

            guard let thread = response?.chatThread else {
                result(FlutterError(code: "CREATE_THREAD_FAILED", message: "Failed to create chat thread", details: nil))
                return
            }

            result(["id": thread.id, "topic": thread.topic ?? ""])
        }
    }

    private func joinChatThread(args: [String: Any], result: @escaping FlutterResult) {
        guard let threadId = args["threadId"] as? String, !threadId.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Thread ID is required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        do {
            chatThreadClient = try client.createClient(forThread: threadId)
            result(["id": threadId, "topic": ""])
        } catch {
            result(FlutterError(code: "JOIN_THREAD_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func sendMessage(args: [String: Any], result: @escaping FlutterResult) {
        guard let threadId = args["threadId"] as? String, !threadId.isEmpty,
              let content = args["content"] as? String, !content.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Thread ID and content are required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        do {
            let threadClient = try client.createClient(forThread: threadId)
            let request = SendChatMessageRequest(
                content: content,
                senderDisplayName: nil,
                type: .text,
                metadata: nil
            )

            threadClient.send(message: request) { response, error in
                if let error = error {
                    result(FlutterError(code: "SEND_MESSAGE_FAILED", message: error.localizedDescription, details: nil))
                    return
                }

                if let messageId = response?.id {
                    result(messageId)
                } else {
                    result(FlutterError(code: "SEND_MESSAGE_FAILED", message: "Failed to send message", details: nil))
                }
            }
        } catch {
            result(FlutterError(code: "SEND_MESSAGE_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func getMessages(args: [String: Any], result: @escaping FlutterResult) {
        guard let threadId = args["threadId"] as? String, !threadId.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Thread ID is required", details: nil))
            return
        }
        guard let client = chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Chat client not initialized", details: nil))
            return
        }

        do {
            let threadClient = try client.createClient(forThread: threadId)
            let maxMessages = args["maxMessages"] as? Int ?? 20
            let options = ListChatMessagesOptions(maxPageSize: maxMessages)

            threadClient.listMessages(withOptions: options) { response, error in
                if let error = error {
                    result(FlutterError(code: "GET_MESSAGES_FAILED", message: error.localizedDescription, details: nil))
                    return
                }

                let items = response?.items ?? []
                let messages = items.compactMap { message -> [String: Any]? in
                    guard let chatMessage = message as? ChatMessage else { return nil }
                    return [
                        "id": chatMessage.id ?? "",
                        "content": chatMessage.content?.message ?? "",
                        "senderId": chatMessage.sender?.identifier ?? "",
                        "sentOn": chatMessage.createdOn?.iso8601String() ?? ""
                    ]
                }
                result(messages)
            }
        } catch {
            result(FlutterError(code: "GET_MESSAGES_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func sendTypingNotification(result: FlutterResult) {
        guard let threadClient = chatThreadClient else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Chat thread client not initialized. Join a thread first.",
                details: nil
            ))
            return
        }

        threadClient.sendTypingNotification { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "TYPING_NOTIFICATION_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        }
    }

    // MARK: - CallDelegate

    public func call(_ call: Call, didUpdateState args: PropertyChangedEvent) {
        if call.state == .disconnected {
            cleanupCallResources()
        }
    }

    public func call(_ call: Call, didUpdateRemoteParticipants args: ParticipantsUpdatedEvent) {
        handleAddedParticipants(args.addedParticipants)
        handleRemovedParticipants(args.removedParticipants)
    }

    // MARK: - RemoteParticipantDelegate

    public func remoteParticipant(_ remoteParticipant: RemoteParticipant, didUpdateVideoStreams args: RemoteVideoStreamsEvent) {
        args.addedRemoteVideoStreams.forEach { subscribeRemoteStream($0) }
        args.removedRemoteVideoStreams.forEach { removeRemoteStream(streamId: Int($0.id)) }
    }

    // MARK: - CallAgentDelegate

    public func callAgent(_ callAgent: CallAgent, didReceiveIncomingCall incomingCall: IncomingCall) {
        self.incomingCall = incomingCall
        answerIncomingCall()
    }
}

private let isoDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private extension Date {
    func iso8601String() -> String {
        isoDateFormatter.string(from: self)
    }
}
