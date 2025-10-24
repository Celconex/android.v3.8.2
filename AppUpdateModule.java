package com.celconex.app;

import android.app.Activity;
import android.content.IntentSender;
import android.util.Log;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.install.InstallState;
import com.google.android.play.core.install.InstallStateUpdatedListener;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.InstallStatus;
import com.google.android.play.core.install.model.UpdateAvailability;
import com.google.android.play.core.tasks.Task;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class AppUpdateModule extends ReactContextBaseJavaModule {
    private static final String TAG = "CelconexAppUpdate";
    private static final int REQUEST_CODE_UPDATE = 1991;
    
    private AppUpdateManager appUpdateManager;
    private ReactApplicationContext reactContext;
    
    private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
        @Override
        public void onActivityResult(Activity activity, int requestCode, int resultCode, @Nullable android.content.Intent data) {
            if (requestCode == REQUEST_CODE_UPDATE) {
                WritableMap result = Arguments.createMap();
                if (resultCode == Activity.RESULT_OK) {
                    result.putString("status", "success");
                    result.putString("message", "Update started successfully");
                } else if (resultCode == Activity.RESULT_CANCELED) {
                    result.putString("status", "cancelled");
                    result.putString("message", "Update cancelled by user");
                } else {
                    result.putString("status", "failed");
                    result.putString("message", "Update failed with code: " + resultCode);
                }
                sendEvent("onUpdateResult", result);
            }
        }
    };

    private final InstallStateUpdatedListener installStateUpdatedListener = new InstallStateUpdatedListener() {
        @Override
        public void onStateUpdate(@NonNull InstallState installState) {
            WritableMap updateState = Arguments.createMap();
            
            switch (installState.installStatus()) {
                case InstallStatus.PENDING:
                    updateState.putString("status", "pending");
                    updateState.putString("message", "Update download pending");
                    break;
                case InstallStatus.DOWNLOADING:
                    updateState.putString("status", "downloading");
                    updateState.putString("message", "Downloading update...");
                    long bytesDownloaded = installState.bytesDownloaded();
                    long totalBytesToDownload = installState.totalBytesToDownload();
                    if (totalBytesToDownload > 0) {
                        int progress = (int) ((bytesDownloaded * 100) / totalBytesToDownload);
                        updateState.putInt("progress", progress);
                        updateState.putString("message", "Downloading: " + progress + "%");
                    }
                    break;
                case InstallStatus.DOWNLOADED:
                    updateState.putString("status", "downloaded");
                    updateState.putString("message", "Update downloaded, ready to install");
                    break;
                case InstallStatus.INSTALLING:
                    updateState.putString("status", "installing");
                    updateState.putString("message", "Installing update...");
                    break;
                case InstallStatus.INSTALLED:
                    updateState.putString("status", "installed");
                    updateState.putString("message", "Update installed successfully");
                    // Unregister listener after successful install
                    appUpdateManager.unregisterListener(installStateUpdatedListener);
                    break;
                case InstallStatus.FAILED:
                    updateState.putString("status", "failed");
                    updateState.putString("message", "Update installation failed");
                    updateState.putInt("errorCode", installState.installErrorCode());
                    break;
                case InstallStatus.CANCELED:
                    updateState.putString("status", "cancelled");
                    updateState.putString("message", "Update cancelled");
                    break;
                default:
                    updateState.putString("status", "unknown");
                    updateState.putString("message", "Unknown update status");
                    break;
            }
            
            sendEvent("onUpdateStateChange", updateState);
        }
    };

    public AppUpdateModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        this.appUpdateManager = AppUpdateManagerFactory.create(reactContext);
        reactContext.addActivityEventListener(mActivityEventListener);
    }

    @NonNull
    @Override
    public String getName() {
        return "CelconexAppUpdate";
    }

    @ReactMethod
    public void checkForUpdate(Promise promise) {
        Log.d(TAG, "Checking for app updates...");
        
        Task<AppUpdateInfo> appUpdateInfoTask = appUpdateManager.getAppUpdateInfo();
        appUpdateInfoTask.addOnSuccessListener(appUpdateInfo -> {
            WritableMap result = Arguments.createMap();
            result.putBoolean("updateAvailable", 
                appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE);
            
            if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                result.putInt("availableVersionCode", appUpdateInfo.availableVersionCode());
                result.putBoolean("isImmediateUpdateAllowed", 
                    appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE));
                result.putBoolean("isFlexibleUpdateAllowed", 
                    appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE));
                result.putInt("updatePriority", appUpdateInfo.updatePriority());
                result.putLong("clientVersionStalenessDays", 
                    appUpdateInfo.clientVersionStalenessDays() != null ? 
                    appUpdateInfo.clientVersionStalenessDays() : -1);
            }
            
            promise.resolve(result);
        }).addOnFailureListener(exception -> {
            Log.e(TAG, "Failed to check for updates", exception);
            promise.reject("UPDATE_CHECK_FAILED", exception.getMessage(), exception);
        });
    }

    @ReactMethod
    public void startImmediateUpdate(Promise promise) {
        Log.d(TAG, "Starting immediate update...");
        
        Task<AppUpdateInfo> appUpdateInfoTask = appUpdateManager.getAppUpdateInfo();
        appUpdateInfoTask.addOnSuccessListener(appUpdateInfo -> {
            if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                
                try {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.IMMEDIATE,
                        getCurrentActivity(),
                        REQUEST_CODE_UPDATE
                    );
                    promise.resolve("Update flow started");
                } catch (IntentSender.SendIntentException e) {
                    Log.e(TAG, "Failed to start immediate update", e);
                    promise.reject("UPDATE_START_FAILED", e.getMessage(), e);
                }
            } else {
                promise.reject("UPDATE_NOT_AVAILABLE", "Immediate update not available");
            }
        }).addOnFailureListener(exception -> {
            Log.e(TAG, "Failed to start immediate update", exception);
            promise.reject("UPDATE_START_FAILED", exception.getMessage(), exception);
        });
    }

    @ReactMethod
    public void startFlexibleUpdate(Promise promise) {
        Log.d(TAG, "Starting flexible update...");
        
        // Register listener for flexible update
        appUpdateManager.registerListener(installStateUpdatedListener);
        
        Task<AppUpdateInfo> appUpdateInfoTask = appUpdateManager.getAppUpdateInfo();
        appUpdateInfoTask.addOnSuccessListener(appUpdateInfo -> {
            if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
                
                try {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.FLEXIBLE,
                        getCurrentActivity(),
                        REQUEST_CODE_UPDATE
                    );
                    promise.resolve("Flexible update started");
                } catch (IntentSender.SendIntentException e) {
                    Log.e(TAG, "Failed to start flexible update", e);
                    appUpdateManager.unregisterListener(installStateUpdatedListener);
                    promise.reject("UPDATE_START_FAILED", e.getMessage(), e);
                }
            } else {
                appUpdateManager.unregisterListener(installStateUpdatedListener);
                promise.reject("UPDATE_NOT_AVAILABLE", "Flexible update not available");
            }
        }).addOnFailureListener(exception -> {
            Log.e(TAG, "Failed to start flexible update", exception);
            appUpdateManager.unregisterListener(installStateUpdatedListener);
            promise.reject("UPDATE_START_FAILED", exception.getMessage(), exception);
        });
    }

    @ReactMethod
    public void completeFlexibleUpdate(Promise promise) {
        Log.d(TAG, "Completing flexible update...");
        
        appUpdateManager.completeUpdate()
            .addOnSuccessListener(result -> {
                Log.d(TAG, "Flexible update completed");
                promise.resolve("Update completed");
            })
            .addOnFailureListener(exception -> {
                Log.e(TAG, "Failed to complete flexible update", exception);
                promise.reject("UPDATE_COMPLETE_FAILED", exception.getMessage(), exception);
            });
    }

    @ReactMethod
    public void resumeUpdate(Promise promise) {
        Log.d(TAG, "Checking for resumed updates...");
        
        Task<AppUpdateInfo> appUpdateInfoTask = appUpdateManager.getAppUpdateInfo();
        appUpdateInfoTask.addOnSuccessListener(appUpdateInfo -> {
            if (appUpdateInfo.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                try {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.IMMEDIATE,
                        getCurrentActivity(),
                        REQUEST_CODE_UPDATE
                    );
                    promise.resolve("Update resumed");
                } catch (IntentSender.SendIntentException e) {
                    Log.e(TAG, "Failed to resume update", e);
                    promise.reject("UPDATE_RESUME_FAILED", e.getMessage(), e);
                }
            } else {
                promise.resolve("No update to resume");
            }
        }).addOnFailureListener(exception -> {
            Log.e(TAG, "Failed to check for resumed updates", exception);
            promise.reject("UPDATE_RESUME_FAILED", exception.getMessage(), exception);
        });
    }

    private void sendEvent(String eventName, @Nullable WritableMap params) {
        if (reactContext.hasActiveCatalystInstance()) {
            reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
        }
    }

    @Override
    public void onCatalystInstanceDestroy() {
        super.onCatalystInstanceDestroy();
        if (appUpdateManager != null) {
            appUpdateManager.unregisterListener(installStateUpdatedListener);
        }
    }
}