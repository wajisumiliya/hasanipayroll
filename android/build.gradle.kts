allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val flutterBuildDir =
    providers.gradleProperty("flutterBuildDir")
        .map { rootProject.file(it) }
        .orElse(rootProject.file("../../build"))
        .get()
rootProject.layout.buildDirectory.set(flutterBuildDir)

subprojects {
    project.layout.buildDirectory.set(flutterBuildDir.resolve(project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(flutterBuildDir)
}
