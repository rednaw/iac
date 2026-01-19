#!/bin/bash
# Validates workspace argument and outputs workspace name if valid
# Usage: WORKSPACE=$(./validate-workspace.sh <namespace> <task-name> <args>)
# Example: WORKSPACE=$(./validate-workspace.sh terraform init "{{.CLI_ARGS}}")

NAMESPACE="$1"
TASK_NAME="$2"
CLI_ARGS="$3"

if [ -z "$CLI_ARGS" ]; then
  echo "❌ Error: Workspace required. Usage: task $NAMESPACE:$TASK_NAME -- <dev|prod>" >&2
  exit 1
fi

if [ "$CLI_ARGS" != "dev" ] && [ "$CLI_ARGS" != "prod" ]; then
  echo "❌ Error: Invalid workspace '$CLI_ARGS'. Use: dev or prod" >&2
  exit 1
fi

echo "$CLI_ARGS"
