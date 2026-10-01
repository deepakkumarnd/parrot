# Development

This guide is for working on Parrot itself. To contribute, see also
[CONTRIBUTING.md](../CONTRIBUTING.md).

## Setup

```sh
git clone git@github.com:deepakkumarnd/parrot.git
cd parrot
./bin/setup
```

`bin/setup` runs `bundle install` and points git at the versioned hooks in
`.githooks/` (`git config core.hooksPath .githooks`). From then on the
`pre-commit` hook runs RuboCop and RSpec and stops the commit if either fails.

To try your changes on a real blog, run the executable from your checkout:

```sh
bundle exec exe/parrot new /tmp/blog
cd /tmp/blog
BUNDLE_GEMFILE=~/path/to/parrot/Gemfile bundle exec parrot serve
```

## Tests and linting

```sh
bundle exec rspec           # run the test suite
bundle exec rspec -f d      # documentation format
bundle exec rubocop         # lint (config in .rubocop.yml)
bundle exec rubocop -a      # autocorrect safe offenses
```

Run the suite from a directory without a `blog/` folder: some specs create and
delete `./blog`.

GitHub Actions (`.github/workflows/ci.yml`) runs RSpec and RuboCop on every pull
request and on pushes to `master`.

## Code layout

| Path | Contents |
| --- | --- |
| `exe/parrot` | The command-line entry point |
| `lib/parrot/commands/` | One class per command: `new`, `post`, `build`, `serve` |
| `lib/parrot/constants.rb` | Defaults for `config.yaml`, the highlighting theme and reserved post names |
| `lib/parrot/metadata.rb` | The gem version |
| `skel/` | The blog that `parrot new` copies |
| `spec/` | RSpec tests |

## Releasing

The gem is published on RubyGems as `prt`, because the name `parrot` belongs to
an unrelated gem. Releases use Bundler's gem tasks.

1. Bump the version and commit. `bundle exec rake bump_patch_version` bumps the
   patch number (0.3.0 → 0.3.1) in `lib/parrot/metadata.rb` and
   `spec/parrot/metadata_spec.rb`, and runs that spec. For a minor or major
   bump, edit both files by hand.
2. Run `bundle exec rake release`. It refuses to run with uncommitted changes.
   It builds `pkg/prt-<version>.gem`, tags `v<version>`, pushes `master` and the
   tag, and pushes the gem to RubyGems. You need to be signed in
   (`gem signin`), and you'll be asked for your MFA code.

`bundle exec rake build` builds the gem without publishing it, and
`bundle exec rake install` installs it locally.
