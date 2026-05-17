val newBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val subprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(subprojectBuildDir)
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
