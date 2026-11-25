#!/usr/bin/env bash
# Render Formula/tappet.rb from the latest tappet-dev/tappet release.
# Release asset contract: tappet-<version>-<target>.tar.gz for targets
#   aarch64-apple-darwin, x86_64-unknown-linux-musl, aarch64-unknown-linux-musl
# plus SHA256SUMS listing them.
set -euo pipefail
repo="${SOURCE_REPO:-tappet-dev/tappet}"
tag="${1:-$(gh release view -R "$repo" --json tagName -q .tagName)}"
version="${tag#v}"
sums="$(gh release download "$tag" -R "$repo" -p SHA256SUMS -O - )"
sha() { echo "$sums" | awk -v f="tappet-${version}-$1.tar.gz" '$2==f || $2=="*"f {print $1}'; }
url() { echo "https://github.com/${repo}/releases/download/${tag}/tappet-${version}-$1.tar.gz"; }
for t in aarch64-apple-darwin x86_64-unknown-linux-musl aarch64-unknown-linux-musl; do
  [ -n "$(sha $t)" ] || { echo "missing checksum for $t" >&2; exit 1; }
done
cat > Formula/tappet.rb <<RUBY
class Tappet < Formula
  desc "Single-binary workflow automation engine that runs n8n-exported workflows"
  homepage "https://tappet.dev"
  version "${version}"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "$(url aarch64-apple-darwin)"
      sha256 "$(sha aarch64-apple-darwin)"
    end
  end

  on_linux do
    on_intel do
      url "$(url x86_64-unknown-linux-musl)"
      sha256 "$(sha x86_64-unknown-linux-musl)"
    end
    on_arm do
      url "$(url aarch64-unknown-linux-musl)"
      sha256 "$(sha aarch64-unknown-linux-musl)"
    end
  end

  def install
    bin.install "tappet"
  end

  service do
    run [opt_bin/"tappet", "serve"]
    keep_alive true
    environment_variables TAPPET_DATA: var/"tappet"
    log_path var/"log/tappet.log"
    error_log_path var/"log/tappet.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/tappet version")
  end
end
RUBY
echo "rendered tappet ${version}"
