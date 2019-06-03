#!/bin/bash

set -o nounset

PRS=""
DATE=""
GITHUB_SEARCH_URL='https://api.github.com/search/issues?q=is:pr+user:kata-containers+base:master+is:closed+merged:">=DATE_SINCE"+label:stable-candidate&per_page=100'
FAILED=()
SUCCESS=()

function usage()
{
  echo ""
  echo "Usage: $(basename ${0}) [-d|--date] [-h|--help]"
  echo ""
  echo "d|date: PRs since this date"
  echo "h|help: print this"
  echo ""
  exit 1
}

function cherry-pick-changes()
{
  args=("$@")
  git checkout "$(git rev-parse HEAD | cut -c1-8)"
  for commit in ${args[*]}
  do
    git cherry-pick -x -s ${commit}
    if [ $? -ne 0 ]
    then
      git cherry-pick --abort
      git reset --hard
      git clean -xdf
      return 1
    fi
  done
  return 0
}

ARGS=$(getopt -o d:h -l date:,help -- "$@")
if [ $# -eq 0 ]; then usage; fi

eval set -- "${ARGS}"

while true; do
  case "$1" in
    -d|--date) DATE="$2"; shift 2;;
    -h|--help) usage;;
    --)shift; break;;
    *)usage;;
  esac
done

if [ -z "${DATE}" ]; then usage; fi

PRS=$(curl -ns ${GITHUB_SEARCH_URL/DATE_SINCE/${DATE}} | jq -r '.items[] | [ .repository_url, "pulls", .number|tostring] | join("/")')|| (echo "Unable to get the merged PRs" && exit 1)

for PR in ${PRS}
do
  repo=$(echo ${PR} | sed 's/.*repos\///' | sed 's/\/pulls.*//')
  commits=$(curl -ns "${PR}/commits" | jq -r '.[] | .sha')
  echo "Pulling ${PR}..."
  pushd $GOPATH/src/github.com/${repo}
  branch=$(git branch --contains "$(git rev-parse HEAD | cut -c1-8)" | grep \* | cut -d ' ' -f2)
  cherry-pick-changes "${commits}"
  if [ $? -ne 0 ]
  then
    echo "Unable to merge ${PR}"
    git checkout $branch
    #FAILED+=(${PR})
    FAILED+=("${repo}#${PR##*\/}")
  else
    git checkout $branch
    git merge HEAD@{1}
    #SUCCESS+=(${PR})
    SUCCESS+=("${repo}#${PR##*\/}")
  fi
  popd
done

echo "FAILED THESE PRs"
printf '%s\n' ${FAILED[@]} | sort
echo "SUCCESS FOR THESE"
printf '%s\n' ${SUCCESS[@]} | sort
