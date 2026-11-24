#!/bin/bash

#
# Copyright (C) 2023 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="${REPOBASE:-ghcr.io/geniusdynamics}"
# Configure the image name
reponame="superset"
# Node.js 25+ no longer ships Corepack, install it from npm
# renovate: datasource=npm packageName=corepack
corepack_version=0.36.0

buildah bud -f Containerfile -t "${repobase}/superset-runtime" .


# Create a new empty container image
container=$(buildah from scratch)

# Reuse existing nodebuilder-superset container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-superset; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-superset -v "${PWD}:/usr/src:Z" docker.io/library/node:26.13.0-slim
    buildah run nodebuilder-superset sh -c "npm install -g corepack@${corepack_version} && corepack enable"
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-superset \
    sh -c "yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# Setup the entrypoint, ask to reserve one TCP port with the label and set a rootless container
# org.nethserver.images lists every image pulled at runtime. Always use fully
# pinned tags, Renovate reads them: the custom Superset runtime image built
# from Containerfile (published together with the module) and PostgreSQL.
# rootfull=0 === rootless container
# tcp-ports-demand=1 number of tcp Port to reserve
buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm" \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.min-core=3.20.1" \
    --label="org.nethserver.images=${repobase}/superset-runtime:${IMAGETAG:-latest} docker.io/library/postgres:17.12-alpine" \
    "${container}"
# Commit the image
buildah commit "${container}" "${repobase}/${reponame}"

# Append the image URL to the images array
images+=("${repobase}/${reponame}")
images+=("${repobase}/superset-runtime")

#
# Setup CI when pushing to Github. 
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
