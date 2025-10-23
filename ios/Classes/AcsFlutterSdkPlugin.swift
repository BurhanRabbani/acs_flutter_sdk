import Flutter
import UIKit
import AzureCommunicationCommon
import AzureCommunicationCalling
import AzureCommunicationChat

/// AcsFlutterSdkPlugin
///
/// Flutter plugin for Microsoft Azure Communication Services.
/// Provides access to calling, chat, and identity management features.
public class AcsFlutterSdkPlugin: NSObject, FlutterPlugin {

    // Azure Communication Services clients
    private var tokenCredential: CommunicationTokenCredential?
    private var callClient: CallClient?
    private var callAgent: CallAgent?
    private var call: Call?
    private var chatClient: ChatClient?
    private var chatThreadClient: ChatThreadClient?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "acs_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = AcsFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Platform info
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        // Identity methods
        case "initializeIdentity":
            initializeIdentity(call: call, result: result)
        case "createUser":
            createUser(result: result)
        case "getToken":
            getToken(call: call, result: result)
        case "revokeToken":
            revokeToken(call: call, result: result)

        // Calling methods
        case "initializeCalling":
            initializeCalling(call: call, result: result)
        case "startCall":
            startCall(call: call, result: result)
        case "joinCall":
            joinCall(call: call, result: result)
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

        // Chat methods
        case "initializeChat":
            initializeChat(call: call, result: result)
        case "createChatThread":
            createChatThread(call: call, result: result)
        case "joinChatThread":
            joinChatThread(call: call, result: result)
        case "sendMessage":
            sendMessage(call: call, result: result)
        case "getMessages":
            getMessages(call: call, result: result)
        case "sendTypingNotification":
            sendTypingNotification(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Identity Management

    /// Initialize identity client with connection string
    private func initializeIdentity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let connectionString = args["connectionString"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Connection string is required",
                              details: nil))
            return
        }

        // Note: In production, identity operations should be done server-side
        result(["status": "initialized"])
    }

    /// Create a new communication user
    /// Note: This should be done server-side in production
    private func createUser(result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED",
                          message: "User creation should be done server-side for security. Use your backend API.",
                          details: nil))
    }

    /// Get access token for a user
    /// Note: This should be done server-side in production
    private func getToken(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED",
                          message: "Token generation should be done server-side for security. Use your backend API.",
                          details: nil))
    }

    /// Revoke access token
    private func revokeToken(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED",
                          message: "Token revocation should be done server-side. Use your backend API.",
                          details: nil))
    }

    // MARK: - Calling

    private func initializeCalling(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let accessToken = args["accessToken"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Access token is required",
                              details: nil))
            return
        }

        do {
            // Initialize call client
            self.callClient = CallClient()

            // Create token credential
            self.tokenCredential = try CommunicationTokenCredential(token: accessToken)

            // Create call agent
            self.callClient?.createCallAgent(userCredential: self.tokenCredential!) { callAgent, error in
                if let error = error {
                    result(FlutterError(code: "INITIALIZATION_ERROR",
                                      message: error.localizedDescription,
                                      details: nil))
                    return
                }

                self.callAgent = callAgent
                result(["status": "initialized"])
            }
        } catch {
            result(FlutterError(code: "INITIALIZATION_ERROR",
                              message: error.localizedDescription,
                              details: nil))
        }
    }

    private func startCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let participants = args["participants"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Participants list is required",
                              details: nil))
            return
        }

        guard let callAgent = self.callAgent else {
            result(FlutterError(code: "NOT_INITIALIZED",
                              message: "Call agent not initialized. Call initializeCalling first.",
                              details: nil))
            return
        }

        let withVideo = args["withVideo"] as? Bool ?? false

        // Create call identifiers
        let callees = participants.map { CommunicationUserIdentifier($0) }

        // Start call options
        let startCallOptions = StartCallOptions()

        // Start the call
        self.call = callAgent.startCall(participants: callees, options: startCallOptions)

        if let call = self.call {
            result([
                "callId": call.id,
                "state": callStateToString(call.state)
            ])
        } else {
            result(FlutterError(code: "CALL_START_FAILED",
                              message: "Failed to start call",
                              details: nil))
        }
    }

    private func joinCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let groupCallId = args["groupCallId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Group call ID is required",
                              details: nil))
            return
        }

        guard let callAgent = self.callAgent else {
            result(FlutterError(code: "NOT_INITIALIZED",
                              message: "Call agent not initialized. Call initializeCalling first.",
                              details: nil))
            return
        }

        let withVideo = args["withVideo"] as? Bool ?? false

        // Join call options
        let joinCallOptions = JoinCallOptions()

        // Join the call
        let groupCallLocator = GroupCallLocator(groupId: UUID(uuidString: groupCallId)!)
        self.call = callAgent.join(with: groupCallLocator, joinCallOptions: joinCallOptions)

        if let call = self.call {
            result([
                "callId": call.id,
                "state": callStateToString(call.state)
            ])
        } else {
            result(FlutterError(code: "CALL_JOIN_FAILED",
                              message: "Failed to join call",
                              details: nil))
        }
    }

    private func endCall(result: @escaping FlutterResult) {
        guard let call = self.call else {
            result(FlutterError(code: "NO_ACTIVE_CALL",
                              message: "No active call to end",
                              details: nil))
            return
        }

        call.hangUp(options: HangUpOptions()) { error in
            if let error = error {
                result(FlutterError(code: "HANGUP_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
                self.call = nil
                result(nil)
            }
        }
    }

    private func muteAudio(result: @escaping FlutterResult) {
        guard let call = self.call else {
            result(FlutterError(code: "NO_ACTIVE_CALL",
                              message: "No active call",
                              details: nil))
            return
        }

        call.muteOutgoingAudio() { error in
            if let error = error {
                result(FlutterError(code: "MUTE_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
                result(nil)
            }
        }
    }

    private func unmuteAudio(result: @escaping FlutterResult) {
        guard let call = self.call else {
            result(FlutterError(code: "NO_ACTIVE_CALL",
                              message: "No active call",
                              details: nil))
            return
        }

        call.unmuteOutgoingAudio() { error in
            if let error = error {
                result(FlutterError(code: "UNMUTE_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
                result(nil)
            }
        }
    }

    private func startVideo(result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED",
                          message: "Video functionality requires camera access and additional setup",
                          details: nil))
    }

    private func stopVideo(result: @escaping FlutterResult) {
        result(FlutterError(code: "NOT_IMPLEMENTED",
                          message: "Video functionality requires camera access and additional setup",
                          details: nil))
    }

    // Helper function to convert call state to string
    private func callStateToString(_ state: CallState) -> String {
        switch state {
        case .none:
            return "none"
        case .connecting:
            return "connecting"
        case .ringing:
            return "ringing"
        case .connected:
            return "connected"
        case .localHold:
            return "onHold"
        case .disconnecting:
            return "disconnecting"
        case .disconnected:
            return "disconnected"
        case .earlyMedia:
            return "earlyMedia"
        case .remoteHold:
            return "remoteHold"
        @unknown default:
            return "unknown"
        }
    }

    // MARK: - Chat

    private func initializeChat(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let accessToken = args["accessToken"] as? String,
              let endpoint = args["endpoint"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Access token and endpoint are required",
                              details: nil))
            return
        }

        do {
            // Create token credential
            self.tokenCredential = try CommunicationTokenCredential(token: accessToken)

            // Create chat client configuration
            let chatClientOptions = AzureCommunicationChatClientOptions()

            // Initialize chat client
            self.chatClient = try ChatClient(
                endpoint: endpoint,
                credential: self.tokenCredential!,
                withOptions: chatClientOptions
            )

            result(["status": "initialized"])
        } catch {
            result(FlutterError(code: "INITIALIZATION_ERROR",
                              message: error.localizedDescription,
                              details: nil))
        }
    }

    private func createChatThread(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let topic = args["topic"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Topic is required",
                              details: nil))
            return
        }

        guard let chatClient = self.chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED",
                              message: "Chat client not initialized. Call initializeChat first.",
                              details: nil))
            return
        }

        let participants = args["participants"] as? [String] ?? []

        // Create thread request
        let request = CreateChatThreadRequest(
            topic: topic,
            participants: participants.map { participantId in
                ChatParticipant(
                    id: CommunicationUserIdentifier(participantId),
                    displayName: nil,
                    shareHistoryTime: nil
                )
            }
        )

        chatClient.create(thread: request) { response, error in
            if let error = error {
                result(FlutterError(code: "CREATE_THREAD_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
                return
            }

            if let chatThread = response?.chatThread {
                result([
                    "threadId": chatThread.id,
                    "topic": chatThread.topic ?? ""
                ])
            } else {
                result(FlutterError(code: "CREATE_THREAD_FAILED",
                                  message: "Failed to create chat thread",
                                  details: nil))
            }
        }
    }

    private func joinChatThread(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let threadId = args["threadId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Thread ID is required",
                              details: nil))
            return
        }

        guard let chatClient = self.chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED",
                              message: "Chat client not initialized. Call initializeChat first.",
                              details: nil))
            return
        }

        do {
            // Get chat thread client
            self.chatThreadClient = try chatClient.createClient(forThread: threadId)
            result(["status": "joined"])
        } catch {
            result(FlutterError(code: "JOIN_THREAD_FAILED",
                              message: error.localizedDescription,
                              details: nil))
        }
    }

    private func sendMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let threadId = args["threadId"] as? String,
              let content = args["content"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Thread ID and content are required",
                              details: nil))
            return
        }

        guard let chatClient = self.chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED",
                              message: "Chat client not initialized",
                              details: nil))
            return
        }

        do {
            let threadClient = try chatClient.createClient(forThread: threadId)

            let request = SendChatMessageRequest(
                content: content,
                senderDisplayName: nil,
                type: .text,
                metadata: nil
            )

            threadClient.send(message: request) { response, error in
                if let error = error {
                    result(FlutterError(code: "SEND_MESSAGE_FAILED",
                                      message: error.localizedDescription,
                                      details: nil))
                    return
                }

                if let messageId = response?.id {
                    result(messageId)
                } else {
                    result(FlutterError(code: "SEND_MESSAGE_FAILED",
                                      message: "Failed to send message",
                                      details: nil))
                }
            }
        } catch {
            result(FlutterError(code: "SEND_MESSAGE_FAILED",
                              message: error.localizedDescription,
                              details: nil))
        }
    }

    private func getMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let threadId = args["threadId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Thread ID is required",
                              details: nil))
            return
        }

        guard let chatClient = self.chatClient else {
            result(FlutterError(code: "NOT_INITIALIZED",
                              message: "Chat client not initialized",
                              details: nil))
            return
        }

        do {
            let threadClient = try chatClient.createClient(forThread: threadId)
            let maxMessages = args["maxMessages"] as? Int ?? 20

            let options = ListChatMessagesOptions(maxPageSize: maxMessages)

            threadClient.listMessages(withOptions: options) { response, error in
                if let error = error {
                    result(FlutterError(code: "GET_MESSAGES_FAILED",
                                      message: error.localizedDescription,
                                      details: nil))
                    return
                }

                if let messages = response?.items {
                    let messageList = messages.compactMap { message -> [String: Any]? in
                        guard let chatMessage = message as? ChatMessage else { return nil }

                        return [
                            "id": chatMessage.id,
                            "content": chatMessage.content?.message ?? "",
                            "senderId": chatMessage.sender?.identifier ?? "",
                            "sentOn": ISO8601DateFormatter().string(from: chatMessage.createdOn ?? Date())
                        ]
                    }
                    result(messageList)
                } else {
                    result([])
                }
            }
        } catch {
            result(FlutterError(code: "GET_MESSAGES_FAILED",
                              message: error.localizedDescription,
                              details: nil))
        }
    }

    private func sendTypingNotification(result: @escaping FlutterResult) {
        guard let chatThreadClient = self.chatThreadClient else {
            result(FlutterError(code: "NOT_INITIALIZED",
                              message: "Chat thread client not initialized. Join a thread first.",
                              details: nil))
            return
        }

        chatThreadClient.sendTypingNotification() { error in
            if let error = error {
                result(FlutterError(code: "TYPING_NOTIFICATION_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            } else {
                result(nil)
            }
        }
    }
}
