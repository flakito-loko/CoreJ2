package org.javaone.freej2me.fixtures;

import javax.microedition.midlet.MIDlet;
import javax.microedition.midlet.MIDletStateChangeException;

/**
 * Minimal MIDlet used to validate FreeJ2ME {@code runJar()} → {@code startApp()}.
 *
 * <p>Does not call {@code Display.setCurrent()}, request repaints, or touch
 * framebuffer / audio / input. Lives outside {@code Vendor/FreeJ2ME}.
 */
public final class ProbeMIDlet extends MIDlet {

    protected void startApp() throws MIDletStateChangeException {
        System.out.println("START_APP_OK");
    }

    protected void pauseApp() {}

    protected void destroyApp(boolean unconditional) throws MIDletStateChangeException {}
}
