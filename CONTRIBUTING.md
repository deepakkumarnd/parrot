# Contributing to Parrot

Thanks for taking the time to contribute! Bug reports, documentation fixes and
new features are all welcome.

## Reporting bugs and requesting features

Open an [issue](https://github.com/deepakkumarnd/parrot/issues). For a bug,
include:

- your Ruby version (`ruby -v`) and Parrot version (`parrot -v`),
- the command you ran and the full output,
- a minimal post or `config.yaml` that shows the problem, if relevant.

For a larger change, please open an issue first so we can agree on the approach
before you write the code.

## Making a change

1. Fork the repository and set it up as described in
   [Development](docs/development.md#setup).
2. Create a branch named after the GitHub issue:
   - features: `feat/<issue-number>-<short-name>`, e.g. `feat/2-post-tags`
   - bug fixes: `fix/<issue-number>-<short-name>`, e.g. `fix/7-broken-internal-links`

   The short name is lowercase and kebab-case.
3. Make your change, with specs for new behavior or fixed bugs.
4. Make sure `bundle exec rspec` and `bundle exec rubocop` pass. The pre-commit
   hook runs both.
5. Update the docs in `README.md` or `docs/` if your change affects users.
6. Push the branch and open a pull request that explains what changed and why,
   and links the issue.

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE.txt).
