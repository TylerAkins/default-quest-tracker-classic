# Development

Default Quest Tracker Classic is a World of Warcraft Classic Era addon. Players should read [README.md](../README.md). This guide covers local builds and releases.

## Local builds

Build a clean, directly installable addon folder with:

```bash
python3 tools/compile_addon.py
```

Each run deletes only `.compiled/DefaultQuestTrackerClassic` and recreates it from the files shipped by the addon. The generated TOC uses the current `git describe --tags --always --dirty` value as its version.

Drag `.compiled/DefaultQuestTrackerClassic` into WoW’s `_classic_era_/Interface/AddOns/` directory. The final path should end with `_classic_era_/Interface/AddOns/DefaultQuestTrackerClassic/DefaultQuestTrackerClassic.toc`. Restart WoW or use `/reload` after replacing an installed copy.

Use `python3 tools/compile_addon.py --dry-run` to list the output files without changing `.compiled/`.

## Tests

Run every Python test from the repository root:

```bash
for test_file in tests/test_*.py; do
  PYTHONPATH=. python3 "$test_file"
done
```

CI also verifies packaging metadata and performs a dry-run package with [BigWigsMods/packager](https://github.com/BigWigsMods/packager).

## Releases

| Channel | Trigger | Result |
|---------|---------|--------|
| Stable | Push an annotated `vX.Y.Z` tag | Numbered GitHub Release and CurseForge package |
| Preview | Merge to `main` or manually run the Release workflow on `main` | Commit-specific GitHub Actions artifact |
| Compatibility | Merge the generated `classic-era-build-update` PR | Annotated patch tag, stable GitHub Release, and CurseForge package |

Preview builds are for testing. They never create or move a tag. Do not point players at GitHub’s automatic source archives; use the packaged Release asset.

For a normal release:

1. Update `VERSION` and `CHANGELOG.md` in a release PR.
2. Merge the reviewed PR into `main`.
3. Create and push an annotated tag matching `VERSION` exactly:

   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

The Release workflow rejects non-semantic, lightweight, or mismatched tags. Retrying it does not duplicate an existing GitHub Release.

## Classic Era compatibility updates

The **Update Classic Era compatibility** workflow runs every Monday at 06:00 UTC and can also be run manually on `main`. It reads Blizzard’s public `wow_classic_era` version feed.

Build-number-only changes are ignored. When Blizzard publishes a new TOC interface, the workflow replaces the TOC interface with the latest value, increments the addon patch version, adds a dated changelog entry, and creates or refreshes the `classic-era-build-update` PR.

Review this PR like any other release change. Merging this exact automation branch is the only `main` merge that automatically creates an annotated tag and stable release. The automation will not move a tag: a conflicting existing tag fails the run, while retrying a same-commit tag is safe.

GitHub must allow Actions to create pull requests under **Settings → Actions → General → Workflow permissions**.

## CurseForge

CurseForge uses native Automatic Packaging. GitHub Actions does not upload to CurseForge, and this repository does not need a CurseForge token or repository secret.

Configure the CurseForge project dashboard and GitHub repository as follows:

1. Keep the GitHub repository public and set it as the project’s source repository.
2. Set **Automatic Packaging** to **package new tagged commits**, not every commit.
3. Add the CurseForge-provided packaging webhook in the GitHub repository’s webhook settings.
4. Subscribe that webhook to the **push event only** and confirm its initial delivery succeeds.

The native packager reads `.pkgmeta` and replaces `@project-version@` with the pushed tag. If CurseForge generates a credentialized webhook URL, keep it only in GitHub’s webhook configuration. No CurseForge API credential belongs in the repository or GitHub Actions secrets.
