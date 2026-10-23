module github.com/authfly/stalwart

go 1.26.0

require (
	github.com/a-h/templ v0.3.1070
	github.com/authfly/authkit/widgets/templ v0.0.0
	github.com/authfly/cli v0.0.0
)

// Pinned sibling repos checked out by tools/deps.sh (deps.lock).
replace (
	github.com/authfly/authkit/widgets/templ => ./.deps/authkit/packages/ui/templ
	github.com/authfly/cli => ./.deps/cli
)
