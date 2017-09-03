# Change Log

All notable changes to the project will be documented in this file.

## unreleased

### Added
- popular movies
- new persistent data schema
- importing new movies no longer replaces entire library
- full release data replaces release year
- tab bar
- launch screen
- empty state views

### Changed
- user data is stored in documents folder
- genres are stored by id instead of name
- runtime and release date are optional
- updated icons

### Fixed
- crash, when tapping on a movie while searching with empty search bar
- invalid property values are accepted
- movie list stays scrolled down when sorting changed
- posters with different aspect ratio are displayed incorrectly
- fast typing while searching leads to unexpected results

## v1.2 - 2017-08-04

### Added
- already added movies are marked when adding new ones
- support for identifying future model versions

### Fixed
- replacing library with invalid data leads to empty library
- missing translations

## v1.1 - 2017-07-08

### Added
- identify movies easily via its poster
- edit title and subtitle of movies in library
- remove movies from library

### Changed
- border for posters
- scrolling details, not just overview
- more precise error messages

### Fixed
- [`#9`][] better displaying of long titles

[`#9`]: https://github.com/bauer-martin/cinema-ios/issues/9

## v1.0.1 - 2017-06-27

### Changed
- articles in title are not taken into account for sorting
- small UI improvements

### Fixed
- [`#1`][] Incorrect runtime sorting

[`#1`]: https://github.com/bauer-martin/cinema-ios/issues/1


## v1.0 - 2017-06-23

Initital release.
