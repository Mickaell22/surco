# Vosk llama a su librería nativa por JNA: R8 no debe renombrar ni quitar nada.
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
