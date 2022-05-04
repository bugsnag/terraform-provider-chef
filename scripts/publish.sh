#!/bin/bash
set -e

# Need goreleaser available locally to be able to sign the artifacts using GPG
if ! command -v goreleaser &> /dev/null
then
  echo "goreleaser is not installed. Please install via brew install goreleaser or via instructions https://goreleaser.com/install/"
  exit
fi

# Need gsutil for pushing to GCS
if ! command -v gsutil &> /dev/null
then
  echo "gsutil is not installed. Please install via Google Cloud CLI"
  exit
fi

GCS_BUCKET="gs://registry.bugsn.ag/v1/providers/bugsnag/chef"

# Tag release and push
git tag "$VERSION"
git push origin "$VERSION"

# Run goreleaser to generate binaries and publish release
goreleaser release --rm-dist

# Upload to GCS
if [ ! -d "dist" ]; then
  echo "dist does not exist, ensure goreleaser ran correctly."
  exit
fi

gsutil "dist/terraform-provider-chef_darwin_amd64_v1/terraform-provider-chef_v$VERSION" "$GCS_BUCKET/$VERSION/download/darwin/amd64"
gsutil "dist/terraform-provider-chef_linux_amd64_v1/terraform-provider-chef_v$VERSION" "$GCS_BUCKET/$VERSION/download/linux/amd64"

# Update versions file
gsutil cp $GCS_BUCKET/versions - | \
  jq -r --arg VERSION "$VERSION" '.versions += [{"version": $VERSION, "platforms": [{"os": "darwin", "arch": "amd64"},{"os": "linux", "arch": "amd64"}]}]' |
  gsutil cp - $GCS_BUCKET/versions
