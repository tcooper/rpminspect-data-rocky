#!/bin/sh
#
# Build new releases in Koji
#
# Copyright (C) 2019 David Cantrell <david.l.cantrell@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# Arguments:
#     $1    Path to the release tarball to build
#     $2    Path to the detached signature for the release tarball
#     $3    The name of the project in dist-git

PATH=/usr/bin
CWD="$(pwd)"
WRKDIR="$(mktemp -d)"

# The list of tools that may or may not be installed locally but
# that the script needs.  Extend this list if needed.
TOOLS="klist"

# What dist-git interaction tool we are using, e.g. Fedora is 'fedpkg'
VENDORPKG="fedpkg"

# What package build tool is in use
VENDORBLD="koji"

cleanup() {
    rm -rf "${WRKDIR}"
}

trap cleanup EXIT

# Verify specific tools are available
for tool in ${TOOLS} ${VENDORPKG} ${VENDORBLD} ; do
    ${tool} >/dev/null 2>&1
    if [ $? -eq 127 ]; then
        echo "*** Missing '${tool}', perhaps 'yum install -y /usr/bin/${tool}'" >&2
        exit 1
    fi
done

# Need a tarball
if [ $# -eq 0 ]; then
    echo "*** Missing tarball of new release" >&2
    exit 1
fi

TARBALL="$(realpath "$1")"

if [ ! -f "${TARBALL}" ]; then
    echo "*** $(basename "${TARBALL}") does not exist" >&2
    exit 1
fi

if ! tar tf "${TARBALL}" >/dev/null 2>&1 ; then
    echo "*** $(basename "${TARBALL}") is not a tar archive" >&2
    exit 1
fi

shift

# Need tarball signature
if [ $# -eq 0 ]; then
    echo "*** Missing detached signature of release tarball" >&2
    exit 1
fi

TARBALL_ASC="$(realpath "$1")"

if [ ! -f "${TARBALL_ASC}" ]; then
    echo "*** $(basename "${TARBALL_ASC}") does not exist" >&2
    exit 1
fi

if [ ! "$(file -b --mime-type "${TARBALL_ASC}")" = "application/pgp-signature" ]; then
    echo "*** $(basename "${TARBALL_ASC}") is not a gpg signature" >&2
    exit 1
fi

shift

# Need project name
if [ $# -eq 0 ]; then
    echo "*** Missing project name" >&2
    exit 1
fi

PROJECT="$1"
shift

# Need a krb5 ticket
if ! klist >/dev/null 2>&1 ; then
    echo "*** You lack an active Kerberos ticket" >&2
    exit 1
fi

if ! klist | grep -q "krbtgt/FEDORAPROJECT.ORG@FEDORAPROJECT.ORG" >/dev/null 2>&1 ; then
    echo "*** You need a FEDORAPROJECT.ORG Kerberos ticket" >&2
    exit 1
fi

GIT_USERNAME="$(git config user.name)"
GIT_USEREMAIL="$(git config user.email)"

cd "${CWD}" || exit
name="$(grep project ../meson.build | cut -d "'" -f 2)"
version="$(grep version "${CWD}"/meson.build | head -n 1 | cut -d "'" -f 2)"
echo "* $(date +"%a %b %d %Y") $(git config user.name) <$(git config user.email)> - ${version}-1" > "${WRKDIR}"/newchangelog
echo "- Upgrade to ${name}-${version}" >> "${WRKDIR}"/newchangelog

cd "${WRKDIR}" || exit
${VENDORPKG} co "${PROJECT}"
cd "${PROJECT}" || exit
git config user.name "${GIT_USERNAME}"
git config user.email "${GIT_USEREMAIL}"

# Allow the calling environment to override the list of dist-git branches
if [ -z "${BRANCHES}" ]; then
    BRANCHES="$(git branch -r | grep -vE "(HEAD)" | cut -d '/' -f 2 | sort | xargs)"
fi

for branch in ${BRANCHES} ; do
    # skip this branch if there is no build target
    if ! ${VENDORBLD} list-targets | grep -q "${branch}" >/dev/null 2>&1 ; then
        echo "*** skipping branch ${branch} because there are no ${VENDORBLD} build targets"
        continue
    fi

    # clean it
    git clean -d -x -f

    # make sure we are on the right branch
    ${VENDORPKG} switch-branch ${branch}
    git pull

    # add the new source archive
    ${VENDORPKG} new-sources "${TARBALL}"

    # extract downstream %changelog
    sed -n '/^%changelog/,$p' "${PROJECT}".spec | grep -vE '^%changelog)' > existingcl
    [ -s existingcl ] || rm -f existingcl

    # delete the %changelog block
    sed -n '/^%changelog/q;p' "${CWD}"/"${PROJECT}".spec > "${PROJECT}".spec

    # update the rolling %changelog for downstream builds
    echo "%changelog" >> "${PROJECT}".spec

    if [ -f existingcl ]; then
        cat "${WRKDIR}"/newchangelog existingcl >> "${PROJECT}".spec
        rm -f existingcl
    else
        cat "${WRKDIR}"/newchangelog >> "${PROJECT}".spec
    fi

    # commit changes
    git add sources "${PROJECT}".spec
    ${VENDORPKG} ci -c -p -s
    git clean -d -x -f

    # build
    ${VENDORPKG} build --nowait
done
