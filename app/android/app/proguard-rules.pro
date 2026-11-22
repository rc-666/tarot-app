# R8 keep rules for release builds (Flutter's Gradle plugin picks up this file automatically).

# WorkManager (pulled in by google_mobile_ads) creates its Room database by reflection
# (WorkDatabase_Impl). Without these rules R8 removes the constructor and the app crashes
# at start-up: "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** extends androidx.room.RoomDatabase { *; }
