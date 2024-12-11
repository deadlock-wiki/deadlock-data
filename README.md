# deadlock-data

Collection of current and historical Deadlock data and stats.

Also includes code for visualizations of the data.

All data is pulled from https://github.com/deadlock-wiki/deadbot

## Organization

Folder Hierarchy:

* `/data` : 
  * `/current` : current, up-to-date data
    * ...
  * `/archive` : all data, including current
    * `/<SourceRevision>_<VersionDate>`
      * ...

## Updating

The commands to update and sync the data are contained in `Taskfile.yml`.

To run, install `go-task`: https://taskfile.dev/

To customize/spell check/format changelogs, first fetch the forum changelogs with deadbot: `task changelogs-sync`.

The take the changelog you want to edit from the `./data/current/changelogs/raw` directory, and place it in `inputs/raw_changelogs`.  Then make you edits to the file, and run `task changelogs-sync` again to update the changelog data with your edits.
