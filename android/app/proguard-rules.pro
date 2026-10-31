# LiteRT-LM resolves these classes by name from native code, so R8 cannot see
# the references and would strip them from release builds.
-keep class org.rockstudio.litertlm.** { *; }
-keep class com.google.ai.edge.litertlm.** { *; }
