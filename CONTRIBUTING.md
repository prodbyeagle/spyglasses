# Contributing

## Setup

Clone the repository, then run:

```bash
swift build
```

## Local Checks

```bash
swift build
swift test
./script/build_install.sh
```

## Pull Requests

- Keep changes focused.
- Include a short description of the user-visible change.
- Mention any macOS or Speedtest CLI assumptions.
- Do not commit generated output from `.build/`, `.swiftpm/`, or `dist/`.
