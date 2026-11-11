#!/bin/bash
set -euo pipefail

# ==============================================================
# Regenerates packer/scripts/checksums.sha256 after a version change in install.sh.
#
# install.sh downloads WordPress and its language packs at pinned versions and checks each file
# against the SHA256 committed in checksums.sha256. This script produces those SHA256 values:
#   1. reads the versions and locales from install.sh, so they are written in one place only;
#   2. downloads the WordPress release and checks it against the SHA1 that WordPress publishes
#      (WordPress publishes no SHA256). It stops if the SHA1 does not match;
#   3. checks that THEME_VERSION is the version of the theme bundled in that release;
#   4. downloads the language packs, which have no official checksum;
#   5. computes the SHA256 of every file and rewrites checksums.sha256.
#
# The official SHA1 is checked here, once per version, and not in the image build: the build
# compares against the committed SHA256, so the checksum never comes from the same server as the
# file. Review the diff of checksums.sha256 in the PR like any other change.
#
# Usage, from the repository root, after editing the versions in packer/scripts/install.sh:
#   bash packer/scripts/update-checksums.sh
#
# Language packs for a new WordPress version are published some days after the release; until
# then the download of a missing locale fails and the script stops.
# ==============================================================

INSTALL_SCRIPT="packer/scripts/install.sh"
CHECKSUMS_FILE="packer/scripts/checksums.sha256"

if [[ ! -f "${INSTALL_SCRIPT}" ]]; then
  echo "ERROR: run this script from the repository root." >&2
  exit 1
fi

# Value of a VAR="value" line of install.sh. Fails if the line is missing.
read_var() {
  local value
  value=$(sed -n "s/^$1=\"\(.*\)\"\r\{0,1\}$/\1/p" "${INSTALL_SCRIPT}")
  if [[ -z "${value}" ]]; then
    echo "ERROR: $1 not found in ${INSTALL_SCRIPT}." >&2
    return 1
  fi
  echo "${value}"
}

WP_VERSION=$(read_var WP_VERSION)
THEME_SLUG=$(read_var THEME_SLUG)
THEME_VERSION=$(read_var THEME_VERSION)
CORE_LOCALES=$(read_var CORE_LOCALES)
THEME_LOCALES=$(read_var THEME_LOCALES)

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

WP_ARCHIVE="wordpress-${WP_VERSION}.tar.gz"

echo ">>> WordPress ${WP_VERSION}: download and check against the official SHA1..."
curl -fsSL -o "${WORK_DIR}/${WP_ARCHIVE}" "https://wordpress.org/${WP_ARCHIVE}"
OFFICIAL_SHA1=$(curl -fsS "https://wordpress.org/${WP_ARCHIVE}.sha1")
(cd "${WORK_DIR}" && echo "${OFFICIAL_SHA1}  ${WP_ARCHIVE}" | sha1sum -c -)

echo ">>> Checking the version of ${THEME_SLUG} bundled in WordPress ${WP_VERSION}..."
BUNDLED_THEME_VERSION=$(tar -xzOf "${WORK_DIR}/${WP_ARCHIVE}" "wordpress/wp-content/themes/${THEME_SLUG}/style.css" \
  | sed -n 's/^Version:[[:space:]]*\([^[:space:]]*\).*/\1/p')
if [[ "${BUNDLED_THEME_VERSION}" != "${THEME_VERSION}" ]]; then
  echo "ERROR: WordPress ${WP_VERSION} bundles ${THEME_SLUG} ${BUNDLED_THEME_VERSION}, but THEME_VERSION is ${THEME_VERSION}. Update it in ${INSTALL_SCRIPT}." >&2
  exit 1
fi

echo ">>> Downloading the language packs..."
FILES=("${WP_ARCHIVE}")
for locale in ${CORE_LOCALES}; do
  file="wordpress-${WP_VERSION}-${locale}.zip"
  curl -fsSL -o "${WORK_DIR}/${file}" "https://downloads.wordpress.org/translation/core/${WP_VERSION}/${locale}.zip"
  FILES+=("${file}")
done
for locale in ${THEME_LOCALES}; do
  file="${THEME_SLUG}-${THEME_VERSION}-${locale}.zip"
  curl -fsSL -o "${WORK_DIR}/${file}" "https://downloads.wordpress.org/translation/theme/${THEME_SLUG}/${THEME_VERSION}/${locale}.zip"
  FILES+=("${file}")
done

echo ">>> Writing ${CHECKSUMS_FILE}..."
# sed: some sha256sum builds (Git Bash on Windows) mark files read in binary mode with "*"; the
# file keeps the two-space format that sha256sum -c reads everywhere.
(cd "${WORK_DIR}" && sha256sum "${FILES[@]}") | sed 's/ \*/  /' > "${CHECKSUMS_FILE}"
cat "${CHECKSUMS_FILE}"
echo ""
echo "Done. Review the diff (git diff ${CHECKSUMS_FILE}) and commit it with the version change."
