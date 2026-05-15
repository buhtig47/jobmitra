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

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    // Force every Android-library subproject to use the same compileSdk as :app.
    // Without this, plugins like `printing` compile against their own (older)
    // declared compileSdk and fail to link androidx.core 1.17.0 resources.
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt is com.android.build.gradle.LibraryExtension) {
            androidExt.compileSdk = 36
        } else if (androidExt is com.android.build.gradle.BaseExtension) {
            androidExt.compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
