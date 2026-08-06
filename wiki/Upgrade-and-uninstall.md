# Upgrade and uninstall

Upgrade with:

```bash
ddev add-on get sdubois/ddev-amezmo
```

Files retaining `#ddev-generated` are updated. Customized files whose marker was removed are preserved; review and merge provider changes manually.

Remove with:

```bash
ddev add-on remove amezmo
```

DDEV removes generated files. Customized or additional profile/provider files may need manual removal. Remove obsolete `AMEZMO_*_DB_PASSWORD` entries from older profile formats.
