# Release notes

One file per release: `docs/release-notes/<version>.md`. The release workflow
(`.github/workflows/release.yml`) reads the file matching the pushed tag and uses
it as the GitHub Release body, so the notes are reviewed in the same commit as
the code they describe — never typed into the web UI after the fact.

Write them for the person deciding whether to install the build:

- lead with what changed **for the user**, not which files moved;
- call out breaking changes, behavior changes, and anything they must
  reconfigure by hand;
- keep the install/verify boilerplate out — the workflow appends it.
