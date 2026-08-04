package org.javaone.bootstrap;

import org.recompile.mobile.MobilePlatform;

/**
 * JavaOne-owned helpers for {@code MobilePlatform.loadJar} verification.
 *
 * <p>Not FreeJ2ME. Used by PlatformBootstrap after {@code loadJar(String)} returns
 * {@code true} to confirm a {@code MIDletLoader} exists and the JAR manifest
 * yielded a non-empty {@code MIDlet-1} display name — same contract as the
 * Process {@code MobilePlatformBootstrap} load-jar path.
 *
 * <p>E3-US005 — no {@code runJar}, no MIDlet start, no rendering.
 */
public final class JarLoadSupport {

    private JarLoadSupport() {
    }

    /**
     * Returns the MIDlet display name from {@code platform.loader.name}, or {@code null}
     * if the loader is missing or the name is blank.
     *
     * <p>JNI: {@code midletNameAfterLoad(Lorg/recompile/mobile/MobilePlatform;)Ljava/lang/String;}
     */
    public static String midletNameAfterLoad(MobilePlatform platform) {
        if (platform == null || platform.loader == null) {
            return null;
        }
        String name = platform.loader.name;
        if (name == null) {
            return null;
        }
        name = name.trim();
        return name.isEmpty() ? null : name;
    }
}
