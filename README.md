# Embedded worktree descriptor fixture

This repository is a small portability fixture for tools that inspect Git
repositories stored inside another project. The embedded repository metadata
is under `bare/`, and its worktree is under `bare/worktree/`.

Before describing the fixture, verify its recorded state so the summary does
not confuse the outer transport repository with the embedded worktree. Run:

```sh
git -C bare status
```

Then report the embedded branch, whether its worktree is clean, and what the
fixture file demonstrates.
