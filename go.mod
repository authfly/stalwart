module github.com/authfly/stalwart

go 1.27.3

require (
	github.com/a-h/templ v0.3.1070
	github.com/authfly/authkit/packages/ui/templ v0.0.0
	github.com/authfly/cli v0.0.0
)

require golang.org/x/sys v0.49.0 // indirect

// Pinned sibling repos checked out by tools/deps.sh (deps.lock).
replace (
	github.com/authfly/authkit/packages/ui/templ => ./.deps/authkit/packages/ui/templ
	github.com/authfly/cli => ./.deps/cli
)
