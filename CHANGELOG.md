# Change Log

All notable changes to the project will be documented in this file.

## v2.0.2 - 2018-09-26

### Added
- sort descriptor is preserved

### Changed
- loading of poster images is animated

### Fixed
- poster cache is cleared on every new version

## v2.0.1 - 2018-09-16

### Added
- support for iOS 12

### Fixed
- long loading times when library has many movies (100+)
- unknown state when accepting share fails

## v2.0 - 2018-09-09

### Added
- support for multiple libraries
- libraries and movies are synced across devices via iCloud
- libraries can be shared
- settings bundle

### Changed
- new project structure
- new app icon
- updated icons (vector graphics)
- larger cells in table views
- library search and TMDB search use same results controller
- TMDB search is throttled
- updated details ui
- details without content are hidden
- smaller cache for popular movie posters
- faster library edits due to new data structure
- adding movies does not block screen
- all table view/collection views use prefetching
- live update for text fields which must not be empty

### Removed
- support for imports (use sharing instead)

### Fixed
- genre list can be refreshed if empty
- movie details for popular movies is cached
- posters are not displayed in some cases

## v.1.4.1 - 2018-01-05

### Added
- summary footer in Library tab

### Fixed
- activity indicator does not stop for some cells in Genre tab
- cancel button in sorting sheet is not translated

## v1.4 - 2017-12-27

### Added
- genre tab

### Changed
- dropped iOS 10 support
- rewritten with coordinator layer on top of MVC
- 'a' and 'an' articles (as prefix) are ignored in title sorting

### Fixed
- text is drawn on top of each other in empty state views
- launch screen bars misaligned on iPhone X

## v1.3.3 - 2017-12-10

### Added
- text fields allow clearing

### Fixed
- accessory view in action sheet cells is highlighted in different shade
- crash when fetching certification for non-existent movie
- table view is fully accessible when keyboard is visible

## v1.3.2 - 2017-10-11

### Changed
- sorting selection via alert sheet

## v1.3.1 - 2017-09-26

### Added
- support for iOS 11
- empty state view for search

### Changed
- written in Swift 4

### Fixed
- search bar disappears after library is modified
- scroll position is not reset when search results are updated

## v1.3 - 2017-09-04

### Added
- popular movies
- new persistent data schema
- importing new movies no longer replaces entire library
- full release data replaces release year
- tab bar
- launch screen
- empty state views

### Changed
- movies are fetched based on the user's language and region
- user data is stored in documents folder
- all images and movie responses from TMDB are cached
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
