# O Room acha a implementação do banco por reflexão (<Nome>_Impl). Sem estas
# regras o R8 remove WorkDatabase_Impl (WorkManager, que vem com o
# google_mobile_ads) e o app fecha na abertura do build de release.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
