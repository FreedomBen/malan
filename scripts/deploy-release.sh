#!/usr/bin/env bash

declare -rx color_restore='\033[0m'
declare -rx color_red='\033[0;31m'
declare -rx color_green='\033[0;32m'
declare -rx color_blue='\033[0;34m'
declare -rx color_cyan='\033[0;36m'
declare -rx color_yellow='\033[1;33m'

declare -rx SLEEP_SECONDS_AFTER_APPLY='3'
declare -rx KUBECTL_EXTERNAL_DIFF='diff --color -N -u'
declare -rx K8S_CA_CERT_TEMP_FILE='/tmp/k8s.ca.crt'

declare -x MIGRATION_TIMEOUT_SECS='1800'
declare -x DEPLOY_TIMEOUT_SECS='900'
declare -x MIGRATION_DELETE_SECS='10'

# Exit codes (see print_usage and cicd/README.md for documentation):
#   0 = success
#   1 = usage error (bad/missing flags, unknown args, no actions, or --help)
#   2 = missing required configuration (env vars or flags)
#   3 = missing required file or directory
#   4 = manifest content error (e.g. missing or multiple namespaces)
#   5 = migration failure (apply or wait failed)
#   6 = deployment failure (apply or rollout failed)
declare -rx EXIT_SUCCESS='0'
declare -rx EXIT_USAGE='1'
declare -rx EXIT_CONFIG='2'
declare -rx EXIT_FILE='3'
declare -rx EXIT_MANIFEST='4'
declare -rx EXIT_MIGRATION_FAIL='5'
declare -rx EXIT_DEPLOY_FAIL='6'

die ()
{
  # Args: $1 = message, $2 = exit code (default 1)
  # Writes to stderr so the FATAL message is not captured by callers that
  # invoke functions inside command substitution (e.g. $(get_namespace)).
  local message="${1}"
  local code="${2:-1}"
  echo -e "${color_red}[FATAL]${color_restore} ${color_cyan}$(date)${color_restore}:  ${message}" >&2
  exit "${code}"
}

notify_migration_failure_and_die ()
{
  notify_migration_fail
  die "${1}" "${EXIT_MIGRATION_FAIL}"
}

notify_deploy_failure_and_die ()
{
  notify_deploy_fail
  die "${1}" "${EXIT_DEPLOY_FAIL}"
}

log ()
{
  echo -e "${color_green}[LOG]${color_restore} ${color_cyan}$(date)${color_restore}:  * ${1}"
}

debug ()
{
  if is_debug; then
    echo -e "${color_blue}[DEBUG]${color_restore} ${color_cyan}$(date)${color_restore}:  ${1}"
  fi
}

warn ()
{
  echo -e "${color_yellow}[WARN]${color_restore} ${color_cyan}$(date)${color_restore}:  * ${1}"
}

error ()
{
  echo -e "${color_red}[ERROR]${color_restore} ${color_cyan}$(date)${color_restore}:  * ${1}"
}

is_debug ()
{
  is_enabled "${DEBUG}"
}

is_force ()
{
  is_enabled "${FORCE}"
}

k8s_server ()
{
  if [ -n "${K8S_SERVER}" ]; then
    echo "--server ${K8S_SERVER}"
  else
    echo ""
  fi
}

k8s_token ()
{
  if [ -n "${K8S_TOKEN}" ]; then
    echo "--token ${K8S_TOKEN}"
  else
    echo ""
  fi
}

k8s_ca ()
{
  # Note:  We should verify the cert, but a bug in kubectl may be preventing that:
  # https://github.com/kubernetes/kubernetes/issues/48767

  local filename="k8s/ca-cert/${ENV}.ca.crt"

  # If the temp file which comes from an env var is set, use that instead
  if [ -f "${K8S_CA_CERT_TEMP_FILE}" ]; then
    filename="${K8S_CA_CERT_TEMP_FILE}"
  fi

  if [ -f "${filename}" ]; then
    #echo "--certificate-authority '${filename}'"
    echo "--insecure-skip-tls-verify=true"
  else
    echo ""
  fi
}

k8s_namespace ()
{
  echo "--namespace=$(get_namespace "${1}")"
}

k8s_namespace_deploy ()
{
  echo "--namespace=$(get_namespace "$(deploy_manifest)")"
}

k8s_namespace_migration ()
{
  echo "--namespace=$(get_namespace "$(migration_manifest)")"
}

k8s_namespace_config ()
{
  echo "--namespace=$(get_namespace "$(config_manifest)")"
}

check_required_vars ()
{
  if [ -z "${ENV}" ]; then
    die "Missing required flag --env or env var ENV" "${EXIT_CONFIG}"
  elif [ -z "${RELEASE_VERSION}" ]; then
    die "Missing required flag --release-ver or env var RELEASE_VERSION" "${EXIT_CONFIG}"
  elif [ -z "${K8S_SERVER}" ]; then
    if [ -n "${APPLY_MIGRATION}" ] || [ -n "${APPLY_DEPLOY}" ]; then
      die "Apply operations require flag --k8s-server or env var K8S_SERVER" "${EXIT_CONFIG}"
    fi
  elif [ -z "${K8S_TOKEN}" ]; then
    if [ -n "${APPLY_MIGRATION}" ] || [ -n "${APPLY_DEPLOY}" ]; then
      die "Apply operations require flag --k8s-token or env var K8S_TOKEN" "${EXIT_CONFIG}"
    fi
  fi
}

check_env_exists ()
{
  debug "Checking that the current env '${ENV}' exists (has files)"
  if [ -n "${ENV}" ]; then
    if [ -d "k8s/${ENV}" ]; then
      log "Current ENV is '${ENV}' and it's k8s config directory exists"
    else
      die "Directory k8s/${ENV} does not exist. Verify \$ENV is set correctly and try again" "${EXIT_FILE}"
    fi
  else
    die "Env var \$ENV is not set. Please set and try again" "${EXIT_CONFIG}"
  fi
}

check_file ()
{
  debug "Checking for existence of mandatory file '${1}'"
  if ! [ -f "${1}" ]; then
    error "Mandatory file '${1}' does not exist!"
    die "If you are running a diff or an apply, make sure that you run --save operation first" "${EXIT_FILE}"
  fi
}

check_dir_for_files ()
{
  if is_enabled "${SAVE_MIGRATION}" || is_enabled "${APPLY_MIGRATION}"; then
    check_file "k8s/${ENV}/migrate.yaml"
  fi

  if is_enabled "${SAVE_DEPLOY}" || is_enabled "${APPLY_DEPLOY}"; then
    check_file "k8s/${ENV}/deploy.yaml"
  fi

  if [ -n "${K8S_CA_CERT}" ]; then
    echo "${K8S_CA_CERT}" > "${K8S_CA_CERT_TEMP_FILE}"
    check_file "${K8S_CA_CERT_TEMP_FILE}"
  else
    check_file "k8s/ca-cert/${ENV}.ca.crt"
  fi
}

check_for_migration_manifest ()
{
  if is_enabled "${DIFF_MIGRATION}" || is_enabled "${APPLY_MIGRATION}"; then
    check_file "$(migration_manifest)"
  fi
}

check_for_deploy_manifest ()
{
  if is_enabled "${DIFF_DEPLOY}" || is_enabled "${APPLY_DEPLOY}"; then
    check_file "$(deploy_manifest)"
  fi
}

migration_manifest ()
{
  echo "${MANIFEST_DIR}/migrate.yaml"
}

generate_migration_manifest ()
{
  debug "Rendering migration manifest into file $(migration_manifest)"
  cat k8s/${ENV}/migrate.yaml \
    | envsubst \
    > "$(migration_manifest)"
  log "Rendered migration manifest into file $(migration_manifest)"
}

deploy_manifest ()
{
  echo "${MANIFEST_DIR}/deploy.yaml"
}

generate_deploy_manifest ()
{
  debug "Rendering deploy manifest for release '${RELEASE_VERSION}' into file $(deploy_manifest)"
  cat k8s/${ENV}/deploy.yaml \
    | envsubst \
    > "$(deploy_manifest)"
  log "Rendered deploy manifest into file $(deploy_manifest)"
}

config_manifest ()
{
  echo "${MANIFEST_DIR}/config.yaml"
}

generate_config_manifest ()
{
  # Config is optional; if no source file is present, silently skip so projects
  # that don't need a pre-deploy kubectl replace are unaffected.
  local source="k8s/${ENV}/config.yaml"
  if [ ! -f "${source}" ]; then
    log "No config source at '${source}'.  Skipping config render."
    return 0
  fi
  debug "Rendering config manifest for release '${RELEASE_VERSION}' into file $(config_manifest)"
  cat "${source}" \
    | envsubst \
    > "$(config_manifest)"
  log "Rendered config manifest into file $(config_manifest)"
}

get_migration_name ()
{
  kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) get -f $(migration_manifest) \
    | grep '^job.batch' \
    | head -1 \
    | awk '{ print $1 }'
}

delete_old_migration_job ()
{
  local old_migration="${1}"

  log "Deleting old migration job '${old_migration}'"

  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) delete \"${old_migration}\""

  kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) delete --wait=true "${old_migration}"
}

object_exists ()
{
  debug "Checking if object '${1}' exists"

  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) get \"${1}\""

  kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) get "${1}"
}

delete_old_migration_job_if_exist ()
{
  debug 'Retrieving old migration name'
  local old_migration="$(get_migration_name)"

  log "Checking if old migration job '${old_migration}' exists"

  if object_exists "${old_migration}"; then
    log "Old migration job still exists.  Deleting..."
    delete_old_migration_job "${old_migration}"

    log "Waiting ${MIGRATION_DELETE_SECS} seconds for old job and pods to delete"
    sleep "${MIGRATION_DELETE_SECS}"
  else
    log "Old migration does not exist"
  fi
}

diff_migration_manifest ()
{
  # Exit status: 0 No differences were found. 1 Differences were found. >1 Kubectl or diff failed with an error.
  log "Diffing migration manifest file '$(migration_manifest)' to cluster '$(k8s_server)'"

  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) diff -f \"$(migration_manifest)\""

  kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) diff -f "$(migration_manifest)"
}

diff_deploy_manifest ()
{
  log "Diffing deployment manifest file '$(deploy_manifest)' to cluster '$(k8s_server)'"
  kubectl $(k8s_namespace_deploy) $(k8s_server) $(k8s_token) $(k8s_ca) diff -f "$(deploy_manifest)"
}

apply_migration_manifest ()
{
  log "Applying migration manifest file '$(migration_manifest)' to cluster '$(k8s_server)'"

  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) apply -f \"$(migration_manifest)\""

  kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) apply -f "$(migration_manifest)"
}

wait_for_migration_complete ()
{
  local migration_name="$(get_migration_name)"

  if [ -z "${migration_name}" ]; then
    error "Problem parsing deployment name from file '$(migration_manifest)'"
    return "${EXIT_MANIFEST}"
  else
    debug "Parsed deployment name '${migration_name}' from '$(migration_manifest)'"
  fi

  log "Waiting ${MIGRATION_TIMEOUT_SECS} seconds for migration '${migration_name}' to complete"

  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) wait --for=condition=Complete --timeout=\"${MIGRATION_TIMEOUT_SECS}s\" \"${migration_name}\""

  kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) wait --for=condition=Complete --timeout="${MIGRATION_TIMEOUT_SECS}s" "${migration_name}"
}

print_migration_logs ()
{
  debug 'Retrieving migration name'
  local migration_name="$(get_migration_name)"

  log "Retrieving logs for migration '${migration_name}'"

  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) logs \"${migration_name}\""

  kubectl $(k8s_namespace_migration) $(k8s_server) $(k8s_token) $(k8s_ca) logs "${migration_name}"
}

apply_and_wait_migration_manifest ()
{
  if apply_migration_manifest; then
    log "Apply of migration manifest succeeded!  Waiting ${SLEEP_SECONDS_AFTER_APPLY} seconds before checking status..."
    sleep "${SLEEP_SECONDS_AFTER_APPLY}"

    if wait_for_migration_complete; then
      log "Migration completed successfully!"
    else
      local wait_exit=$?
      print_migration_logs
      notify_migration_failure_and_die "Migration did NOT complete successfully.  exit status was '${wait_exit}'.  Be sure to check the logs above and verify the current state of the application in ${ENV}"
    fi
    print_migration_logs
  else
    notify_migration_failure_and_die "Apply of migration manifest FAILED!"
  fi
}

apply_deploy_manifest ()
{
  log "Applying deployment manifest file '$(deploy_manifest)' to cluster '$(k8s_server)'"

  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_deploy) $(k8s_server) $(k8s_token) $(k8s_ca) apply -f \"$(deploy_manifest)\""

  kubectl $(k8s_namespace_deploy) $(k8s_server) $(k8s_token) $(k8s_ca) apply -f "$(deploy_manifest)"
}

apply_or_replace_config_manifest ()
{
  # Optional pre-deploy step.  If the rendered config manifest exists we want
  # `kubectl replace` semantics (full object overwrite, not 3-way merge), but
  # replace fails when the resource is not yet on the cluster — so on the
  # first deploy we fall back to `kubectl apply` to seed it.
  local rendered="$(config_manifest)"
  if [ ! -f "${rendered}" ]; then
    log "No rendered config manifest at '${rendered}'.  Skipping config update."
    return 0
  fi

  debug "Checking whether config resources already exist on cluster '$(k8s_server)'"
  debug "| Running command:"
  debug "|=> kubectl $(k8s_namespace_config) $(k8s_server) $(k8s_token) $(k8s_ca) get -f \"${rendered}\""

  if kubectl $(k8s_namespace_config) $(k8s_server) $(k8s_token) $(k8s_ca) get -f "${rendered}" > /dev/null 2>&1; then
    log "Config resources exist.  Replacing config manifest file '${rendered}' on cluster '$(k8s_server)'"

    debug "| Running command:"
    debug "|=> kubectl $(k8s_namespace_config) $(k8s_server) $(k8s_token) $(k8s_ca) replace -f \"${rendered}\""

    kubectl $(k8s_namespace_config) $(k8s_server) $(k8s_token) $(k8s_ca) replace -f "${rendered}"
  else
    log "Config resources not yet present.  Applying config manifest file '${rendered}' to cluster '$(k8s_server)'"

    debug "| Running command:"
    debug "|=> kubectl $(k8s_namespace_config) $(k8s_server) $(k8s_token) $(k8s_ca) apply -f \"${rendered}\""

    kubectl $(k8s_namespace_config) $(k8s_server) $(k8s_token) $(k8s_ca) apply -f "${rendered}"
  fi
}

get_rollout_resource_names ()
{
  # Return all rollout-capable resources (Deployment, DaemonSet, StatefulSet)
  # -o name forces "kind.group/name" output; the default tabular output drops
  # the kind prefix when the manifest contains a single resource type, which
  # is the case for the DaemonSet-only primer manifest.
  kubectl $(k8s_server) $(k8s_token) $(k8s_ca) get -f $(deploy_manifest) -o name \
    | grep -E '^(deployment|daemonset|statefulset)\.apps/'
}

get_namespace ()
{
  # Current implementation assumes that the first namespace is the only one.
  # We should actually use the correct namespace for each object

  #kubectl $(k8s_server) $(k8s_token) $(k8s_ca) get \
  #  -f $(deploy_manifest) \
  #  -o jsonpath='{.items[*].metadata.namespace}' \
  #  | sed -e 's/\s/\n/g' \
  #  | sort \
  #  | uniq

  local manifest="${1}"

  if [ -z "${manifest}" ]; then
    manifest=$(deploy_manifest)
  fi

  #kubectl $(k8s_server) $(k8s_token) $(k8s_ca) get \
  #  -f "${manifest}" \
  #  -o jsonpath='{.items[0].metadata.namespace}'

  local namespaces="$(cat "${manifest}" | grep -E '^\s*namespace:\s' | awk '{ print $2 }' | sort | uniq)"

  if [ -z "${namespaces}" ]; then
    die "Expected 1 namespace but found 0 in manifest '${manifest}'" "${EXIT_MANIFEST}"
  fi

  local num_namespaces="$(echo "${namespaces}" | wc -l)"

  if (( "${num_namespaces}" != 1 )); then
    die "Expected 1 namespace but found ${num_namespaces}.  '$(echo ${namespaces} | xargs)'" "${EXIT_MANIFEST}"
  else
    cat "${manifest}" | grep -E '^\s*namespace:\s' | awk '{ print $2 }' | sort | uniq
  fi
}

wait_for_deploy_complete ()
{
  local deploy_names="$(get_rollout_resource_names)"

  if [ -z "${deploy_names}" ]; then
    log "No rollout-capable resources (Deployment/DaemonSet/StatefulSet) in '$(deploy_manifest)'.  Nothing to wait for."
    return 0
  fi

  debug "Parsed rollout resources from '$(deploy_manifest)':"
  debug "${deploy_names}"

  local deploy_name
  while IFS= read -r deploy_name; do
    log "Waiting ${DEPLOY_TIMEOUT_SECS} seconds for rollout '${deploy_name}' to complete"

    debug "| Running command:"
    debug "|=> kubectl $(k8s_namespace_deploy) $(k8s_server) $(k8s_token) $(k8s_ca) rollout status --watch --timeout=\"${DEPLOY_TIMEOUT_SECS}s\" \"${deploy_name}\""

    if ! kubectl $(k8s_namespace_deploy) $(k8s_server) $(k8s_token) $(k8s_ca) rollout status --watch --timeout="${DEPLOY_TIMEOUT_SECS}s" "${deploy_name}"; then
      error "Rollout of '${deploy_name}' did NOT complete successfully"
      return "${EXIT_DEPLOY_FAIL}"
    fi
  done <<< "${deploy_names}"
}

apply_and_wait_deployment_manifest ()
{
  if ! apply_or_replace_config_manifest; then
    notify_deploy_failure_and_die "Apply/replace of config manifest FAILED!  Check logs above"
  fi

  if apply_deploy_manifest; then
    log "Apply of deploy manifest succeeded!  Waiting ${SLEEP_SECONDS_AFTER_APPLY} seconds before checking status..."
    sleep "${SLEEP_SECONDS_AFTER_APPLY}"

    if wait_for_deploy_complete; then
      log "Deployment completed successfully!"
      notify_deploy_complete
    else
      notify_deploy_failure_and_die "Deployment did NOT complete successfully.  exit status was '$?'.  Be sure to check the logs above and verify the current state of the application in ${ENV}"
    fi
  else
    notify_deploy_failure_and_die "Apply of deploy manifest FAILED!  Check logs above"
  fi
}

verify_namespace_is_set ()
{
  debug "Verifying a namespace is set"
  local namespace="$(get_namespace)"

  if [ -n "${namespace}" ]; then
    log "Namespace we're using is '${namespace}'"
  else
    die "Unable to parse a namespace from the deploy manifest at '$(deploy_manifest)'.  Ensure one is set and try again.  Parsed was '${namespace}'" "${EXIT_MANIFEST}"
  fi
}

print_usage ()
{
  echo "
  Usage:

  Actions:

    -l|--save-apply-all
    -s|--save-all
       --save-migration
       --save-deploy
    -d|--diff-all
       --diff-migration
       --diff-deploy
    -a|--apply-all       # Applying automatically includes diffing
       --apply-migration
       --apply-deploy

    -h|--help  # Display this menu

  Configuration (flag or environment variable):

    -m|--manifest-dir <manifest-directory> # or MANIFEST_DIR

    -f|--force # or FORCE='yes'
       --debug # or DEBUG='yes'

    -t|--timeout-secs <seconds>           # sets both migration and deploy timeout value
       --migration-timeout-secs <seconds> # or MIGRATION_TIMEOUT_SECS
       --deploy-timeout-secs <seconds>    # or DEPLOY_TIMEOUT_SECS

    -e|--env <environment>             # or ENV
    -r|--release-ver <release-version> # or RELEASE_VERSION
    -k|--k8s-server <k8s-server>       # or K8S_SERVER
       --k8s-token <k8s-token>         # or K8S_TOKEN

  Exit codes:

    0 - Success
    1 - Usage error (bad/missing flags, unknown args, no actions, or --help)
    2 - Missing required configuration (env vars or flags)
    3 - Missing required file or directory (manifest, CA cert, env config)
    4 - Manifest content error (e.g. missing or multiple namespaces)
    5 - Migration failure (apply or wait failed)
    6 - Deployment failure (apply or rollout failed)

  "
}

print_usage_and_exit ()
{
  print_usage
  exit "${EXIT_USAGE}"
}

is_enabled ()
{
  [[ "${1}" =~ ^[Yy] ]]
}

sanitize ()
{
  echo "${1}" | sed -e 's/./*/g' | awk '{ print substr($0, 0, 10) }'
}

get_gh_link ()
{
  echo "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
}

send_slack_message ()
{
  local username="Deploy of ${GITHUB_REPOSITORY} to ${ENV}"
  if [ -n "${SLACK_TOKEN}" ] && [ -n "${SLACK_CHANNEL}" ]; then
    curl \
      --data "token=${SLACK_TOKEN}&channel=#${SLACK_CHANNEL}&text=${1}&username=${username}&icon_emoji=:ameelio_blue:" \
      'https://slack.com/api/chat.postMessage'
    echo # add a new-line to the output so it's easier to read the logs
  fi
}

notify_migration_start ()
{
  send_slack_message ":hourglass:  ${ENV} migration of release ${RELEASE_VERSION} started for ${GITHUB_REPOSITORY} by ${GITHUB_ACTOR}.  To see details: $(get_gh_link)"
}

notify_deploy_start ()
{
  send_slack_message ":hourglass:  ${ENV} deploy of release ${RELEASE_VERSION} started for ${GITHUB_REPOSITORY} by ${GITHUB_ACTOR}.  To see details: $(get_gh_link)"
}

notify_migration_fail ()
{

  send_slack_message ":x:  ${ENV} migration of release ${RELEASE_VERSION} for ${GITHUB_REPOSITORY} by ${GITHUB_ACTOR} has FAILED!.  To see details: $(get_gh_link)"
}

notify_deploy_fail ()
{
  send_slack_message ":x:  ${ENV} deploy of release ${RELEASE_VERSION} for ${GITHUB_REPOSITORY} by $GITHUB_ACTOR has FAILED!.  To see details: $(get_gh_link)"
}

notify_deploy_complete ()
{
  send_slack_message ":white_check_mark:  ${ENV} deploy of release ${RELEASE_VERSION} for ${GITHUB_REPOSITORY} by ${GITHUB_ACTOR} has completed successfully.  To see details: $(get_gh_link)"
}

main ()
{
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        print_usage_and_exit
        ;;

      -l|--save-apply-all)
        SAVE_MIGRATION='Yes'
        SAVE_DEPLOY='Yes'
        APPLY_MIGRATION='Yes'
        APPLY_DEPLOY='Yes'
        shift
        ;;

      -s|--save-all)
        SAVE_MIGRATION='Yes'
        SAVE_DEPLOY='Yes'
        shift
        ;;

      --save-migration)
        SAVE_MIGRATION='Yes'
        shift
        ;;

      --save-deploy)
        SAVE_DEPLOY='Yes'
        shift
        ;;

      -d|--diff-all)
        export DIFF_MIGRATION='Yes'
        export DIFF_DEPLOY='Yes'
        shift
        ;;

      --diff-migration)
        export DIFF_MIGRATION='Yes'
        shift
        ;;

      --diff-deploy)
        export DIFF_DEPLOY='Yes'
        shift
        ;;

      -a|--apply-all)
        export DIFF_MIGRATION='Yes'
        export DIFF_DEPLOY='Yes'
        export APPLY_MIGRATION='Yes'
        export APPLY_DEPLOY='Yes'
        shift
        ;;

      --apply-migration)
        export DIFF_MIGRATION='Yes'
        export APPLY_MIGRATION='Yes'
        shift
        ;;

      --apply-deploy)
        export DIFF_DEPLOY='Yes'
        export APPLY_DEPLOY='Yes'
        shift
        ;;

      -f|--force)
        export FORCE='Yes'
        shift
        ;;

      -t|--timeout-secs)
        export MIGRATION_TIMEOUT_SECS="$2"
        export DEPLOY_TIMEOUT_SECS="$2"
        shift
        shift
        ;;

      --migration-timeout-secs)
        export MIGRATION_TIMEOUT_SECS="$2"
        shift
        shift
        ;;

      --deploy-timeout-secs)
        export DEPLOY_TIMEOUT_SECS="$2"
        shift
        shift
        ;;

      -m|--manifest-dir)
        export MANIFEST_DIR="$2"
        shift
        shift
        ;;

      --debug)
        export DEBUG='Yes'
        shift
        ;;

      -e|--env)
        export ENV="$2"
        shift
        shift
        ;;

      -k|--k8s-server)
        export K8S_SERVER="$2"
        shift
        shift
        ;;

      -r|--release-ver)
        export RELEASE_VERSION="$2"
        shift
        shift
        ;;

      --k8s-token)
        export K8S_TOKEN="$2"
        shift
        shift
        ;;

      *)
        # We've got incorrect flags or missing args or something else went wrong
        print_usage_and_exit
        ;;
    esac
  done

  if [ -z "$SAVE_MIGRATION" ] \
    && [ -z "$SAVE_DEPLOY" ] \
    && [ -z "$DIFF_MIGRATION" ] \
    && [ -z "$DIFF_DEPLOY" ] \
    && [ -z "$APPLY_MIGRATION" ] \
    && [ -z "$APPLY_DEPLOY" ]
  then
    print_usage
    die "All actions are empty!  Pass flags such as --save-all or --apply-all" "${EXIT_USAGE}"
  fi

  if is_debug; then
    debug ""
    debug "  Actions:"
    debug "---------------------------------------------"
    debug "  SAVE_MIGRATION:  '${SAVE_MIGRATION}'"
    debug "  SAVE_DEPLOY:     '${SAVE_DEPLOY}'"
    debug "  DIFF_MIGRATION:  '${DIFF_MIGRATION}'"
    debug "  DIFF_DEPLOY:     '${DIFF_DEPLOY}'"
    debug "  APPLY_MIGRATION: '${APPLY_MIGRATION}'"
    debug "  APPLY_DEPLOY:    '${APPLY_DEPLOY}'"
    debug ""
    debug "  Configuration:"
    debug "---------------------------------------------"
    debug "  MIGRATION_TIMEOUT_SECS: '${MIGRATION_TIMEOUT_SECS}'"
    debug "  DEPLOY_TIMEOUT_SECS: '${DEPLOY_TIMEOUT_SECS}'"
    debug "  MANIFEST_DIR:     '${MANIFEST_DIR}'"
    debug "  FORCE:            '${FORCE}'"
    debug "  DEBUG:            '${DEBUG}'"
    debug "  ENV:              '${ENV}'"
    debug "  RELEASE_VERSION:  '${RELEASE_VERSION}'"
    debug "  K8S_SERVER:       '${K8S_SERVER}'"
    debug "  K8S_TOKEN:        '$(sanitize ${K8S_TOKEN})'"
    debug ""
  fi

  check_required_vars

  if [ -z "${MANIFEST_DIR}" ]; then
    MANIFEST_DIR="manifests-${RELEASE_VERSION}-${ENV}"
    debug "MANIFEST_DIR not set.  setting to default of '${MANIFEST_DIR}'"
  fi

  check_env_exists
  check_dir_for_files

  debug 'Creating directory to save manifests to'
  mkdir -p "${MANIFEST_DIR}"

  if is_enabled "${SAVE_MIGRATION}"; then
    generate_migration_manifest
  fi

  if is_enabled "${SAVE_DEPLOY}"; then
    generate_deploy_manifest
    generate_config_manifest
  fi

  if is_enabled "${DIFF_MIGRATION}" || is_enabled "${APPLY_MIGRATION}"; then
    check_for_migration_manifest
    delete_old_migration_job_if_exist
    diff_migration_manifest
    local migration_diff_exit=$?
    # Exit status of diff_migration_manifest:
    #   0 - No differences were found.
    #   1 - Differences were found.
    #  >1 - Kubectl or diff failed with an error.
    if is_enabled "${APPLY_MIGRATION}"; then
      if [ "${migration_diff_exit}" = "0" ] || [ "${migration_diff_exit}" = "1" ] || is_force; then
        log "Migration diff exited with success.  Exit code '${migration_diff_exit}'"
        apply_and_wait_migration_manifest
      else
        log "Migration diff failed!  Check K8s config yaml and try again"
        if is_force; then
          log "Force is set!  Applying migration anyway"
          apply_and_wait_migration_manifest
        fi
      fi
    else
      log "Diff was enabled for migration but apply was not.  Skipping Apply on migration"
    fi
  fi

  if is_enabled "${DIFF_DEPLOY}" || is_enabled "${APPLY_DEPLOY}"; then
    check_for_deploy_manifest
    verify_namespace_is_set
    diff_deploy_manifest
    local deploy_diff_exit=$?
    # Exit status of diff_deploy_manifest:
    #   0 - No differences were found.
    #   1 - Differences were found.
    #  >1 - Kubectl or diff failed with an error.
    if is_enabled "${APPLY_DEPLOY}"; then
      if [ "${deploy_diff_exit}" = "0" ] || [ "${deploy_diff_exit}" = "1" ] || is_force; then
        log "Deployment diff exited with success.  Exit code '${deploy_diff_exit}'"
        apply_and_wait_deployment_manifest
      else
        log "Deployment diff failed!  Check K8s config yaml and try again"
        if is_force; then
          log "Force is set!  Applying deploy anyway"
          apply_and_wait_deployment_manifest
        fi
      fi
    else
      log "Diff was enabled for deployment but apply was not.  Skipping Apply on deployment"
    fi
  fi
}

# Only run main when executed directly, so unit tests can source this file
# to call individual helpers without invoking the full pipeline.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
