package com.ghostcorearena.util;

import com.fs.starfarer.api.Global;
import org.apache.log4j.Logger;

/**
 * Thin logging wrapper so all mod logs share a consistent prefix and a single
 * logger category. Use {@code GCALog.info(...)} etc. instead of calling
 * {@code Global.getLogger(...)} directly.
 */
public final class GCALog {

    private GCALog() {}

    private static final String PREFIX = "[GhostCoreArena] ";

    private static Logger log() {
        return Global.getLogger(GCALog.class);
    }

    public static void info(String msg) {
        log().info(PREFIX + msg);
    }

    public static void warn(String msg) {
        log().warn(PREFIX + msg);
    }

    public static void error(String msg, Throwable t) {
        log().error(PREFIX + msg, t);
    }
}
