package org.javaone.bootstrap;

import javax.microedition.lcdui.Display;
import javax.microedition.lcdui.Displayable;

import org.recompile.mobile.Mobile;

/**
 * JavaOne-owned Display lifecycle inspection for {@code PlatformBootstrap}.
 *
 * <p>Not FreeJ2ME. Reads FreeJ2ME Display state after {@code runJar()} without
 * calling {@code setCurrent}, {@code repaint}, or touching the painter / framebuffer.
 *
 * <p>E3-US007 — verifies Display singleton + current Displayable only.
 */
public final class DisplaySupport {

    /** {@code Mobile.getDisplay()} / Display singleton is null. */
    public static final String STATUS_NO_DISPLAY = "NO_DISPLAY";

    /** Display exists but {@code getCurrent()} is null (no {@code setCurrent}). */
    public static final String STATUS_NO_CURRENT = "NO_CURRENT";

    /** Prefix for success: {@code OK:<SimpleClassName>}. */
    public static final String STATUS_OK_PREFIX = "OK:";

    private DisplaySupport() {
    }

    /**
     * Inspects FreeJ2ME Display lifecycle after a successful {@code runJar}.
     *
     * <p>JNI: {@code inspectStatus()Ljava/lang/String;}
     *
     * @return {@link #STATUS_NO_DISPLAY}, {@link #STATUS_NO_CURRENT},
     *     or {@code OK:<DisplayableSimpleName>}
     */
    public static String inspectStatus() {
        final Display resolved = resolveDisplay();
        if (resolved == null) {
            return STATUS_NO_DISPLAY;
        }
        final Displayable current = resolved.getCurrent();
        if (current == null) {
            return STATUS_NO_CURRENT;
        }
        return STATUS_OK_PREFIX + current.getClass().getSimpleName();
    }

    /** JNI: {@code hasDisplay()Z} */
    public static boolean hasDisplay() {
        return resolveDisplay() != null;
    }

    /** JNI: {@code hasCurrentDisplayable()Z} */
    public static boolean hasCurrentDisplayable() {
        final Display resolved = resolveDisplay();
        return resolved != null && resolved.getCurrent() != null;
    }

    private static Display resolveDisplay() {
        final Display fromMobile = Mobile.getDisplay();
        if (fromMobile != null) {
            return fromMobile;
        }
        return Display.getDisplay(null);
    }
}
