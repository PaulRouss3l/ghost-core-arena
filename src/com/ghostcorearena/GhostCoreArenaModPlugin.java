package com.ghostcorearena;

import com.ghostcorearena.util.GCALog;
import com.fs.starfarer.api.BaseModPlugin;

/**
 * Entry point for the Ghost Core Arena mod.
 * Registered via "modPlugin" in mod_info.json.
 */
public class GhostCoreArenaModPlugin extends BaseModPlugin {

    @Override
    public void onApplicationLoad() throws Exception {
        GCALog.info("Hello world: application loaded");
    }

    @Override
    public void onGameLoad(boolean newGame) {
        GCALog.info("Hello world: game loaded (newGame=" + newGame + ")");
    }
}
