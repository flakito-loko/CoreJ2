package org.javaone.freej2me.fixtures;

import javax.microedition.midlet.MIDlet;
import javax.microedition.midlet.MIDletStateChangeException;

/**
 * MIDlet that fails inside {@code startApp()} to validate typed startup failures.
 */
public final class FailingMIDlet extends MIDlet {

    protected void startApp() throws MIDletStateChangeException {
        throw new MIDletStateChangeException("intentional probe failure");
    }

    protected void pauseApp() {}

    protected void destroyApp(boolean unconditional) throws MIDletStateChangeException {}
}
