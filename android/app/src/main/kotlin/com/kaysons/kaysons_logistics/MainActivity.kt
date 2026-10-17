package com.kaysons.kaysons_logistics

import android.app.Activity
import android.content.Intent
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.ActivityResult as PlayActivityResult
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.kaysons.kaysons_logistics/app_updates"
        private const val EVENT_CHANNEL = "com.kaysons.kaysons_logistics/app_update_events"
        private const val UPDATE_REQUEST_CODE = 0x4B59
        private const val PLAY_STORE_PACKAGE = "com.android.vending"
    }

    private var appUpdateManager: AppUpdateManager? = null
    private var installStateListener: InstallStateUpdatedListener? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var latestUpdateSnapshot: Map<String, Any?>? = null
    private var pendingUpdateResult: PendingMethodResult? = null
    private val pendingMethodResults = mutableSetOf<PendingMethodResult>()
    private var isDisposed = false

    private inner class PendingMethodResult(
        private val delegate: MethodChannel.Result,
    ) : MethodChannel.Result {
        private var completed = false

        init {
            pendingMethodResults.add(this)
        }

        override fun success(result: Any?) {
            finish { delegate.success(result) }
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            finish { delegate.error(errorCode, errorMessage, errorDetails) }
        }

        override fun notImplemented() {
            finish { delegate.notImplemented() }
        }

        private inline fun finish(reply: () -> Unit) {
            if (completed) return
            completed = true
            pendingMethodResults.remove(this)
            reply()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result -> handleMethodCall(call, PendingMethodResult(result)) }
        }

        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).also { channel ->
            channel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    if (isDisposed) return
                    eventSink = events
                    latestUpdateSnapshot?.let(events::success)
                    refreshUpdateSnapshot()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
        }

        // A manager/listener failure must not prevent Flutter from starting. Calls that need
        // Play will report the failure through their MethodChannel result.
        try {
            getAppUpdateManager()
        } catch (_: Exception) {
            // The error is surfaced when Flutter requests an update operation.
        }
    }

    private fun handleMethodCall(call: MethodCall, result: PendingMethodResult) {
        if (isDisposed) {
            result.error("activity_disposed", "The Android activity is no longer available.", null)
            return
        }

        when (call.method) {
            "checkForUpdate" -> checkForUpdate(result)
            "startFlexibleUpdate" -> startFlexibleUpdate(result)
            "completeUpdate" -> completeUpdate(result)
            else -> result.notImplemented()
        }
    }

    private fun checkForUpdate(result: PendingMethodResult) {
        val manager = try {
            requirePlayStoreInstall()
            getAppUpdateManager()
        } catch (exception: Exception) {
            result.error("play_update_unavailable", exception.message ?: "Google Play in-app updates are unavailable.", null)
            return
        }

        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                val snapshot = snapshotFor(info)
                latestUpdateSnapshot = snapshot
                if (!isDisposed) eventSink?.success(snapshot)
                result.success(snapshot)
            }
            .addOnFailureListener { exception ->
                result.error("play_update_unavailable", exception.message ?: "Could not check for a Google Play update.", null)
            }
    }

    private fun startFlexibleUpdate(result: PendingMethodResult) {
        if (pendingUpdateResult != null) {
            result.error("update_flow_in_progress", "An in-app update flow is already waiting for a result.", null)
            return
        }

        val manager = try {
            requirePlayStoreInstall()
            getAppUpdateManager()
        } catch (exception: Exception) {
            result.error("play_update_unavailable", exception.message ?: "Google Play in-app updates are unavailable.", null)
            return
        }

        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                if (isDisposed) {
                    result.error("activity_disposed", "The Android activity is no longer available.", null)
                    return@addOnSuccessListener
                }

                val snapshot = snapshotFor(info)
                latestUpdateSnapshot = snapshot
                eventSink?.success(snapshot)

                val options = AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build()
                if (info.updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE ||
                    !info.isUpdateTypeAllowed(options)
                ) {
                    result.success(false)
                    return@addOnSuccessListener
                }

                pendingUpdateResult = result
                try {
                    val started = manager.startUpdateFlowForResult(info, this, options, UPDATE_REQUEST_CODE)
                    if (!started) {
                        pendingUpdateResult = null
                        result.success(false)
                    }
                } catch (exception: Exception) {
                    pendingUpdateResult = null
                    result.error("play_update_start_failed", exception.message ?: "Could not start the flexible update flow.", null)
                }
            }
            .addOnFailureListener { exception ->
                result.error("play_update_unavailable", exception.message ?: "Could not check for a Google Play update.", null)
            }
    }

    private fun completeUpdate(result: PendingMethodResult) {
        val manager = try {
            requirePlayStoreInstall()
            getAppUpdateManager()
        } catch (exception: Exception) {
            result.error("play_update_unavailable", exception.message ?: "Google Play in-app updates are unavailable.", null)
            return
        }

        manager.completeUpdate()
            .addOnSuccessListener {
                result.success(true)
            }
            .addOnFailureListener { exception ->
                result.error("play_update_complete_failed", exception.message ?: "Could not complete the downloaded update.", null)
            }
    }

    private fun getAppUpdateManager(): AppUpdateManager {
        appUpdateManager?.let { return it }

        val manager = AppUpdateManagerFactory.create(applicationContext)
        val listener = InstallStateUpdatedListener { state ->
            if (!isDisposed) publishInstallState(state)
        }
        manager.registerListener(listener)
        appUpdateManager = manager
        installStateListener = listener
        return manager
    }

    private fun requirePlayStoreInstall() {
        val installerPackage = packageManager.getInstallerPackageName(packageName)
        if (installerPackage != PLAY_STORE_PACKAGE) {
            throw UnsupportedOperationException(
                "Google Play in-app updates require an installation from the Google Play Store."
            )
        }
    }

    private fun snapshotFor(info: AppUpdateInfo): Map<String, Any?> {
        val availability = info.updateAvailability()
        val installStatus = info.installStatus()
        val updateAvailable = availability == UpdateAvailability.UPDATE_AVAILABLE
        val updateInProgress = availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS ||
            isInstallInProgress(installStatus)
        val hasUpdateVersion = updateAvailable || updateInProgress

        return mapOf(
            "available" to updateAvailable,
            "downloaded" to (installStatus == InstallStatus.DOWNLOADED),
            "inProgress" to updateInProgress,
            "flexibleAllowed" to info.isUpdateTypeAllowed(
                AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build()
            ),
            "immediateAllowed" to info.isUpdateTypeAllowed(
                AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build()
            ),
            "availableVersionCode" to if (hasUpdateVersion) info.availableVersionCode() else null,
        )
    }

    private fun isInstallInProgress(status: Int): Boolean = when (status) {
        InstallStatus.PENDING,
        InstallStatus.DOWNLOADING,
        InstallStatus.DOWNLOADED,
        InstallStatus.INSTALLING -> true
        else -> false
    }

    private fun publishInstallState(state: InstallState) {
        val snapshot = (latestUpdateSnapshot ?: emptyUpdateSnapshot()).toMutableMap()
        val status = state.installStatus()

        snapshot["downloaded"] = status == InstallStatus.DOWNLOADED
        snapshot["inProgress"] = isInstallInProgress(status)
        if (status == InstallStatus.INSTALLED) {
            snapshot["available"] = false
            snapshot["flexibleAllowed"] = false
            snapshot["immediateAllowed"] = false
            snapshot["availableVersionCode"] = null
        }

        latestUpdateSnapshot = snapshot
        if (!isDisposed) eventSink?.success(snapshot)
    }

    private fun emptyUpdateSnapshot(): Map<String, Any?> = mapOf(
        "available" to false,
        "downloaded" to false,
        "inProgress" to false,
        "flexibleAllowed" to false,
        "immediateAllowed" to false,
        "availableVersionCode" to null,
    )

    private fun refreshUpdateSnapshot() {
        if (isDisposed) return
        val manager = try {
            getAppUpdateManager()
        } catch (_: Exception) {
            return
        }

        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                if (isDisposed) return@addOnSuccessListener
                val snapshot = snapshotFor(info)
                latestUpdateSnapshot = snapshot
                eventSink?.success(snapshot)
            }
    }

    override fun onResume() {
        super.onResume()
        // A flexible download may have completed while the activity was backgrounded.
        // Recheck and publish its current state without starting an update flow.
        refreshUpdateSnapshot()
    }

    @Deprecated("Deprecated in Android, retained for Google Play's documented result callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != UPDATE_REQUEST_CODE) return

        val result = pendingUpdateResult ?: return
        pendingUpdateResult = null
        when (resultCode) {
            Activity.RESULT_OK -> result.success(true)
            Activity.RESULT_CANCELED -> result.success(false)
            PlayActivityResult.RESULT_IN_APP_UPDATE_FAILED -> result.error(
                "play_update_start_failed",
                "Google Play could not complete the flexible update confirmation flow.",
                null,
            )
            else -> result.error(
                "play_update_start_failed",
                "Google Play returned an unexpected result for the flexible update flow.",
                resultCode,
            )
        }
    }

    private fun cleanupUpdateBridge() {
        if (isDisposed) return
        isDisposed = true
        eventSink = null
        pendingUpdateResult = null
        pendingMethodResults.toList().forEach { result ->
            result.error("activity_disposed", "The Android activity was disposed before the operation completed.", null)
        }

        val manager = appUpdateManager
        val listener = installStateListener
        if (manager != null && listener != null) {
            try {
                manager.unregisterListener(listener)
            } catch (_: Exception) {
                // Cleanup should not prevent Flutter from shutting down.
            }
        }
        installStateListener = null
        appUpdateManager = null
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        cleanupUpdateBridge()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        cleanupUpdateBridge()
        super.onDestroy()
    }
}
