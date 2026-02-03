# AsyncClosureLinter

A Swift lint tool that ensures async closure properties in SwiftUI Views have `@MainActor` attribute.

## Why?

When using Swift 6 with **Default Actor Isolation** set to `nonisolated` (in Build Settings), async closures in SwiftUI Views without `@MainActor` will **crash on iOS 17** at runtime.

This happens because:
1. SwiftUI Views run on the main thread
2. With `nonisolated` default, async closures are not bound to any actor
3. iOS 17 lacks some runtime fixes present in iOS 18+, causing crashes when these closures are invoked

```swift
// Bad - crashes on iOS 17 when Default Isolation is nonisolated
struct MyView: View {
    var onTap: () async -> Void
}

// Good - explicitly marked as MainActor, works on all iOS versions
struct MyView: View {
    var onTap: @MainActor () async -> Void
}
```

This tool helps you catch these issues at build time before they crash in production.

## Installation

### Download Binary

Download from [Releases](https://github.com/user/async-closure-lint/releases):

```bash
curl -L https://github.com/user/async-closure-lint/releases/latest/download/async-closure-lint-macos.tar.gz | tar xz
sudo mv async-closure-lint /usr/local/bin/
```

### Build from Source

```bash
git clone https://github.com/user/async-closure-lint.git
cd async-closure-lint
make install
```

## Usage

```bash
# Lint single file
async-closure-lint path/to/file.swift

# Lint directory (recursive)
async-closure-lint path/to/project/

# Lint multiple paths
async-closure-lint Sources/ Tests/
```

### Exit Codes

- `0` - No violations found
- `1` - Violations found

### Xcode Integration

Add a Run Script Build Phase:

```bash
if which async-closure-lint > /dev/null; then
  async-closure-lint "${SRCROOT}/Sources"
else
  echo "warning: async-closure-lint not installed"
fi
```

### CI Integration

```yaml
# GitHub Actions
- name: Lint
  run: async-closure-lint Sources/ || exit 1
```

## What It Detects

| Pattern | Result |
|---------|--------|
| `var onTap: () async -> Void` | Warning |
| `var onTap: (() async -> Void)?` | Warning |
| `var onTap: (() async -> Void)!` | Warning |
| `var onTap: () async throws -> Void` | Warning |
| `var onTap: @MainActor () async -> Void` | OK |
| `var onTap: (@MainActor () async -> Void)?` | OK |
| `var onTap: () -> Void` | OK (not async) |
| Non-View structs | Ignored |

## Development

```bash
# Run tests
make test

# Build debug
make build

# Build release
make build-release

# Build universal binary (arm64 + x86_64)
make build-universal
```

## License

MIT
