# Vendored: IRIS (Intelligent Real-time Input Suggestion)

- Source:    https://github.com/versenilvis/iris
- Version:   v0.6.4-nightly.42416f (commit 42416fc720d62e80696d839b66deffe8aa7c90d6)
- License:   0BSD (see LICENSE) — no attribution required; credit upstream when publishing.
- Vendored:  2026-08-22
- Module:    renamed to github.com/SrwR16/flow-engine (2026-08-22)
- Upstream:  intentionally severed — updater subsystem deleted; future
  development is Flow-native. No upstream merges planned.
- Note:      github.com/versenilvis/fuzzy remains as a third-party library
              dependency (fuzzy search), not an iris link.
- Removed vs upstream: .github CI, packaging/, scripts/ (upstream installers),
  Nix flake, goreleaser/cliff/hk configs. Everything else kept verbatim.
- Upstream strategy: thin patches only (providers, themes, Flow features).
  Never rewrite rendering core — cherry-pick upstream fixes instead.
- Build:     cd engine && go build -o iris ./cmd/iris   (Go >= 1.24)

Flow additions planned (in order):
1. internal/providers flow provider reading ~/.local/state/flow/predictor/aggregates.tsv
   (canonical schema=1 format — see sdata/lib/flow_predictor.sh header)
2. Directory-context ranking via cwd (IRIS_CWD already flows through integration/)
3. theme.toml generated from Matugen Material tokens
4. ./ script discovery, production-warning styling, profile-aware pools
