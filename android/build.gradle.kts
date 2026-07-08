allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Force every Android library subproject to compile against the same
// compileSdk as the app (36+). Some plugins ship with compileSdk = 34
// while their transitive deps require ≥ 36 → `CheckAarMetadata` aborts.
//
// The afterEvaluate callback MUST be registered in the SAME subprojects
// block that sets the build directory, and BEFORE the
// `evaluationDependsOn(":app")` block below. Otherwise Gradle throws
// "Cannot run Project.afterEvaluate(Action) when the project is already
// evaluated" (see .cursor/rules/gray_part_pitfalls.md §7).
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
