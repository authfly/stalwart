# AGENTS.md — authfly/stalwart

- Console UI = UI8Kit 3 templ primitives via authkit `widgets/templ` (package `authfly`). Do not reintroduce xgen/kit.css.
- Composites in `apps/console/ui.templ`: className/tokens only, no new CSS beyond `apps/console/app.css` Tailwind entry.
- Icons: edit `apps/console/icon-names.txt`, then `bun tools/gen-console-icons.ts <lucide-dir>`; never hand-edit `lucide_icons.go`.
- After editing `.templ`: `templ generate -path apps/console`, `bun run console:css`, `go vet ./... && go test ./...`.
- `go build ./...` overwrites the committed `console` binary — restore with `git checkout console` before committing.
- Pins: `tools/deps.sh --bump <authkit|cli>`; e2e needs docker (`tools/e2e-compat.sh`).
- Push only when asked; never force-push or rewrite history.
