# Moonshine Voice SDK (ai.moonshine:moonshine-voice) bundles native libraries and
# classes that are loaded reflectively. Keep everything so R8 cannot strip them.
-keep class ai.moonshine.voice.** { *; }
-keepclassmembers class ai.moonshine.voice.** { *; }