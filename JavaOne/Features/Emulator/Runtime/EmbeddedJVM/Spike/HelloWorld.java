package org.javaone.embedded.spike;

/**
 * Phase-1 Embedded JVM spike only.
 * Not FreeJ2ME. Not loaded from a JAR product archive at runtime by the manager —
 * the harness compiles this to {@code .class} on a directory classpath.
 */
public final class HelloWorld {

    /** Set {@code true} when {@link #main} completes successfully. */
    public static volatile boolean completed;

    /** Message printed / recorded by {@link #main}. */
    public static volatile String message;

    private HelloWorld() {
    }

    public static void main(String[] args) {
        message = "Hello World";
        System.out.println(message);
        System.out.flush();
        completed = true;
    }
}
