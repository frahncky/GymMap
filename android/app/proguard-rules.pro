# O Room acha a implementação do banco por reflexão (<Nome>_Impl). Sem estas
# regras o R8 remove WorkDatabase_Impl (WorkManager, que vem com o
# google_mobile_ads) e o app fecha na abertura do build de release.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# O shared_preferences_android é chamado do Dart via JNI (pacote jni), por
# nome e assinatura. Sem estas regras o R8 remove ou renomeia esses métodos
# e toda leitura das preferências falha no release (NoSuchMethodError) —
# inclusive o cache do estilo do mapa, que ficava cinza.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class com.github.dart_lang.jni.** { *; }
