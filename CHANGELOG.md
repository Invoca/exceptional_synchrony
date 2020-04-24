# CHANGELOG for `exception_synchrony`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - Unreleased
### Changed
- If `EMP.run` rescues an exception, previous versions would simply log the exception and continue.
  Instead this version has an `on_error` option with possible values `:log` and `:raise`.
  It defaults to `:log` and in that case, as before, logs any rescued `StandardError` exception and continues.
  When `on_error` is set to `:raise`, the method raises a `FatalRunError` wrapper around the rescued exception.
  This `FatalRunError` exception does not derive from `StandardError`, so it will not be erroneously rescued by any
  registered `EMP.error_handler`. Instead it should be rescued at the outer edge of the process.
  We expect that outer edge handler to log the exception chain (the wrapper plus nested `cause` exception(s))
  and exit the process with a non-0 status code.

[1.2.0]: https://github.com/Invoca/exceptional_synchrony/compare/v1.1.0...v1.2.0
