# select-recipe.sh - resolve the RECIPE knob of buildspec.yaml. SOURCED (`. ./select-recipe.sh`) from this folder in every phase.
#
# Author: Anton Alexander
#
#   RECIPE unset / empty (the default)  RECIPE_DIR=.               this folder's Dockerfile -> dynamo-vllm-efa:1.5.0-patched;
#                                                                  BASE / IMAGE / DOCKER_BUILD_ARGS stay exactly as the environment has them.
#   RECIPE=<sibling folder>             RECIPE_DIR=./<folder>      that folder's Dockerfile; its recipe.env is sourced and REPLACES
#                                       (e.g. 1.4.0-patched)       BASE / IMAGE / DOCKER_BUILD_ARGS with that recipe's own values.
#                                                                  REGISTRY, GATE_SEVERITY and MAX_HIGH are not recipe-specific and stay.
#   anything else                       exit 1 before any build:   not a plain sibling folder name, or no Dockerfile / recipe.env in it.
#
# Sourced, not executed: the resolved RECIPE_DIR (and the recipe.env values) must land in the calling phase's shell.
case "${RECIPE:-}" in
  "")
    RECIPE_DIR="." ;;
  .*|*[!A-Za-z0-9._-]*)
    echo "[recipe] RECIPE='${RECIPE}' is not a sibling folder name (letters, digits, . _ - only; no leading dot, no slash)"; exit 1 ;;
  *)
    RECIPE_DIR="./${RECIPE}"
    [ -f "${RECIPE_DIR}/Dockerfile" ] || { echo "[recipe] RECIPE='${RECIPE}': no ${RECIPE_DIR}/Dockerfile here ($(pwd))"; exit 1; }
    [ -f "${RECIPE_DIR}/recipe.env" ] || { echo "[recipe] RECIPE='${RECIPE}': no ${RECIPE_DIR}/recipe.env (BASE / IMAGE / DOCKER_BUILD_ARGS of that recipe)"; exit 1; }
    . "${RECIPE_DIR}/recipe.env" ;;
esac
echo "[recipe] RECIPE='${RECIPE:-}' -> ${RECIPE_DIR}  IMAGE=${IMAGE:-<unset>}  BASE=${BASE:-<unset>}  DOCKER_BUILD_ARGS='${DOCKER_BUILD_ARGS:-}'"
