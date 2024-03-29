export PATH=$PATH:~/bin[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"





#!/usr/bin/env bash

# rvm : Ruby enVironment Manager
# https://rvm.io
# https://github.com/wayneeseguin/rvm

# Do not allow sourcing RVM in `sh` - it's not supported
# return 0 to exit from sourcing this script without breaking sh
[[ ":$SHELLOPTS:" =~ ":posix:" ]] && return 0 || true

set +e

if [[ -n "$CDPATH" ]]; then
    rvm_stored_cdpath="$CDPATH"
    unset CDPATH
fi

# TODO: Alter the variable names to make sense
\export HOME rvm_prefix rvm_user_install_flag rvm_path
HOME="${HOME%%+(\/)}" # Remove trailing slashes if they exist on HOME

[[ -n "${rvm_stored_umask:-}" ]] || export rvm_stored_umask=$(umask)
if (( ${rvm_ignore_rvmrc:=0} == 0 ))
then
  rvm_rvmrc_files=("/etc/rvmrc" "$HOME/.rvmrc")
  if [[ -n "${rvm_prefix:-}" ]] && ! [[ "$HOME/.rvmrc" -ef "${rvm_prefix}/.rvmrc" ]]
     then rvm_rvmrc_files+=( "${rvm_prefix}/.rvmrc" )
  fi

  for rvmrc in "${rvm_rvmrc_files[@]}"
  do
    if [[ -f "$rvmrc" ]]
    then
      if GREP_OPTIONS="" \grep '^\s*rvm .*$' "$rvmrc" >/dev/null 2>&1
      then
        printf "%b" "
Error:
        $rvmrc is for rvm settings only.
        rvm CLI may NOT be called from within $rvmrc.
        Skipping the loading of $rvmrc"
        return 1
      else
        source "$rvmrc"
      fi
    fi
  done
  unset rvm_rvmrc_files
fi

# detect rvm_path if not set
if [[ -z "${rvm_path:-}" ]]
then
  if (( UID == 0 ))
  then
    if (( ${rvm_user_install_flag:-0} == 0 ))
    then
      rvm_user_install_flag=0
      rvm_prefix="/usr/local"
      rvm_path="${rvm_prefix}/rvm"
    else
      rvm_user_install_flag=1
      rvm_prefix="$HOME"
      rvm_path="${rvm_prefix}/.rvm"
    fi
  else
    if [[ -d "$HOME/.rvm" && -s "$HOME/.rvm/scripts/rvm" ]]
    then
      rvm_user_install_flag=1
      rvm_prefix="$HOME"
      rvm_path="${rvm_prefix}/.rvm"
    else
      rvm_user_install_flag=0
      rvm_prefix="/usr/local"
      rvm_path="${rvm_prefix}/rvm"
    fi
  fi
else
  # remove trailing slashes, btw. %%/ <- does not work as expected
  rvm_path="${rvm_path%%+(\/)}"
fi

# guess rvm_prefix if not set
if [[ -z "${rvm_prefix}" ]]
then
  rvm_prefix=$( dirname $rvm_path )
fi

# guess rvm_user_install_flag if not set
if [[ -z "${rvm_user_install_flag}" ]]
then
  if [[ "${rvm_prefix}" == "${HOME}" ]]
  then
    rvm_user_install_flag=1
  else
    rvm_user_install_flag=0
  fi
fi

export rvm_loaded_flag
if [[ -n "${BASH_VERSION:-}" || -n "${ZSH_VERSION:-}" ]] &&
  typeset -f rvm >/dev/null 2>&1
then
  rvm_loaded_flag=1
else
  rvm_loaded_flag=0
fi

if (( ${rvm_loaded_flag:=0} == 0 )) || (( ${rvm_reload_flag:=0} == 1 ))
then
  if [[ -n "${rvm_path}" && -d "$rvm_path" ]]
  then
    true ${rvm_scripts_path:="$rvm_path/scripts"}

    if [[ -f "$rvm_scripts_path/base" ]]
    then
      source "$rvm_scripts_path/base"
    else
      printf "%b" "WARNING:
      Could not source '$rvm_scripts_path/base' as file does not exist.
      RVM will likely not work as expected.\n"
    fi

    __rvm_ensure_is_a_function
    __rvm_setup

    export rvm_version
    rvm_version="$(cat "$rvm_path/VERSION") ($(cat "$rvm_path/RELEASE" 2>/dev/null))"

    alias rvm-restart="rvm_reload_flag=1 source '${rvm_scripts_path:-${rvm_path}/scripts}/rvm'"

    if ! builtin command -v ruby >/dev/null 2>&1 ||
      builtin command -v ruby | GREP_OPTIONS="" \grep -v "${rvm_path}" >/dev/null ||
      builtin command -v ruby | GREP_OPTIONS="" \grep "${rvm_path}/bin/ruby$" >/dev/null
    then
      if [[ -s "$rvm_environments_path/default" ]]
      then
        source "$rvm_environments_path/default"
      elif [[ -s "$rvm_path/environments/default" ]]
      then
        source "$rvm_path/environments/default"
      fi
    fi

    # Makes sure rvm_bin_path is in PATH atleast once.
    __rvm_conditionally_add_bin_path

    if (( ${rvm_reload_flag:=0} == 1 ))
    then
      [[ "${rvm_auto_reload_flag:-0}" == 2 ]] || printf "%b" 'RVM reloaded!\n'
      # make sure we clean env on reload
      __rvm_env_loaded=1
      unset __rvm_project_rvmrc_lock
    fi

    rvm_loaded_flag=1
  else
    printf "%b" "\n\$rvm_path ($rvm_path) does not exist."
  fi
  unset rvm_prefix_needs_trailing_slash rvm_gems_cache_path \
    rvm_gems_path rvm_project_rvmrc_default rvm_gemset_separator rvm_reload_flag
else
  source "${rvm_scripts_path:="$rvm_path/scripts"}/initialize"
  __rvm_setup
fi

if [[ -t 0 && ${rvm_project_rvmrc:-1} -gt 0 ]] &&
  rvm_is_a_shell_function no_warning &&
  ! __function_on_stack __rvm_project_rvmrc &&
  typeset -f __rvm_project_rvmrc >/dev/null 2>&1
then
  # Reload the rvmrc, use promptless ensuring shell processes does not
  # prompt if .rvmrc trust value is not stored.
  rvm_promptless=1 __rvm_project_rvmrc
  rvm_hook=after_cd
  source "${rvm_scripts_path:-${rvm_path}/scripts}/hook"
fi

__rvm_teardown

# Setting PATH for Python 3.3
# The orginal version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.3/bin:${PATH}"
export PATH
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# add ~/bin to $PATH
PATH=$PATH:~/bin
export PATH
