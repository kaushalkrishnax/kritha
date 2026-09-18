package com.jeppeman.globallydynamic.generated;

import com.kritha.app.BuildConfig;
import com.kritha.app.MainActivity;

import java.util.Collections;
import java.util.List;
import java.util.Map;

public class GloballyDynamicBuildConfig {

    public long getDownloadConnectTimeout() {
        return 30000L;
    }

    public long getDownloadReadTimeout() {
        return 30000L;
    }

    public Map<String, List<String>> getInstallTimeFeatures() {
        return Collections.emptyMap();
    }

    public String[] getOnDemandFeatures() {
        return new String[] {
            "feature-litert",
            "feature-litertlm",
            "feature-onnx"
        };
    }

    public String getServerUrl() {
        return BuildConfig.GLOBALLY_DYNAMIC_SERVER_URL;
    }

    public String getApplicationId() {
        return BuildConfig.APPLICATION_ID;
    }

    public String getVariantName() {
        return BuildConfig.BUILD_TYPE;
    }

    public int getVersionCode() {
        return BuildConfig.VERSION_CODE;
    }

    public long getThrottleDownloadBy() {
        return 0L;
    }

    public String getMainActivityFullyQualifiedName() {
        return MainActivity.class.getName();
    }
}