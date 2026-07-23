# <img src="./.github/assets/logo.svg" align="center" alt="transparenZ logo" width="216">

Utility that makes windows 11 taskbar transparent.

## TODO:

- Replace manual `winapi` bindings with `zigwin32` package.
  It can't be done until `zls` closes [#3208](https://github.com/zigtools/zls/issues/3208),
  because it is very hard to use any imports (like `zigwin32`) without types in IDE.
