#!/bin/bash
if [ -z "${FISCAL_KIT_ACCESS:-}" ] && command -v gh > /dev/null \
  && gh auth token --user byescaleira > /dev/null 2>&1; then
  export FISCAL_KIT_ACCESS=1
  export GIT_TERMINAL_PROMPT=0
  export GIT_CONFIG_COUNT=3
  export GIT_CONFIG_KEY_0=url.https://byescaleira@github.com/byescaleira/byescaleira-kit.insteadOf
  export GIT_CONFIG_VALUE_0=https://github.com/byescaleira/byescaleira-kit
  export GIT_CONFIG_KEY_1=credential.https://byescaleira@github.com.helper
  export GIT_CONFIG_VALUE_1=
  export GIT_CONFIG_KEY_2=credential.https://byescaleira@github.com.helper
  export GIT_CONFIG_VALUE_2='!f() { test "$1" = get || exit 0; echo username=byescaleira; printf password=; gh auth token --user byescaleira; }; f'
fi
kit_scm=(-scmProvider system)
