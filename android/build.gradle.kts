buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Force AGP to the version already cached by Flutter's own tooling.
        // This overrides the AGP 7.4.2 that google_mlkit_commons tries to pull.
        classpath("com.android.tools.build:gradle:8.11.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Offline resolution strategy removed because internet is available.
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
