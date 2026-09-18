# Keep RuntimeProvider implementations and their constructors for ServiceLoader
-keep class * implements expo.modules.kritha.runtime.RuntimeProvider {
    <init>();
    *;
}

-keep class com.jeppeman.globallydynamic.** { *; }

