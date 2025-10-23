package com.example.acs_flutter_sdk

import android.content.Context
import com.azure.android.communication.calling.*
import com.azure.android.communication.chat.*
import com.azure.android.communication.common.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.ExecutionException

/**
 * AcsFlutterSdkPlugin
 *
 * Flutter plugin for Microsoft Azure Communication Services.
 * Provides access to calling, chat, and identity management features.
 */
class AcsFlutterSdkPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    // Azure Communication Services clients
    private var tokenCredential: CommunicationTokenCredential? = null
    private var callClient: CallClient? = null
    private var callAgent: CallAgent? = null
    private var call: Call? = null
    private var chatClient: ChatClient? = null
    private var chatThreadClient: ChatThreadClient? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "acs_flutter_sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // Platform info
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            // Identity methods
            "initializeIdentity" -> initializeIdentity(call, result)
            "createUser" -> createUser(result)
            "getToken" -> getToken(call, result)
            "revokeToken" -> revokeToken(call, result)

            // Calling methods
            "initializeCalling" -> initializeCalling(call, result)
            "startCall" -> startCall(call, result)
            "joinCall" -> joinCall(call, result)
            "endCall" -> endCall(result)
            "muteAudio" -> muteAudio(result)
            "unmuteAudio" -> unmuteAudio(result)
            "startVideo" -> startVideo(result)
            "stopVideo" -> stopVideo(result)

            // Chat methods
            "initializeChat" -> initializeChat(call, result)
            "createChatThread" -> createChatThread(call, result)
            "joinChatThread" -> joinChatThread(call, result)
            "sendMessage" -> sendMessage(call, result)
            "getMessages" -> getMessages(call, result)
            "sendTypingNotification" -> sendTypingNotification(result)

            else -> result.notImplemented()
        }
    }

    // ========== Identity Management ==========

    /**
     * Initialize identity client with connection string
     */
    private fun initializeIdentity(call: MethodCall, result: Result) {
        try {
            val connectionString = call.argument<String>("connectionString")
            if (connectionString == null) {
                result.error("INVALID_ARGUMENT", "Connection string is required", null)
                return
            }

            // Note: In production, identity operations should be done server-side
            // This is a simplified implementation for demonstration
            result.success(mapOf("status" to "initialized"))
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    /**
     * Create a new communication user
     * Note: This should be done server-side in production
     */
    private fun createUser(result: Result) {
        result.error(
            "NOT_IMPLEMENTED",
            "User creation should be done server-side for security. Use your backend API.",
            null
        )
    }

    /**
     * Get access token for a user
     * Note: This should be done server-side in production
     */
    private fun getToken(call: MethodCall, result: Result) {
        result.error(
            "NOT_IMPLEMENTED",
            "Token generation should be done server-side for security. Use your backend API.",
            null
        )
    }

    /**
     * Revoke access token
     */
    private fun revokeToken(call: MethodCall, result: Result) {
        result.error(
            "NOT_IMPLEMENTED",
            "Token revocation should be done server-side. Use your backend API.",
            null
        )
    }

    // ========== Calling ==========

    private fun initializeCalling(call: MethodCall, result: Result) {
        val accessToken = call.argument<String>("accessToken")
        if (accessToken == null) {
            result.error("INVALID_ARGUMENT", "Access token is required", null)
            return
        }

        try {
            // Initialize call client
            callClient = CallClient()

            // Create token credential
            tokenCredential = CommunicationTokenCredential(accessToken)

            // Create call agent
            val callAgentFuture = callClient!!.createCallAgent(
                context,
                tokenCredential!!
            )

            callAgentFuture.whenComplete { agent, error ->
                if (error != null) {
                    result.error("INITIALIZATION_ERROR", error.message, null)
                    return@whenComplete
                }

                callAgent = agent
                result.success(mapOf("status" to "initialized"))
            }
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun startCall(call: MethodCall, result: Result) {
        val participants = call.argument<List<String>>("participants")
        if (participants == null) {
            result.error("INVALID_ARGUMENT", "Participants list is required", null)
            return
        }

        if (callAgent == null) {
            result.error("NOT_INITIALIZED", "Call agent not initialized. Call initializeCalling first.", null)
            return
        }

        val withVideo = call.argument<Boolean>("withVideo") ?: false

        try {
            // Create call identifiers
            val callees = participants.map { CommunicationUserIdentifier(it) }

            // Start call options
            val startCallOptions = StartCallOptions()

            // Start the call
            this.call = callAgent!!.startCall(context, callees, startCallOptions)

            if (this.call != null) {
                result.success(
                    mapOf(
                        "callId" to this.call!!.id,
                        "state" to callStateToString(this.call!!.state)
                    )
                )
            } else {
                result.error("CALL_START_FAILED", "Failed to start call", null)
            }
        } catch (e: Exception) {
            result.error("CALL_START_FAILED", e.message, null)
        }
    }

    private fun joinCall(call: MethodCall, result: Result) {
        val groupCallId = call.argument<String>("groupCallId")
        if (groupCallId == null) {
            result.error("INVALID_ARGUMENT", "Group call ID is required", null)
            return
        }

        if (callAgent == null) {
            result.error("NOT_INITIALIZED", "Call agent not initialized. Call initializeCalling first.", null)
            return
        }

        val withVideo = call.argument<Boolean>("withVideo") ?: false

        try {
            // Join call options
            val joinCallOptions = JoinCallOptions()

            // Join the call
            val groupCallLocator = GroupCallLocator(java.util.UUID.fromString(groupCallId))
            this.call = callAgent!!.join(context, groupCallLocator, joinCallOptions)

            if (this.call != null) {
                result.success(
                    mapOf(
                        "callId" to this.call!!.id,
                        "state" to callStateToString(this.call!!.state)
                    )
                )
            } else {
                result.error("CALL_JOIN_FAILED", "Failed to join call", null)
            }
        } catch (e: Exception) {
            result.error("CALL_JOIN_FAILED", e.message, null)
        }
    }

    private fun endCall(result: Result) {
        if (call == null) {
            result.error("NO_ACTIVE_CALL", "No active call to end", null)
            return
        }

        try {
            val hangUpFuture = call!!.hangUp(HangUpOptions())
            hangUpFuture.whenComplete { _, error ->
                if (error != null) {
                    result.error("HANGUP_FAILED", error.message, null)
                } else {
                    call = null
                    result.success(null)
                }
            }
        } catch (e: Exception) {
            result.error("HANGUP_FAILED", e.message, null)
        }
    }

    private fun muteAudio(result: Result) {
        if (call == null) {
            result.error("NO_ACTIVE_CALL", "No active call", null)
            return
        }

        try {
            val muteFuture = call!!.muteOutgoingAudio()
            muteFuture.whenComplete { _, error ->
                if (error != null) {
                    result.error("MUTE_FAILED", error.message, null)
                } else {
                    result.success(null)
                }
            }
        } catch (e: Exception) {
            result.error("MUTE_FAILED", e.message, null)
        }
    }

    private fun unmuteAudio(result: Result) {
        if (call == null) {
            result.error("NO_ACTIVE_CALL", "No active call", null)
            return
        }

        try {
            val unmuteFuture = call!!.unmuteOutgoingAudio()
            unmuteFuture.whenComplete { _, error ->
                if (error != null) {
                    result.error("UNMUTE_FAILED", error.message, null)
                } else {
                    result.success(null)
                }
            }
        } catch (e: Exception) {
            result.error("UNMUTE_FAILED", e.message, null)
        }
    }

    private fun startVideo(result: Result) {
        result.error("NOT_IMPLEMENTED", "Video functionality requires camera access and additional setup", null)
    }

    private fun stopVideo(result: Result) {
        result.error("NOT_IMPLEMENTED", "Video functionality requires camera access and additional setup", null)
    }

    // Helper function to convert call state to string
    private fun callStateToString(state: CallState): String {
        return when (state) {
            CallState.NONE -> "none"
            CallState.CONNECTING -> "connecting"
            CallState.RINGING -> "ringing"
            CallState.CONNECTED -> "connected"
            CallState.LOCAL_HOLD -> "onHold"
            CallState.DISCONNECTING -> "disconnecting"
            CallState.DISCONNECTED -> "disconnected"
            CallState.EARLY_MEDIA -> "earlyMedia"
            CallState.REMOTE_HOLD -> "remoteHold"
            else -> "unknown"
        }
    }

    // ========== Chat ==========

    private fun initializeChat(call: MethodCall, result: Result) {
        val accessToken = call.argument<String>("accessToken")
        val endpoint = call.argument<String>("endpoint")

        if (accessToken == null || endpoint == null) {
            result.error("INVALID_ARGUMENT", "Access token and endpoint are required", null)
            return
        }

        try {
            // Create token credential
            tokenCredential = CommunicationTokenCredential(accessToken)

            // Create chat client builder
            val chatClientBuilder = ChatClientBuilder()
                .endpoint(endpoint)
                .credential(tokenCredential!!)

            // Build chat client
            chatClient = chatClientBuilder.buildClient()

            result.success(mapOf("status" to "initialized"))
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun createChatThread(call: MethodCall, result: Result) {
        val topic = call.argument<String>("topic")
        if (topic == null) {
            result.error("INVALID_ARGUMENT", "Topic is required", null)
            return
        }

        if (chatClient == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized. Call initializeChat first.", null)
            return
        }

        val participants = call.argument<List<String>>("participants") ?: emptyList()

        try {
            // Create thread request
            val createChatThreadOptions = CreateChatThreadOptions()
                .setTopic(topic)

            // Add participants
            participants.forEach { participantId ->
                val participant = ChatParticipant()
                participant.communicationIdentifier = CommunicationUserIdentifier(participantId)
                createChatThreadOptions.addParticipant(participant)
            }

            // Create thread
            val createChatThreadResult = chatClient!!.createChatThread(createChatThreadOptions)

            if (createChatThreadResult != null) {
                val chatThread = createChatThreadResult.chatThread
                result.success(
                    mapOf(
                        "threadId" to chatThread.id,
                        "topic" to (chatThread.topic ?: "")
                    )
                )
            } else {
                result.error("CREATE_THREAD_FAILED", "Failed to create chat thread", null)
            }
        } catch (e: Exception) {
            result.error("CREATE_THREAD_FAILED", e.message, null)
        }
    }

    private fun joinChatThread(call: MethodCall, result: Result) {
        val threadId = call.argument<String>("threadId")
        if (threadId == null) {
            result.error("INVALID_ARGUMENT", "Thread ID is required", null)
            return
        }

        if (chatClient == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized. Call initializeChat first.", null)
            return
        }

        try {
            // Get chat thread client
            chatThreadClient = chatClient!!.getChatThreadClient(threadId)
            result.success(mapOf("status" to "joined"))
        } catch (e: Exception) {
            result.error("JOIN_THREAD_FAILED", e.message, null)
        }
    }

    private fun sendMessage(call: MethodCall, result: Result) {
        val threadId = call.argument<String>("threadId")
        val content = call.argument<String>("content")

        if (threadId == null || content == null) {
            result.error("INVALID_ARGUMENT", "Thread ID and content are required", null)
            return
        }

        if (chatClient == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized", null)
            return
        }

        try {
            val threadClient = chatClient!!.getChatThreadClient(threadId)

            // Send message options
            val sendChatMessageOptions = SendChatMessageOptions()
                .setContent(content)
                .setType(ChatMessageType.TEXT)

            // Send message
            val sendMessageResult = threadClient.sendMessage(sendChatMessageOptions)

            if (sendMessageResult != null) {
                result.success(sendMessageResult.id)
            } else {
                result.error("SEND_MESSAGE_FAILED", "Failed to send message", null)
            }
        } catch (e: Exception) {
            result.error("SEND_MESSAGE_FAILED", e.message, null)
        }
    }

    private fun getMessages(call: MethodCall, result: Result) {
        val threadId = call.argument<String>("threadId")
        if (threadId == null) {
            result.error("INVALID_ARGUMENT", "Thread ID is required", null)
            return
        }

        if (chatClient == null) {
            result.error("NOT_INITIALIZED", "Chat client not initialized", null)
            return
        }

        try {
            val threadClient = chatClient!!.getChatThreadClient(threadId)
            val maxMessages = call.argument<Int>("maxMessages") ?: 20

            // List messages options
            val listMessagesOptions = ListChatMessagesOptions()
                .setMaxPageSize(maxMessages)

            // Get messages
            val messagesPagedIterable = threadClient.listMessages(listMessagesOptions, null)

            val messageList = mutableListOf<Map<String, Any>>()
            messagesPagedIterable.iterableByPage().forEach { page ->
                page.elements.forEach { chatMessage ->
                    messageList.add(
                        mapOf(
                            "id" to chatMessage.id,
                            "content" to (chatMessage.content?.message ?: ""),
                            "senderId" to (chatMessage.senderCommunicationIdentifier?.rawId ?: ""),
                            "sentOn" to (chatMessage.createdOn?.toString() ?: "")
                        )
                    )
                }
            }

            result.success(messageList)
        } catch (e: Exception) {
            result.error("GET_MESSAGES_FAILED", e.message, null)
        }
    }

    private fun sendTypingNotification(result: Result) {
        if (chatThreadClient == null) {
            result.error("NOT_INITIALIZED", "Chat thread client not initialized. Join a thread first.", null)
            return
        }

        try {
            chatThreadClient!!.sendTypingNotification()
            result.success(null)
        } catch (e: Exception) {
            result.error("TYPING_NOTIFICATION_FAILED", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        tokenCredential = null
    }
}
