NFSU2 Phase 2.7 - Host pthread + NFSU2 memory smoke test

1. Extract this ZIP on Windows.
2. Upload main.m, mem.c, cpu.h, Info.plist to the root of your GitHub NFSU2-2 repository (replace existing versions).
3. Replace .github/workflows/ios-smoke.yml with the workflow in this ZIP. Do not upload ios-smoke.yml to repository root.
4. GitHub Actions -> NFSU2 iOS Phase 2.7 Thread Smoke -> Run workflow.
5. Download artifact, extract unsigned IPA, sign it, install with Feather, open app and send screenshot.

This uses the real NFSU2Recomp mem.c and cpu.h but a separate HOST pthread synchronization test. It does NOT yet execute NFSU2 guest code or use win32_ext.c. It is not the game.

The bundle ID is com.nfsu2.port.phase27 to avoid replacing the previous test app.
