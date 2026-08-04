package org.javaone.freej2me.fixtures;

import javax.microedition.lcdui.Canvas;
import javax.microedition.lcdui.Display;
import javax.microedition.lcdui.Graphics;
import javax.microedition.midlet.MIDlet;
import javax.microedition.midlet.MIDletStateChangeException;

/**
 * MIDlet fixture that activates Display via {@code setCurrent} (E3-US007).
 *
 * <p>Does not request repaints, draw content, or touch framebuffer / audio / input.
 * Lives outside {@code Vendor/FreeJ2ME}.
 */
public final class DisplayProbeMIDlet extends MIDlet {

    private final Canvas canvas = new Canvas() {
        protected void paint(Graphics g) {
            // Intentionally empty — Display activation only.
        }
    };

    protected void startApp() throws MIDletStateChangeException {
        Display.getDisplay(this).setCurrent(canvas);
        System.out.println("START_APP_OK");
    }

    protected void pauseApp() {}

    protected void destroyApp(boolean unconditional) throws MIDletStateChangeException {}
}
