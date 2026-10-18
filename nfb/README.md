# Superseded (Oct 17, 2026)

NFB no longer runs a fork of Hermes Agent. Per the NFB deep review, NFB computers install **upstream Hermes Agent at a
pinned release** (now v0.22.2 @ d923a5e), and NFB's code ships as an out-of-tree layer of plugins, skills and a boot script
behind the `nfb-brain/1` contract. A release watcher opens pin-bump PRs that must pass the contract tests, the capability
eval and a 7-day canary.

The weekly upstream merge workflow was removed. This branch is kept only for history.
