# Development and testing

```bash
shellcheck amezmo/amezmo commands/host/amezmo tests/*.bash
bats tests/test.bats
ddev add-on get "$PWD"
```

The Bats suite mocks network and database tools and does not require an Amezmo account. CI validates YAML, ShellCheck, Bats, and local add-on installation when Docker is available.
