package com.jeppeman.globallydynamic.generated;

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
        return new String[] { "feature-litert", "feature-litertlm", "feature-onnx" };
    }

    public String getServerUrl() {
        return "http://10.0.2.2:8080";
    }

    public String getApplicationId() {
        return "com.kritha.app.debug";
    }

    public String getVariantName() {
        return "debug";
    }

    public int getVersionCode() {
        return 1;
    }

    public long getThrottleDownloadBy() {
        return 0L;
    }

    public String getMainActivityFullyQualifiedName() {
        return "com.kritha.app.MainActivity";
    }
}

