# Nix durability tests

Tests to reproduce Nix durablity problems

## Tests

### Corrupt schema version

Reproduces a "schema is corrupt" error message.

### Corrupt store contents

Reproduces corrupt Nix store contents.

## Running

Run all tests on all filesystems:

    nix build -L -v .#

Run one test with one filesystem:

    nix build -L -v .#corrupt-schema-tests.xfs

## Notes

The tests are timing dependent, but XFS seems to reproduce the most reliabily on the tested systems.
