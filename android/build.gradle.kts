allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

fun Project.fallbackAndroidNamespace(): String {
    val validNamespacePattern =
        Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$")
    val groupNamespace = group.toString()
    if (validNamespacePattern.matches(groupNamespace)) {
        return groupNamespace
    }

    val safeModuleName = name.replace(Regex("[^A-Za-z0-9_]"), "_")
    return "dev.flutter.$safeModuleName"
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

subprojects {
    pluginManager.withPlugin("com.android.library") {
        try {
            val androidExtension = extensions.findByName("android") ?: return@withPlugin
            val getNamespace = androidExtension.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            } ?: return@withPlugin
            val setNamespace = androidExtension.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            } ?: return@withPlugin

            val namespace = getNamespace.invoke(androidExtension) as? String
            if (namespace.isNullOrBlank()) {
                setNamespace.invoke(androidExtension, fallbackAndroidNamespace())
            }
        } catch (_: Exception) {
            // Ignore non-Android projects or extensions that do not support namespace.
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
