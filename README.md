# To update Terrform-provider-chef

## Requirement

Install gpg, go, sha256sum, goreleaser if you don't have them yet:

```shell
brew install gpg
brew install go
brew install goreleaser
brew install coreutils # contains sha256sum
```

## To publish

you'll need the new version number, a GPG_FINGERPRINT:

```shell
gpg --list-keys
```
you'll also need a github token with the 'repo' scope

Add this to your `.bashrc`, `zshrc`, `.profile` etc and `source` the file if you don't have it yet:

```sh
export GPG_TTY=$(tty)
```

Run publish.sh

```shell
$ make publish VERSION=yourVersion GPG_FINGERPRINT=yourGPGfingerprint GITHUB_TOKEN=yourGithubToken
```

## Rollback publish for rerun

remove any bad files from GCS if generated
remove the remote tag in github
remove the local tag by running

```sh
git tag -d yourVersion
```
