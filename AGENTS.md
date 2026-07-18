# AGENTS.md

## GitHub Release

- A pushed Git tag is not a GitHub Release.
- When a release is requested, create and push the version tag, then create the corresponding GitHub Release with `gh release create`.
- After creation, verify it with `gh release view <version>` and confirm that the release is published for the intended tag.
