# CHANGELOG for `exception_synchrony`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

All notable changes to this project will be documented in this file.

## [1.4.1] - 2021-03-09
### Fixed
- FaradayAdapterPatch_v1 name typo

## [1.4.0] - 2021-03-08
### Added
- Added use of Thread local variable to indicate when Eventmachine is running using EM::Synchrony
- Added faraday gem monkey patch to use the new Thread local variable to choose the adapter to use

## [1.3.0] - 2021-02-04
### Added
- Extend `EMP.defer` to have a new keyword argument, `wait_for_result` for the callers to control whether they should should block until the background thread returns. To preserve existing behavior, this option defaults to `true`, so `EMP.defer` will block in order to return the value (or raise an exception) from the deferred block. Callers can pass `wait_for_result: false` if they do not want to block.

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

## [1.1.1] - 2020-05-03
- Replace hobo_support with invoca_utils

[1.4.1]: https://github.com/Invoca/exceptional_synchrony/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/Invoca/exceptional_synchrony/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Invoca/exceptional_synchrony/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Invoca/exceptional_synchrony/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/Invoca/exceptional_synchrony/compare/v1.1.0...v1.1.1
