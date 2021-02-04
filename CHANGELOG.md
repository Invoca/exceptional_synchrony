# CHANGELOG for `exception_synchrony`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

All notable changes to this project will be documented in this file.

## [1.3.0] - UNRELEASED
### Added
- For users of `Faraday` connections, its `default_adapter` is configured to `:em_synchrony` when starting
  the `EventMachine` reactor so that the reactor does not get blocked when using `Faraday`

## [1.1.1] - 2020-05-03
- Replace hobo_support with invoca_utils

[1.1.1]: https://github.com/Invoca/exceptional_synchrony/compare/v1.1.0...v1.1.1

## [1.2.0] - 2020-06-02
### Changed
- If `EMP.run` rescues an exception, previous versions would simply log the exception and continue.
  Instead this version has an `on_error` option with possible values `:log` and `:raise`.
  It defaults to `:log` and in that case, as before, logs any rescued `StandardError` exception and continues.
  When `on_error` is set to `:raise`, the method raises a `FatalRunError` wrapper around the rescued exception.
  This `FatalRunError` exception does not derive from `StandardError`, so it will not be erroneously rescued by any
  registered `EMP.error_handler`. Instead it should be rescued at the outer edge of the process.
  We expect that outer edge handler to log the exception chain (the wrapper plus nested `cause` exception(s))
  and exit the process with a non-0 status code.

[1.2.0]: https://github.com/Invoca/exceptional_synchrony/compare/v1.1.1...v1.2.0
