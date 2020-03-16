#:title:        Divine deployment: primer-ssh
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2020.03.16
#:revremark:    Remove dtrim from ssh primer
#:created_at:   2019.06.30

D_DPL_NAME='primer-ssh'
D_DPL_DESC='[Install-only] Storage and retrieval of ssh keys to/from encrypted can'
D_DPL_PRIORITY=5000
D_DPL_FLAGS=!
D_DPL_WARNING=
D_DPL_OS=( any )

# Storage variables (defined here merely as table of content)
D_PRIMER_CFG_FILEPATH="$D__DPL_ASSET_DIR/$D_DPL_NAME.cfg.sh"
D_GPG_CMD=
D_SSH_CMD=

d_dpl_check()
{
  # Detect gnupg executable
  if gpg2 --version &>/dev/null; then D_GPG_CMD=gpg2
  elif gpg --version &>/dev/null; then D_GPG_CMD=gpg
  elif gpg1 --version &>/dev/null; then D_GPG_CMD=gpg1
  else
    d__notify -ls -- 'GnuPG executable not found (used for can file encryption)'
    return 3
  fi

  # Detect ssh executable
  if ssh -V &>/dev/null; then D_SSH_CMD=ssh
  else
    d__notify -ls -- 'SSH executable not found'
    return 3
  fi

  # Check if cfg file is available
  [ -r "$D_PRIMER_CFG_FILEPATH" -a -f "$D_PRIMER_CFG_FILEPATH" ] || {
    d__notify -ls -- 'Configuration file is not readable at:' \
      -i- "$D_PRIMER_CFG_FILEPATH"
    return 3
  }

  # Source cfg file
  source "$D_PRIMER_CFG_FILEPATH"

  # Check if can path is provided
  [ -n "$D_SSH_CAN_LOCATION" ] || {
    d__notify -ls -- 'Can path not provided ($D_SSH_CAN_LOCATION)'
    return 3
  }

  # Check if can path is for some reason a directory (not acceptable)
  [ -d "$D_SSH_CAN_LOCATION" ] && {
    d__notify -ls -- 'Path to can file is a directory:' \
      -i- "$D_SSH_CAN_LOCATION"
    return 3
  }

  # Check if SSH directory is provided
  [ -n "$D_SSH_DIR" ] || {
    d__notify -ls -- 'Path to SSH working directory not provided ($D_SSH_DIR)'
    return 3
  }

  # SSH directory checks
  [ -d "$D_SSH_DIR" ] && {

    # Extract true path of it
    local ssh_dir_true_path
    ssh_dir_true_path="$( cd -- "$D_SSH_DIR" && pwd -P || exit $?)"

    # Check if trick worked
    [ $? -eq 0 ] || {
      d__notify -ls -- 'SSH working directory is inaccessible'
      return 3
    }

    # Check if SSH working directory is root (not acceptable)
    [[ $ssh_dir_true_path == '/' ]] && {
      d__notify -ls -- 'SSH working directory is root (not acceptable)'
      return 3
    }

  }

  # Check if SSH directory exists and is not a dir (not acceptable)
  [ -e "$D_SSH_DIR" -a ! -d "$D_SSH_DIR" ] && {
    d__notify -ls -- 'Path to SSH working directory is not a directory:' \
      -i- "$D_SSH_DIR"
    return 3
  }

  # Check if parent path of SSH directory is a writable directory
  local ssh_dir_parent
  ssh_dir_parent="$( dirname -- "$D_SSH_DIR" )"
  [ -d "$ssh_dir_parent" -a -w "$ssh_dir_parent" ] || {
    d__notify -ls -- 'SSH directory is located in non-writable directory:' \
      -i "$ssh_dir_parent"
    return 3
  }

  # Make no assumptions about installation status
  return 0
}

d_dpl_install()
{
  # Array of available routines
  local routines_available=()

  # Print status and assemble available routines along the way
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Working with:'
  printf >&2 '%s: %s (%s)\n' \
    'GnuPG version  ' \
    "${BOLD}$( $D_GPG_CMD --version | head -1 )${NORMAL}" \
    "$( command -v $D_GPG_CMD )"
  printf >&2 '%s: %s (%s)\n' \
    'SSH version    ' \
    "${BOLD}$( $D_SSH_CMD -V 2>&1 | head -1 )${NORMAL}" \
    "$( command -v $D_SSH_CMD )"

  # Checks on SSH directory
  printf >&2 '%s: %s\n' \
    'SSH dir        ' \
    "${BOLD}${D_SSH_DIR}${NORMAL}"
  # Check if ssh directory exists and is not empty
  if [ -n "$( ls -A "$D_SSH_DIR" 2>/dev/null )" ]; then
    # ssh directory exists and is not empty
    printf >&2 '%s: %s\n' 'SSH dir status ' 'exists and contains files'
    # Assemble tasks for working with it
    routines_available+=( d_task__pack_into_can )
    routines_available+=( d_task__erase_ssh_dir )
  else
    # ssh directory either does not exist or empty
    [ -d "$D_SSH_DIR" ] \
      && printf >&2 '%s: %s\n' 'SSH dir status ' 'empty' \
      || printf >&2 '%s: %s\n' 'SSH dir status ' \
        "does ${BOLD}not${NORMAL} yet exist"
  fi

  # Checks on can file
  printf >&2 '%s: %s\n' \
    'Can file       ' \
    "${BOLD}${D_SSH_CAN_LOCATION}${NORMAL}"
  # Check if can file exists
  if [ -r "$D_SSH_CAN_LOCATION" ]; then
    # Can file exists
    printf >&2 '%s: %s\n\n' 'Can status     ' 'exists'
    # Assemble tasks for working with it
    routines_available+=( d_task__extract_from_can )
  else
    # Can file does not exist
    printf >&2 '%s: %s\n\n' 'Can status     ' \
      "does ${BOLD}not${NORMAL} yet exist"
  fi
    
  # Offer to do nothing
  routines_available+=( d_task__do_nothing )

  # List available tasks
  printf >&2 '%s %s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Choose routine to perform:'
  local i
  for (( i=0; i<${#routines_available[@]}; i++ )); do
    # Print title
    printf '%s %s\n' \
      "${BOLD}($(( i+1 )))${NORMAL}" \
      "${BOLD}$( ${routines_available[$i]} --title )${NORMAL}"

    # Print description
    ${routines_available[$i]} --desc

    # Print separating newline
    printf '\n'
  done

  # Prompt for choice
  local input
  printf '%s %s ' 'Your choice' "[1-${#routines_available[@]}]:"
  while true; do
    read -rsn1 input
    if [[ $input =~ ^[0-9]$ ]]; then
      (( input>=1 && input<=${#routines_available[@]} )) \
        && { printf '%s' "$input"; (( input-- )); break; }
    fi
  done
  printf '\n'

  # Store task title
  local task_title
  task_title="$( ${routines_available[$input]} --title )"

  # Announce selected routine
  printf >&2 '\n%s %s\n' "${BOLD}${GREEN}==>${NORMAL}" \
    'Commencing task:'
  printf >&2 '  %s\n' "$task_title"

  # Execute routine
  ${routines_available[$input]}

  # Check if main task has been completed
  case $? in
    0)
      printf >&2 '\n%s %s\n' "${BOLD}${GREEN}==>${NORMAL}" \
        'Task completed successfully:'
      printf >&2 '  %s\n\n' "$task_title"
      return 0
      ;;
    1)
      printf >&2 '\n%s %s\n' "${BOLD}${RED}==>${NORMAL}" \
        'Task failed:'
      printf >&2 '  %s\n\n' "$task_title"
      return 1
      ;;
    2)
      printf >&2 '\n%s %s\n\n' "${BOLD}${WHITE}==>${NORMAL}" \
        'Come back when you grow a pair'
      return 2
      ;;
    3)
      printf >&2 '\n%s %s\n' "${BOLD}${WHITE}==>${NORMAL}" \
        'Task aborted:'
      printf >&2 '  %s\n\n' "$task_title"
      return 2
      ;;
  esac
}

d_dpl_remove()
{
  d__notify -ls -- 'This deployment is install-only'
  return 2
}

d_task__extract_from_can()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' 'Extract all SSH data from can file'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Pre-erase directory '$D_SSH_DIR';
    Decrypt can file and put all its content in '$D_SSH_DIR'.
EOF
    return 0
  }

  # Perform sub-tasks in sequence; bail out on first failure
  d_subtask__erase_ssh_dir \
    && d_subtask__extract_from_can
}

d_task__pack_into_can()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' 'Package all SSH data into can file'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Encrypt content of '$D_SSH_DIR' into can file;
    Overwrite existing can file.
EOF
    return 0
  }

  # Perform sub-task
  d_subtask__pack_into_can
}

d_task__erase_ssh_dir()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' \
      'Erase SSH directory'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Erase directory '$D_SSH_DIR' ${BOLD}WITHOUT BACKING UP${NORMAL}.
EOF
    return 0
  }

  # Perform sub-task
  d_subtask__erase_ssh_dir
}

d_task__do_nothing()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' \
      'Do nothing'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Pussy option.
EOF
    return 0
  }

  # Return status of the main routine (skip status)
  return 2
}

d_subtask__erase_ssh_dir()
{
  # Check if there is anything to erase
  if [ ! -e "$D_SSH_DIR" ]; then
    # All good
    return 0
  fi

  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Erasing SSH directory at:'
  printf >&2 '  %s\n' "$D_SSH_DIR"

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='erasing of SSH dir'
  next_up "$prompt_desc" || return $?

  rm -rf -- "$D_SSH_DIR" || {
    # Report failure and return
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to erase SSH directory at'
    printf >&2 '  %s\n' "$D_SSH_DIR"
    return 1
  }

  # Report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully erased SSH directory at:'
  printf >&2 '  %s\n' "$D_SSH_DIR"
}

d_subtask__extract_from_can()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Unpacking can file at:'
  printf >&2 '  %s\n' "$D_SSH_CAN_LOCATION"
  printf >&2 '%s\n' 'to SSH directory at:'
  printf >&2 '  %s\n' "$D_SSH_DIR"

  # Ensure can file is readable
  [ -r "$D_SSH_CAN_LOCATION" ] || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Can file is missing/unreadable'
    return 1
  }

  # Ensure tar is available
  tar --version &>/dev/null || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'tar executable not found'
    return 1
  }

  # Create SSH directory
  mkdir -p -- "$D_SSH_DIR" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to create fresh SSH directory'
    return 1
  }

  # Change permissions on SSH directory
  chmod 0700 "$D_SSH_DIR" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to change permissions of SSH directory'
    return 1
  }

  # Storage variables
  local gpg_opts=() can_name

  # Extract can name
  can_name="$( basename -- "$D_SSH_CAN_LOCATION" )"

  # Populate gpg options
  # Don't cache passphrase (relevant for gpg2 only)
  $D_GPG_CMD --no-symkey-cache --version &>/dev/null \
    && gpg_opts+=(--no-symkey-cache)
  # Other options
  gpg_opts+=( \
    --quiet \
    --cipher-algo AES256 \
    --decrypt "$D_SSH_CAN_LOCATION" \
  )

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='can file passphrase (current)'
  next_up "$prompt_desc" || return $?

  # Carry out command
  $D_GPG_CMD "${gpg_opts[@]}" 2>/dev/null \
    | tar -C "$D_SSH_DIR" -xf -
  
  # Check status
  [ $? -eq 0 ] || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Failed to decrypt and untar can file '$can_name'"
    return 1
  }

  # Report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully unpacked can file at:'
  printf >&2 '  %s\n' "$D_SSH_CAN_LOCATION"
  printf >&2 '%s\n' 'to SSH directory at:'
  printf >&2 '  %s\n' "$D_SSH_DIR"
}

d_subtask__pack_into_can()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Packing content of SSH directory at:'
  printf >&2 '  %s\n' "$D_SSH_DIR"
  printf >&2 '%s\n' 'into can file at:'
  printf >&2 '  %s\n' "$D_SSH_CAN_LOCATION"

  # Ensure tar is available
  tar --version &>/dev/null || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'tar executable not found'
  }

  # Ensure sed is available
  command -v sed &>/dev/null || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'sed executable not found'
  }

  # Ensure find is available
  command -v find &>/dev/null || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'find executable not found'
  }

  # Ensure grep is available
  command -v grep &>/dev/null || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'grep executable not found'
  }

  # Check that SSH directory exists and is not empty
  [ -d "$D_SSH_DIR" -a -n "$( ls -A "$D_SSH_DIR" )" ] || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Missing or empty SSH directory at:'
    printf >&2 '  %s\n' "$D_SSH_DIR"
    return 1
  }

  # Check if any of the files in SSH directory contain '|' in their path
  # (This is a no-go for sed command to be used in further step)
  grep -q '|' < <( find "$D_SSH_DIR" -mindepth 1 ) && {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Some files in SSH directory contain '|' (vertical bar) in their path"
    printf >&2 '%s\n' 'Unfortunately, that is not supported'
    return 1
  }

  # Check if can file already exists
  if [ -e "$D_SSH_CAN_LOCATION" ]; then

    # User approval required

    # Prompt user if they are willing to overwrite
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Can file already exists at:" \
      "$D_SSH_CAN_LOCATION"

    # Prompt user
    dprompt 'Overwrite?' || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${WHITE}==>${NORMAL}" \
        "Aborting task"
      return 3
    }

  else

    # Can file does not exist, parent directory might not either

    # Extract can's parent directory
    local can_parent_dir
    can_parent_dir=$( dirname -- "$D_SSH_CAN_LOCATION" )

    # Check if parent path is a readable directory
    [ -d "$can_parent_dir" -a -r "$can_parent_dir" ] || {

      # Attempt to create parent path, or kill routine
      mkdir -p -- "$can_parent_dir" || {
        printf >&2 '\n%s %s\n  %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to create can file parent directory at:" \
          "$can_parent_dir"
        return 1
      }

    }

  fi

  # Storage variables
  local gpg_opts=() can_name

  # Extract can name
  can_name="$( basename -- "$D_SSH_CAN_LOCATION" )"

  # Populate gpg options
  # Don't cache passphrase (relevant for gpg2 only)
  $D_GPG_CMD --no-symkey-cache --version &>/dev/null \
    && gpg_opts+=(--no-symkey-cache)
  # Don't add comments to output
  $D_GPG_CMD --no-comments --version &>/dev/null \
    && gpg_opts+=(--no-comments)
  $D_GPG_CMD --no-emit-version --version &>/dev/null \
    && gpg_opts+=(--no-emit-version)
  # Other options
  gpg_opts+=( \
    --quiet \
    --armor \
    --yes \
    --cipher-algo AES256 \
    --output "$D_SSH_CAN_LOCATION" \
    --symmetric \
  )

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='can file passphrase (new)'
  next_up "$prompt_desc" || return $?

  # Find, clean, tar, and encrypt, all in one pipeline
  find "$D_SSH_DIR" -mindepth 1 \
    | sed "s|^$D_SSH_DIR/||" \
    | xargs tar -C "$D_SSH_DIR" -cf - \
    | $D_GPG_CMD "${gpg_opts[@]}" 2>/dev/null
  
  # Check status
  [ $? -eq 0 ] || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Failed to find, clean, tar, and encrypt can file '$can_name'"
    return 1
  }

  # Report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully packed content of SSH directory at:'
  printf >&2 '  %s\n' "$D_SSH_DIR"
  printf >&2 '%s\n' 'into can file at:'
  printf >&2 '  %s\n' "$D_SSH_CAN_LOCATION"
}

next_up()
{
  # Extract message from arguments and trim it
  local msg="$*"

  # Early exit for empty message
  [ -n "$msg" ] || return 1

  # Warn user of next event
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "${BOLD}NEXT UP:${NORMAL}" \
    "${BOLD}${REVERSE} ${msg} ${NORMAL}"

  # Read response
  local input
  printf '%s' "${YELLOW}Press any key to continue (or 'q' to quit)${NORMAL}"
  read -rsn1 input && printf >&2 '\n'

  # Check response
  if [ "$input" = q ]; then
    printf >&2 '\n%s %s\n' \
      "${BOLD}${WHITE}==>${NORMAL}" \
      "Aborting task"
    return 3
  else
    return 0
  fi
}