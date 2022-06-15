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

# Get the full key id from fingerprint
gpg_key_id=$(gpg --list-keys --with-colons --with-fingerprint "$GPG_FINGERPRINT" | awk -F: '/^fpr:/ { print $10 }' | head -n 1)
# Get public key from fingerprint
gpg_public_key=$(gpg --export -a "$GPG_FINGERPRINT" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g')

for platform in "darwin|amd64" "darwin|arm64" "linux|amd64"; do
  IFS='|' read -ra arr <<< $platform
  os=${arr[0]}
  arch=${arr[1]}
  checksum=$(sha256sum "dist/terraform-provider-chef_${VERSION}_${os}_${arch}.zip" | awk '{ print $1 }' )
  cat <<EOT > "dist/terraform-provider-chef_${VERSION}_${os}_${arch}.json"
{
  "os": "${os}",
  "arch": "${arch}",
  "filename": "terraform-provider-chef_${VERSION}_${os}_${arch}.zip",
  "download_url": "https://github.com/bugsnag/terraform-provider-chef/releases/download/${VERSION}/terraform-provider-chef_${VERSION}_${os}_${arch}.zip",
  "shasums_url": "https://github.com/bugsnag/terraform-provider-chef/releases/download/${VERSION}/terraform-provider-chef_${VERSION}_SHA256SUMS",
  "shasums_signature_url": "https://github.com/bugsnag/terraform-provider-chef/releases/download/${VERSION}/terraform-provider-chef_${VERSION}_SHA256SUMS.sig",
  "shasum": "${checksum}",
  "signing_keys": {
    "gpg_public_keys": [
      {
        "key_id": "$gpg_key_id",
        "ascii_armor": "$gpg_public_key",
        "trust_signature": "",
        "source": "Bugsnag",
        "source_url": "https://www.bugsnag.com"
      }
    ]
  }
}
EOT
gsutil cp "dist/terraform-provider-chef_${VERSION}_${os}_${arch}.json" "$GCS_BUCKET/$VERSION/download/${os}/${arch}"
done

# Update versions file
gsutil cp $GCS_BUCKET/versions - | \
  jq -r --arg VERSION "$VERSION" '.versions += [{"version": $VERSION, "platforms": [{"os": "darwin", "arch": "amd64"},{"os": "linux", "arch": "amd64"},{"os": "darwin", "arch": "arm64"}]}]' | \
  gsutil cp - $GCS_BUCKET/versions