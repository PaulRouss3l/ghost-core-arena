# Research: can mod code make HTTP calls to our server in 0.98a?

Ticket: #3. Researched 2026-11-11 against Starsector **0.98a-RC8** (local install, Linux, bundled
Zulu JRE 17.0.10).

## Answer (TL;DR)

**Yes.** The game's script classloader does **not** block `java.net`, `java.net.http`,
`javax.net.ssl`, sockets, `java.lang.Thread` or `java.util.concurrent`. It blocks most of
`java.io` (file access), `java.nio.file.File*`, `java.lang.reflect`, `javax.script` and
`java.util.prefs`. That blocklist **does** apply to classes in our jar. Two widely installed mods
(LunaLib, Nexerelin) already make HTTPS calls from mod jars on background threads. Use
`java.net.http.HttpClient.sendAsync` and hand results back to the game thread through an
`EveryFrameScript` queue. A sketch that does this was compiled and then **run through the game's
real filtering classloader on the bundled JRE**, and it returned HTTP 200 (see §6).

Two caveats matter more than the technical ones:

1. **Nexus Mods prohibits internet-connected mods by default.** Distributing there needs a staff
   exception and our source code (§5).
2. **LunaLib changes a JVM-global HTTPS setting** that caps `HttpsURLConnection` at TLS 1.2. Use
   `HttpClient` with explicit `SSLParameters`, or make sure the server accepts TLS 1.2 (§4).

## 1. The classloader blocklist (primary evidence: game bytecode)

Source: `starfarer_obf.jar`, class `com.fs.starfarer.loading.scripts.new` (a `ClassLoader`),
method `loadClass(String, boolean)`. I disassembled it with `javap -c -p`. Its logic, in order:

| Class name | Result |
|---|---|
| starts with `java.io` or `java.nio.file.File`, **unless** it is exactly one of `java.io.{BufferedInputStream, BufferedReader, FilterInputStream, InputStreamReader, Reader, Serializable, InvalidClassException, ObjectStreamException, InputStream, IOException, PrintStream, PrintWriter, ByteArrayInputStream, FilterOutputStream, OutputStream, Closeable, Flushable, StringReader, FileReader}`, `java.nio.{ByteBuffer, CharBuffer, IntBuffer}`, `java.lang.Class` | `SecurityException("File access and reflection are not allowed to scripts.")` |
| starts with `javax.script` | `SecurityException("javax.script access not allowed to scripts.")` |
| starts with `java.util.prefs` | `SecurityException("java preferences access not allowed to scripts.")` |
| starts with `java.lang.reflect`, except `AnnotatedElement`, `InvocationTargetException`, `Type`, `GenericDeclaration` | `SecurityException("File access and reflection are not allowed to scripts. (<name>)")` |
| equals `sun.reflect.misc.MethodUtil` | same SecurityException |
| anything else | delegated to the parent loader, so it is **allowed** |

`java.net.*`, `java.net.http.*`, `javax.net.ssl.*`, `java.lang.Thread`, `java.util.concurrent.*`,
`java.time.*` and `java.lang.invoke.*` (lambdas) are **not** in the list.

**Does it apply to jar mods, not only loose `.java` scripts?** Yes. In `ScriptStore` /
`ScriptStore$3`, the game builds the jar loader as
`new URLClassLoader(modJarUrls, ScriptStore.<filter instance of 'new'>)`. Because the filter is
the parent, every `java.*` reference from our jar resolves through the filter's `loadClass`
(normal parent-first delegation). §6 confirms this experimentally.

Consequences for our code:

- `java.io.ByteArrayOutputStream`, `Writer`, `OutputStreamWriter`, `StringWriter`,
  `UncheckedIOException`, `EOFException` and `File` are **blocked**. Do not name them in mod
  bytecode. Even a `catch (UncheckedIOException e)` is enough to trigger it. Use
  `HttpResponse.BodyHandlers.ofString()` and `BodyPublishers.ofString()`, or
  `InputStream.readAllBytes()` (allowed), instead.
- `IOException`, `InputStream`, `OutputStream`, `BufferedReader` and `InputStreamReader` are
  allowed, so the classic `HttpURLConnection` style also works.
- The check is **by name, on classes our bytecode references**. JDK-internal use of `java.io` (for
  example inside `HttpClient`) is not affected.
- For persistence, use the game's own I/O instead of `java.io.File`:
  `Global.getSettings().writeTextFileToCommon` / `readTextFileFromCommon`.

Forum confirmation from Alex (the developer) could not be fetched: `fractalsoftworks.com/forum`
returns HTTP 402 to automated clients. The bytecode is the authoritative source either way.

## 2. How existing mods do HTTP (primary evidence: installed mod source and the game log)

**LunaLib 2.0.5** includes a fork of LazyWizard's Version Checker, source at
`mods/LunaLib-2.0.5/src/lunalib/backend/ui/versionchecker/`:

- `VersionChecker.getRemoteVersionFile`: `new URL(versionFileURL).openStream()`, read with
  `java.util.Scanner`. It catches `IOException`, `JSONException` and `Throwable`, and treats any
  failure as "unknown", never as a crash.
- `VersionChecker.scheduleUpdateCheck`: it wraps the work in a `FutureTask` on
  `new Thread(task, "Thread-VC-Main")`. That thread fans out to
  `Executors.newFixedThreadPool(n, VCThreadFactory)` (threads `Thread-VC-1..n`). The UI
  (`LunaVersionUIPanel.kt`) holds the `Future<UpdateInfo>` and reads it later on the game thread.
- `UpdateInfo` also calls the GitHub API (`https://api.github.com/repos/...`) through
  `URL.openStream()`, and imports `javax.net.ssl.HttpsURLConnection`.
- `VCModPlugin.onApplicationLoad` disables URL caching globally and **sets
  `System.setProperty("https.protocols", "SSLv3,TLSv1,TLSv1.1,TLSv1.2")`** (see §4).
- Local `file:` URLs are refused unless devMode is on.

**Nexerelin 0.12.2c** ships its own copy (`exerelin/utilities/versionchecker/*` in
`ExerelinCore.jar`) that uses the same `URL` / `URLConnection` pattern.

**Runtime proof from this install** (`starsector.log`): lines such as
`[Thread-VC-6] INFO lunalib...VersionChecker - Loading version info from remote URL https://raw.githubusercontent.com/...`
followed by `[Thread-VC-Main] ... Checked game and 19 mods in 1.926 seconds`. These are HTTPS GETs
to GitHub, Bitbucket and GitLab from mod jars on worker threads, completing in about 2 s. The log
contains no `SecurityException`.

No installed mod POSTs data to a server. Version checking (GET only, to static files) is the only
networking precedent in this mod set.

## 3. Threading: never block the game loop

- Game logic is single-threaded. The wiki says "The game logic is single-threaded, so you'll never
  need to worry about concurrency issues unless you create them yourself"
  ([Miscellaneous modding tidbits](https://starsector.wiki.gg/wiki/Miscellaneous_modding_tidbits)).
  The corollary is that **no game API call (`Global.*`, fleets, memory, UI) may run on an HTTP
  thread**.
- Pattern: `HttpClient.sendAsync` returns a `CompletableFuture`. Its continuation runs on the
  client's daemon worker threads, where we only parse JSON into plain POJOs. We then post a
  `Runnable` to a `ConcurrentLinkedQueue` that a transient `EveryFrameScript` (`runWhilePaused()`
  returns true) drains on the game thread (`SectorAPI.addTransientScript`, verified in the API).
  For combat or the title screen, drain the same queue from an `EveryFrameCombatPlugin`, or poll
  the `Future` from UI code, as LunaLib does.
- Use a `connectTimeout` (5 s) and a per-request `timeout` (15 s). Never call `.get()` / `.join()`
  on the game thread. Treat every failure as "offline mode" and keep going.
- Never put the client, futures or queue into saved state (XStream). Keep them in static, transient
  holders that contain **no game objects** (consistent with our CLAUDE.md constraint).

## 4. TLS and certificates with the bundled JRE 17

Bundled runtime (`jre_linux/release`): **Azul Zulu 17.0.10 (2024-01-16)**. Its modules include
`java.net.http`, `jdk.crypto.ec` and `jdk.crypto.cryptoki`, so `HttpClient` and ECDSA certs work.

- **Trust store**: `keytool -list -cacerts` shows 161 roots, including `letsencryptisrgx1` and
  `letsencryptisrgx2`, the GTS roots, USERTrust RSA/ECC (Sectigo) and DigiCert. **A Let's Encrypt
  certificate on our VPS works without any custom trust setup.** Never ship a "trust all"
  `TrustManager`.
- **Disabled protocols** (`conf/security/java.security`):
  `jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1, RC4, DES, MD5withRSA, DH keySize < 1024, EC keySize < 224, 3DES_EDE_CBC, anon, NULL`.
  Only TLS 1.2 and 1.3 are possible.
- **LunaLib side effect (verified)**: once LunaLib's `onApplicationLoad` sets
  `https.protocols=SSLv3,TLSv1,TLSv1.1,TLSv1.2`, every `HttpsURLConnection` in the JVM negotiates
  **TLS 1.2 only**. Measured on the bundled JRE against `api.github.com`: before setting it,
  `TLS_AES_128_GCM_SHA256` (TLS 1.3); after, `TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256` (TLS 1.2).
  `HttpClient` with explicit `SSLParameters` is not affected. Either way: **configure the server to
  accept TLS 1.2 and 1.3** (default for Caddy and nginx) and use ECDHE AES-GCM suites.
- Root-store age: this JRE is from January 2024. Any future CA change on our side should be checked
  with `keytool -list -cacerts` against the bundled JRE. Players on Windows or macOS, or those who
  swap in a newer JRE (a common community performance tweak), will have a different but newer
  store. **Not verified here**: the Windows and macOS bundled JREs, since only the Linux install
  is available.

## 5. Norms and rules for mods that phone home

- **Nexus Mods File Submission Guidelines** (primary,
  [help.nexusmods.com/article/28](https://help.nexusmods.com/article/28-file-submission-guidelines)):
  files that "connect to the internet to download or send information and/or files are prohibited"
  unless "crucial for the functioning of the mod/utility". "Auto update" functionality does not
  count, and Nexus "reserve[s] the right to moderate and/or remove any files/tools/utilities/mods
  that communicate with the internet". If functionality depends on sending and receiving data,
  "please contact staff", by emailing support with the source code. Files that require registration
  or submission of user information may do so only "to facilitate the functions associated with
  the mod and must be clearly presented as such to the user". **Implication: an async-PvP mod is
  arguably "crucial" networking, but it needs prior contact with Nexus staff and public source.**
- **Fractal Softworks forum**: not verifiable here (automated fetches get HTTP 402). Second-hand
  reports summarise the forum's mod rules as "no malware, no porn, no racist/discriminatory content".
  I found no first-party rule on networking. **Open item: a human should read the forum's modding
  rules thread and ask on the forum or Discord before release.**
- **Community precedent**: Version Checker is the only widely accepted networking, and it is
  GET-only to author-hosted static files, sending no player data. Nothing comparable to uploading
  player data was found.
- **What this means for our design** (recommendations, not sourced rules):
  - **Opt-in, off by default.** The first time the feature is used, show a clear dialog saying what
    is sent (fleet snapshot: hulls, variants, officers, the player-chosen display name) and where
    (our domain). Persist the choice in a LunaLib setting or common-file setting (`gca_` prefix).
    Provide an obvious "offline mode" that still plays.
  - Send **no** machine identifiers, file paths, mod lists beyond what is needed, or logs. Use a
    random per-install token (from `java.util.UUID`) stored with `writeTextFileToCommon`, not
    hardware or Steam IDs.
  - Our server sees player IP addresses, which are personal data under the GDPR. Publish a short
    privacy note (what we store, for how long, how to delete) and keep server logs short-lived.
  - Open-source the client code (the repo is already public) and link it from the mod page. This
    is also what Nexus staff will ask for.
  - Only HTTPS to a hard-coded host, with no user-configurable URLs, except in devMode for a local
    server, mirroring LunaLib's `file:` guard.

## 6. Verified code sketch

Two classes (Java 17, no Kotlin, no blocked `java.io` names), saved below. Verification performed:

1. `javac --release 17 -Xlint:all -cp starfarer.api.jar:log4j-1.2.9.jar` compiled both classes
   cleanly, with no warnings.
2. **Filter run (without launching the game)**: a harness created the game's real filter loader
   (`com.fs.starfarer.loading.scripts.new`, from `starfarer_obf.jar`) and set it as the parent of a
   `URLClassLoader` over our compiled classes, exactly as `ScriptStore$3` does. It ran on the
   bundled `jre_linux/bin/java` with the launcher's `-noverify` flags. Probe results:
   - `new Thread(...)` → `ran on gca-probe` (threads allowed)
   - `new java.io.ByteArrayOutputStream()` → `SecurityException: File access and reflection are not allowed to scripts.` (negative control: the filter is active)
   - `GCAHttp.getJson("https://api.github.com/zen").get()` → `status=200` (HTTPS works through the filter)

```java
package com.ghostcorearena.net;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;
import javax.net.ssl.SSLParameters;

/** Non-blocking HTTPS client. Never touches the game API; hand results to GCAMainThread.post. */
public final class GCAHttp {
    private GCAHttp() {}

    /** One shared client; its internal threads are daemon threads, so they never block game exit. */
    private static final HttpClient CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            // Explicit protocols: do not depend on the global https.protocols set by LunaLib.
            .sslParameters(new SSLParameters(null, new String[] {"TLSv1.3", "TLSv1.2"}))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();

    /** Immutable result; status -1 means a transport error (message in body). */
    public static final class Result {
        public final int status;
        public final String body;
        Result(int status, String body) { this.status = status; this.body = body; }
        public boolean ok() { return status >= 200 && status < 300; }
    }

    public static CompletableFuture<Result> getJson(String url) {
        return send(base(url).GET().build());
    }

    public static CompletableFuture<Result> postJson(String url, String json) {
        return send(base(url)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build());
    }

    private static HttpRequest.Builder base(String url) {
        return HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(15))
                .header("Accept", "application/json")
                .header("User-Agent", "GhostCoreArena/0.1");
    }

    private static CompletableFuture<Result> send(HttpRequest req) {
        return CLIENT.sendAsync(req, HttpResponse.BodyHandlers.ofString())
                .handle((resp, err) -> err != null
                        ? new Result(-1, String.valueOf(err))
                        : new Result(resp.statusCode(), resp.body()));
    }
}
```

```java
package com.ghostcorearena.net;

import com.fs.starfarer.api.EveryFrameScript;
import com.fs.starfarer.api.Global;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Hands work from HTTP threads to the game thread. In onGameLoad:
 * Global.getSector().addTransientScript(new GCAMainThread());
 * Usage: GCAHttp.getJson(url).thenAccept(r -> GCAMainThread.post(() -> use(r)));
 */
public final class GCAMainThread implements EveryFrameScript {
    private static final Queue<Runnable> QUEUE = new ConcurrentLinkedQueue<>();

    /** Thread-safe; callable from any thread. */
    public static void post(Runnable r) { QUEUE.add(r); }

    @Override public boolean isDone() { return false; }
    @Override public boolean runWhilePaused() { return true; }

    @Override
    public void advance(float amount) {
        Runnable r;
        int budget = 16; // bounded work per frame
        while (budget-- > 0 && (r = QUEUE.poll()) != null) {
            try {
                r.run();
            } catch (RuntimeException e) {
                Global.getLogger(GCAMainThread.class).error("[GhostCoreArena] main-thread task failed", e);
            }
        }
    }
}
```

Notes:

- JSON: use the game's bundled `org.json` (`json.jar`, already used by LunaLib) to build and parse
  bodies on the worker thread. It is not blocked.
- Gzip: `HttpClient` does not decompress automatically. If snapshots get large, gzip them with
  `java.util.zip.GZIPOutputStream` (allowed) wrapped around an allowed `OutputStream`, and avoid
  `ByteArrayOutputStream`. Or simply keep payloads small: a fleet snapshot is a few KB of JSON.
- The queue drains only while a campaign is loaded. Requests fired from the title screen or combat
  need another drain point (§3).
- Not verified: behaviour in a full game session (this ticket said not to launch the game). The
  first in-game test should check `starsector.log` for `SecurityException` and confirm no frame
  hitches.

## Sources

- Game bytecode: `/home/ubik/Downloads/starsector/starfarer_obf.jar` →
  `com/fs/starfarer/loading/scripts/new.class`, `ScriptStore.class`, `ScriptStore$3.class`,
  `com/fs/starfarer/settings/StarfarerSettings.class` (`javap -c -p`).
- Bundled JRE: `jre_linux/release`, `jre_linux/conf/security/java.security`,
  `keytool -list -cacerts`, `java --list-modules`.
- LunaLib 2.0.5 source: `mods/LunaLib-2.0.5/src/lunalib/backend/ui/versionchecker/{VersionChecker,VCModPlugin,UpdateInfo}.java`, `LunaVersionUIPanel.kt`.
- Nexerelin 0.12.2c: `jars/ExerelinCore.jar` → `exerelin/utilities/versionchecker/`.
- `starsector.log` (Version Checker lines on `Thread-VC-*`).
- Nexus Mods File Submission Guidelines: https://help.nexusmods.com/article/28-file-submission-guidelines
- Starsector wiki, Miscellaneous modding tidbits: https://starsector.wiki.gg/wiki/Miscellaneous_modding_tidbits
- Unreachable: Fractal Softworks forum (HTTP 402 to automated fetches). Forum rules and any
  developer statements need a manual check.
