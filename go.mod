module github.com/authfly/stalwart

go 1.26.0

require (
	github.com/a-h/templ v0.3.1070
	github.com/authfly/cli v0.0.0
	github.com/ui8kit/codegen/packages/templ/ui v0.0.0
)

// Pinned sibling repos checked out by tools/deps.sh (deps.lock).
replace (
	github.com/authfly/cli => ./.deps/cli
	github.com/ui8kit/codegen/packages/templ/ui => ./.deps/authkit/packages/ui/templ
)
