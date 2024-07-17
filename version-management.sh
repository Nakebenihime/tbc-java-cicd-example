#!/usr/bin/env bash

# logging functions for different log levels
log_info() { >&2 echo -e "[\e[1;94mINFO\e[0m] $*"; }
log_error() { >&2 echo -e "[\e[1;91mERROR\e[0m] $*"; }

# function to evaluate maven settings and builds the CLI option accordingly ("-s")
eval_mvn_settings_opt() {
  if [[ -f "$MAVEN_SETTINGS_FILE" ]]; then
    log_info "Maven settings file found: \e[33;1m$MAVEN_SETTINGS_FILE\e[0m"
    mvn_settings_opt="-s $MAVEN_SETTINGS_FILE"
  fi
}

# function to replace version in files
replace_version_in_files() {
  local VERSION=$1

  # replace version in CHANGELOG.md
  git add ":(glob)**/CHANGELOG.md"

  # replace version in pom.xml
  if [[ -f pom.xml ]]; then
    log_info "Bump to \e[33;1m$VERSION\e[0m version in pom.xml file(s)"
    apt-get update -q 1>/dev/null && apt-get install -qy maven 1>/dev/null
    mvn versions:set "$mvn_settings_opt" -DnewVersion="$VERSION" -q
    git add ":(glob)**/pom.xml"
  fi

  # replace version in Dockerfile
  if [[ $(find . -type f -name Dockerfile) ]]; then
    log_info "Bump to \e[33;1m$VERSION\e[0m version in Dockerfile"
    find . -name Dockerfile -exec sed -i "s/version=\"[0-9\.]\+\(-SNAPSHOT\)\?\"/version=\"$VERSION\"/" {} \;
    git add ":(glob)**/Dockerfile"
  fi
}

if [[ $# -eq 3 ]]; then
  NEXT_VERSION=$1
  RELEASE_TYPE=$2
  BRANCH=$3

  TEMP_NEXT_VERSION=$(echo "$NEXT_VERSION" | awk -F. '{print $1 "." $2 + 1 ".0"}')
  SNAPSHOT_VERSION=$TEMP_NEXT_VERSION-SNAPSHOT

  eval_mvn_settings_opt

  log_info "Bump version from \e[33;1m${NEXT_VERSION}\e[0m to \e[33;1m${SNAPSHOT_VERSION}\e[0m (release type: $RELEASE_TYPE)..."
  log_info "Create a release branch to retrieve changes done by bumpversion.sh"
  BRANCH_FROM_RELEASE=release/${NEXT_VERSION}
  git checkout -b "$BRANCH_FROM_RELEASE"

  replace_version_in_files "$SNAPSHOT_VERSION"

  # commit changes made in the release/${NEXT_VERSION}
  git commit -m "chore: prepare next development iteration ${SNAPSHOT_VERSION}"
  commit_result=$?

  if [ $commit_result -eq 0 ]; then
    log_info "Changes committed successfully."

    # merge changes into develop (default) branch
    log_info "Merge ${BRANCH_FROM_RELEASE} into develop"
    git fetch origin
    git checkout develop
    git merge --no-ff "$BRANCH_FROM_RELEASE" -m "Merge '$BRANCH_FROM_RELEASE' into develop [ci skip]"
    merge_result=$?

    if [ $merge_result -eq 0 ]; then
      log_info "Merge into develop branch successful."

      # push new commit to develop
      log_info "Push new commit to develop [ci skip]"
      GIT_BASE_URL=$(echo "$CI_REPOSITORY_URL" | cut -d\@ -f2)
      GIT_AUTH_URL="https://token:${GITLAB_TOKEN}@${GIT_BASE_URL}"
      git push "$GIT_AUTH_URL" develop
      push_result=$?

      if [ $push_result -eq 0 ]; then
        log_info "Push to develop branch successful."
      else
        log_error "Failed to push changes to develop branch."
      fi
    else
      log_error "Merge into develop branch failed."
    fi
  else
    log_error "Commit failed. Aborting further operations."
  fi

elif [[ $# -ge 4 ]]; then
  CURRENT_VERSION=$1
  NEXT_VERSION=$2
  RELEASE_TYPE=$3
  BRANCH=$4
  NOTES=$5

  eval_mvn_settings_opt

  if [[ "$CURRENT_VERSION" ]]; then
    log_info "Bump version from \e[33;1m${CURRENT_VERSION}\e[0m to \e[33;1m${NEXT_VERSION}\e[0m (release type: $RELEASE_TYPE)..."
    else
      if [[ -f pom.xml ]]; then
        SNAPSHOT_VERSION=$(mvn help:evaluate "$mvn_settings_opt" -Dexpression=project.version -q -DforceStdout | sed "s/[^0-9]*\\([0-9\\.]+\\(-SNAPSHOT\\)?\\).*/\\1/")
      else
        SNAPSHOT_VERSION=0.0.1-SNAPSHOT
      fi
      CURRENT_VERSION=${SNAPSHOT_VERSION/-SNAPSHOT/}
      log_info "Bump version from \e[33;1m${CURRENT_VERSION}\e[0m to \e[33;1m${NEXT_VERSION}\e[0m: this is the first release (skip)..."
  fi

  replace_version_in_files "$NEXT_VERSION"

  log_info "Push new commit to $BRANCH [ci skip]"
  git commit -m "chore(release): ${NEXT_VERSION}" -m "${NOTES}"
  GIT_BASE_URL=$(echo "$CI_REPOSITORY_URL" | cut -d\@ -f2)
  GIT_AUTH_URL="https://token:${GITLAB_TOKEN}@${GIT_BASE_URL}"
  git push -o ci.skip "$GIT_AUTH_URL" HEAD:"$BRANCH"

else
  log_error "Invalid number of arguments"
  log_error "Usage: $0 <current version> <next version> <release type> <branch name> <release notes> (for prepare)"
  log_error "       $0 <next version> <release type> <branch name> (for success)"
  exit 1
fi

exit $?