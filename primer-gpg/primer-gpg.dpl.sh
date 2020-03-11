#:title:        Divine deployment: primer-gpg
#:author:       Grove Pyree
#:email:        grayarea@protonmail.ch
#:revdate:      2020.03.11
#:revremark:    Remove all calls to dtrim
#:created_at:   2019.06.30

D_DPL_NAME='primer-gpg'
D_DPL_DESC='[Install-only] Collection of GnuPG tasks for initial set-up'
D_DPL_PRIORITY=5000
D_DPL_FLAGS=!
D_DPL_WARNING=
D_DPL_OS=( any )

# Storage variables (defined here merely as table of content)
D_PRIMER_CFG_FILEPATH="$D__DPL_ASSET_DIR/$D_DPL_NAME.cfg.sh"
D_GPG_PUBKEY_FILENAME='key.pub.gpg'
D_GPG_SECKEY_FILENAME='key.sec.gpg'
D_GPG_CMD=
D_GPG_MAJOR_VERSION=
D_RAMDISK_DEV=
D_RAMDISK_DIR=
D_TEMP_GPG_DIR=
D_PRIMARY_GPG_DIR=

d_dpl_check()
{
  # Detect gnupg executable
  if gpg2 --version &>/dev/null; then D_GPG_CMD=gpg2
  elif gpg --version &>/dev/null; then D_GPG_CMD=gpg
  elif gpg1 --version &>/dev/null; then D_GPG_CMD=gpg1
  else
    d__notify -ls -- 'GnuPG executable not found'
    return 3
  fi

  # Detect gnupg major version
  D_GPG_MAJOR_VERSION="$( \
    $D_GPG_CMD --version | head -1 | awk '{ print $3 }' \
  )"
  D_GPG_MAJOR_VERSION="${D_GPG_MAJOR_VERSION:0:1}"
  
  # Check if major version is detected correctly
  [[ $D_GPG_MAJOR_VERSION =~ ^[0-9]$ ]] || {
    d__notify -ls -- 'Failed to detect GnuPG version'
    return 3
  }

  # Check if major version is supported
  [ "$D_GPG_MAJOR_VERSION" -eq 2 -o "$D_GPG_MAJOR_VERSION" -eq 1 ] || {
    d__notify -ls -- 'Detected version of GnuPG is not supported:' \
      "$D_GPG_MAJOR_VERSION"
    return 3
  }

  # Check if cfg file is available
  [ -r "$D_PRIMER_CFG_FILEPATH" -a -f "$D_PRIMER_CFG_FILEPATH" ] || {
    d__notify -ls -- 'Configuration file is not readable at:' \
      -i- "$D_PRIMER_CFG_FILEPATH"
    return 3
  }

  # Source cfg file
  source "$D_PRIMER_CFG_FILEPATH"

  # Check if can path is provided
  [ -n "$D_GPG_KEY_CAN_LOCATION" ] || {
    d__notify -ls -- 'Path to can file not provided ($D_GPG_KEY_CAN_LOCATION)'
    return 3
  }

  # Check if can path is for some reason a directory (not acceptable)
  [ -d "$D_GPG_KEY_CAN_LOCATION" ] && {
    d__notify -ls -- 'Path to can file is a directory:' \
      -i- "$D_GPG_KEY_CAN_LOCATION"
    return 3
  }

  # Check if uid is provided
  [ -n "$D_GPG_UID" ] || {
    d__notify -ls -- 'GnuPG UID not provided ($D_GPG_UID)'
    return 3
  }

  # Check if pub keyfile name is provided
  [ -n "$D_GPG_PUBKEY_FILENAME" ] || {
    d__notify -ls -- 'Public keyfile name not provided ($D_GPG_PUBKEY_FILENAME)'
    return 3
  }

  # Check if sec keyfile name is provided
  [ -n "$D_GPG_SECKEY_FILENAME" ] || {
    d__notify -ls -- 'Secret keyfile name not provided ($D_GPG_SECKEY_FILENAME)'
    return 3
  }

  # Populate location of primary GnuPG directory
  D_PRIMARY_GPG_DIR="$( $D_GPG_CMD --version | awk '$1=="Home:"' )"
  D_PRIMARY_GPG_DIR="${D_PRIMARY_GPG_DIR#'Home: '}"

  # Make no assumptions about installation status
  return 0
}

d_dpl_install()
{
  # Print status
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Working with:'
  printf >&2 '%s: %s\n' \
    'UID           ' \
    "${BOLD}${D_GPG_UID}${NORMAL}"
  printf >&2 '%s: %s (%s)\n' \
    'GnuPG version ' \
    "${BOLD}$( $D_GPG_CMD --version | head -1 )${NORMAL}" \
    "$( command -v $D_GPG_CMD )"
  printf >&2 '%s: %s\n' \
    'GnuPG homedir ' \
    "${BOLD}${D_PRIMARY_GPG_DIR}${NORMAL}"
  printf >&2 '%s: %s\n' \
    'Can file      ' \
    "${BOLD}${D_GPG_KEY_CAN_LOCATION}${NORMAL}"
    
  # Array of available routines
  local routines_available=()

  # Assemble available routines
  if [ -r "$D_GPG_KEY_CAN_LOCATION" ]; then

    # Can file exists
    printf >&2 '%s: %s\n\n' 'Can status    ' 'exists'

    # Assemble tasks for working with it
    routines_available+=( d_task__arm_gpg_with_pub )
    routines_available+=( d_task__arm_gpg_with_pub_and_sec )
    routines_available+=( d_task__arm_gpg_with_pub_and_ssb )
    routines_available+=( d_task__tinker_with_canned_keys )
  
  else

    # Can file does not exist
    printf >&2 '%s: %s\n\n' 'Can status    ' \
      "does ${BOLD}not${NORMAL} yet exist"
    
    # Assemble tasks for creating one
    routines_available+=( d_task__make_fresh_keys_for_can_file )

    # If full set of keys is present in current keyring, offer to can it
    if $D_GPG_CMD --list-keys "$D_GPG_UID" &>/dev/null \
      && $D_GPG_CMD --list-secret-keys "$D_GPG_UID" &>/dev/null \
      && ! grep -Fq 'sec#' < <( $D_GPG_CMD --list-secret-keys "$D_GPG_UID" ) \
      && ! grep -Fq 'ssb#' < <( $D_GPG_CMD --list-secret-keys "$D_GPG_UID" )
      then
        routines_available+=( d_task__can_current_keys )
    fi
  
  fi

  # If any of the keys are present in current keyring, offer to erase them
  if $D_GPG_CMD --list-keys "$D_GPG_UID" &>/dev/null \
    || $D_GPG_CMD --list-secret-keys "$D_GPG_UID" &>/dev/null; then
      routines_available+=( d_task__erase_current_keys )
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

d_task__arm_gpg_with_pub()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' 'Arm gpg with canned keys: public only'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Use volatile RAM disk for temporary files;
    Pre-erase any '$D_GPG_UID' keys currently in keyring.
EOF
    return 0
  }

  # Local failure marker
  local task_code=0

  # Perform sub-tasks in sequence; bail out on first failure
  d_subtask__create_ramdisk \
    && d_subtask__unpack_can_file_to_ramdisk \
    && d_subtask__make_temp_gpg_dir_on_ramdisk \
    && d_subtask__import_to_temp__pub \
    && d_subtask__confirm_multiple_keys_in_temp \
    && d_subtask__export_from_temp__pub \
    && d_subtask__confirm_multiple_keys_in_primary \
    && d_subtask__remove_all_keypairs_from_primary \
    && d_subtask__import_to_primary__pub \
    || task_code=$?

  # In all cases, attempt to clean up
  d_subtask__destroy_ramdisk

  # Return status of the main routine
  return $task_code
}

d_task__arm_gpg_with_pub_and_sec()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' 'Arm gpg with canned keys: public + secret (all)'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Use volatile RAM disk for temporary files;
    Pre-erase any '$D_GPG_UID' keys currently in keyring.
EOF
    return 0
  }

  # Local failure marker
  local task_code=0

  # Perform sub-tasks in sequence; bail out on first failure
  d_subtask__create_ramdisk \
    && d_subtask__unpack_can_file_to_ramdisk \
    && d_subtask__make_temp_gpg_dir_on_ramdisk \
    && d_subtask__import_to_temp__pub \
    && d_subtask__import_to_temp__sec \
      'secret key passphrase (canned)' \
    && d_subtask__confirm_multiple_keys_in_temp \
    && d_subtask__change_pass_in_temp \
      'secret key passphrase (canned -> new)' \
    && d_subtask__export_from_temp__pub \
    && d_subtask__export_from_temp__sec \
      'secret key passphrase (new)' \
    && d_subtask__confirm_multiple_keys_in_primary \
    && d_subtask__remove_all_keypairs_from_primary \
    && d_subtask__import_to_primary__pub \
    && d_subtask__import_to_primary__sec \
      'secret key passphrase (new)' \
    || task_code=$?

  # In all cases, attempt to clean up
  d_subtask__destroy_ramdisk

  # Return status of the main routine
  return $task_code
}

d_task__arm_gpg_with_pub_and_ssb()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' "Arm gpg with canned keys: public + secret (subkeys only)"
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Use volatile RAM disk for temporary files;
    Pre-erase any '$D_GPG_UID' keys currently in keyring.
EOF
    return 0
  }

  # Local failure marker
  local task_code=0

  # Perform sub-tasks in sequence; bail out on first failure
  d_subtask__create_ramdisk \
    && d_subtask__unpack_can_file_to_ramdisk \
    && d_subtask__make_temp_gpg_dir_on_ramdisk \
    && d_subtask__import_to_temp__pub \
    && d_subtask__import_to_temp__sec \
      'secret key passphrase (canned)' \
    && d_subtask__confirm_multiple_keys_in_temp \
    && d_subtask__change_pass_in_temp \
      'secret key passphrase (canned -> new)' \
    && d_subtask__export_from_temp__pub \
    && d_subtask__export_from_temp__ssb \
      'secret key passphrase (new)' \
    && d_subtask__confirm_multiple_keys_in_primary \
    && d_subtask__remove_all_keypairs_from_primary \
    && d_subtask__import_to_primary__pub \
    && d_subtask__import_to_primary__sec \
      'secret key passphrase (new)' \
    || task_code=$?

  # In all cases, attempt to clean up
  d_subtask__destroy_ramdisk

  # Return status of the main routine
  return $task_code
}

d_task__tinker_with_canned_keys()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' \
      'Tinker with canned keys'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Run '$D_GPG_CMD --edit-key' on canned keys extracted to volatile RAM disk;
    Repack edited keys back into can file afterward.
EOF
    return 0
  }

  # Local failure marker
  local task_code=0

  # Perform sub-tasks in sequence; bail out on first failure
  d_subtask__create_ramdisk \
    && d_subtask__unpack_can_file_to_ramdisk \
    && d_subtask__make_temp_gpg_dir_on_ramdisk \
    && d_subtask__import_to_temp__pub \
    && d_subtask__import_to_temp__sec \
      'secret key passphrase (canned)' \
    && d_subtask__confirm_multiple_keys_in_temp \
    && d_subtask__tinker_with_keypairs_in_temp \
    && d_subtask__export_from_temp__pub \
    && d_subtask__export_from_temp__sec \
      'secret key passphrase (canned)' \
    && d_subtask__pack_can_file_from_ramdisk \
    || task_code=$?

  # In all cases, attempt to clean up
  d_subtask__destroy_ramdisk

  # Return status of the main routine
  return $task_code
}

d_task__make_fresh_keys_for_can_file()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' \
      'Generate fresh keys for can file'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Run '$D_GPG_CMD --full-generate-key' inside volatile RAM disk;
    Run '$D_GPG_CMD --edit-key' on generated keys;
    Pack these keys into can file afterward.
EOF
    return 0
  }

  # Local failure marker
  local task_code=0

  # Perform sub-tasks in sequence; bail out on first failure
  d_subtask__create_ramdisk \
    && d_subtask__make_temp_gpg_dir_on_ramdisk \
    && d_subtask__create_fresh_keypair_in_temp \
    && d_subtask__tinker_with_keypairs_in_temp \
    && d_subtask__export_from_temp__pub \
    && d_subtask__export_from_temp__sec \
      'secret key passphrase (new)' \
    && d_subtask__pack_can_file_from_ramdisk \
    || task_code=$?

  # In all cases, attempt to clean up
  d_subtask__destroy_ramdisk

  # Return status of the main routine
  return $task_code
}

d_task__can_current_keys()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' \
      'Pack current keys into can file'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Use volatile RAM disk for temporary files;
    Pack all current keys for '$D_GPG_UID' into can file.
EOF
    return 0
  }

  # Local failure marker
  local task_code=0

  # Perform sub-tasks in sequence; bail out on first failure
  d_subtask__confirm_multiple_keys_in_primary \
    && d_subtask__create_ramdisk \
    && d_subtask__export_from_primary__pub \
    && d_subtask__export_from_primary__sec \
    && d_subtask__pack_can_file_from_ramdisk \
    || task_code=$?

  # In all cases, attempt to clean up
  d_subtask__destroy_ramdisk

  # Return status of the main routine
  return $task_code
}

d_task__erase_current_keys()
{
  # Special mode: print title and return
  [ "$1" = --title ] && {
    printf '%s\n' \
      'Erase current keys'
    return 0
  }

  # Special mode: print description and return
  [ "$1" = --desc ] && {
    cat <<EOF
    Erase all current keys for '$D_GPG_UID' ${BOLD}WITHOUT BACKING UP${NORMAL};
    Can file is not affected by this.
EOF
    return 0
  }

  # Perform sub-task
  d_subtask__confirm_multiple_keys_in_primary \
    && d_subtask__remove_all_keypairs_from_primary

  # Return status of the subtask
  return $?
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

d_subtask__create_ramdisk()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Creating RAM disk'

  # Check current OS and act accordingly
  case "$D__OS_FAMILY" in

    macos)
      # Generate unique-ish name for RAM disk
      local ramdisk_name="rd$$"

      # Attach 2 megabyte drive
      D_RAMDISK_DEV="$( hdiutil attach -nomount ram://4096 2>/dev/null )"
      [ $? -eq 0 ] || {
        printf >&2 '\n%s %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          'Failed to attach drive using hdiutil'
        return 1
      }

      # Erase that volume, format it to HFS+, and mount
      diskutil erasevolume hfs+ $ramdisk_name $D_RAMDISK_DEV &>/dev/null || {
        printf >&2 '\n%s %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to erase volume $D_RAMDISK_DEV"
        return 1
      }

      # Extract mount directory path
      D_RAMDISK_DIR="$( df | tail -1 | awk '{ print $9 }' )"
      ;;

    linux)
      # Under construction
      return 1
      ;;

    *)
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Current OS family is not supported'
      return 1
      ;;

  esac

  # Check if mount directory is present and readable
  [ -d "$D_RAMDISK_DIR" -a -r "$D_RAMDISK_DIR" ] || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Failed to properly mount RAM disk '$D_RAMDISK_DEV' to directory:"
    printf >&2 '  %s\n' "$D_RAMDISK_DIR"
    return 1
  }

  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully created RAM disk at:'
  printf >&2 '  %s\n' "$D_RAMDISK_DIR"
  return 0
}

d_subtask__unpack_can_file_to_ramdisk()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Unpacking can file at:'
  printf >&2 '  %s\n' "$D_GPG_KEY_CAN_LOCATION"
  printf >&2 '%s\n' 'to location at:'
  printf >&2 '  %s\n' "$D_RAMDISK_DIR"

  # Ensure can file is readable
  [ -r "$D_GPG_KEY_CAN_LOCATION" ] || {
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

  # Storage variables
  local gpg_opts=() can_name

  # Extract can name
  can_name="$( basename -- "$D_GPG_KEY_CAN_LOCATION" )"

  # Populate gpg options
  # Don't cache passphrase (relevant for gpg2 only)
  $D_GPG_CMD --no-symkey-cache --version &>/dev/null \
    && gpg_opts+=(--no-symkey-cache)
  # Other options
  gpg_opts+=( \
    --quiet \
    --cipher-algo AES256 \
    --decrypt "$D_GPG_KEY_CAN_LOCATION" \
  )

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='can file passphrase (current)'
  next_up "$prompt_desc" || return $?

  # Carry out command
  $D_GPG_CMD "${gpg_opts[@]}" >"$D_RAMDISK_DIR/$can_name" 2>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to decrypt can '$can_name'"
      return 1
    }

  # Untar files
  tar -C "$D_RAMDISK_DIR" -xf "$D_RAMDISK_DIR/$can_name" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Failed to untar '$can_name'"
    return 1
  }

  # Status variable
  local all_good=true

  # Check that appropriate files have been extracted
  local extracted_file
  extracted_file="$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
  [ -r "$extracted_file" -a -f "$extracted_file" ] || {
    all_good=false
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Missing file '$D_GPG_PUBKEY_FILENAME' in decrypted can"
  }
  extracted_file="$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
  [ -r "$extracted_file" -a -f "$extracted_file" ] || {
    all_good=false
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Missing file '$D_GPG_SECKEY_FILENAME' in decrypted can"
  }

  # Report
  if $all_good; then
    # Report success
    printf >&2 '\n%s %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      'Successfully unpacked can file at:'
    printf >&2 '  %s\n' "$D_GPG_KEY_CAN_LOCATION"
    printf >&2 '%s\n' 'to location at:'
    printf >&2 '  %s\n' "$D_RAMDISK_DIR"
    return 0
  else
    return 1
  fi
}

d_subtask__make_temp_gpg_dir_on_ramdisk()
{
  # Construct path to temporary GnuPG directory
  D_TEMP_GPG_DIR="$D_RAMDISK_DIR/.gnupg"

  # Create a temporary .gnupg directory
  mkdir -p "$D_TEMP_GPG_DIR" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to create directory at:'
    printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"
    return 1
  }

  # Ensure safe permissions of temporary dir
  chmod 0700 "$D_TEMP_GPG_DIR" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to change permissions of directory:'
    printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"
    return 1
  }
}

d_subtask__change_pass_in_temp()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Changing passphrase in temporary GnuPG directory at:'
  printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='secret key passphrase (current -> new)'
  next_up "$prompt_desc" || return $?

  # Change passphrase of secret keys
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --edit-key "$D_GPG_UID" passwd quit || {
      printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
        'Failed to change passphrase in temporary GnuPG directory'
      return 1
    }
  
  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully changed passphrase in temporary GnuPG directory at:'
  printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"
  return 0
}

d_subtask__confirm_multiple_keys_in_primary()
{
  # Storage variables
  local multiple_uids=false num_of_public_uids num_of_secret_uids

  # Check if any public keys are present
  if $D_GPG_CMD --list-keys "$D_GPG_UID" &>/dev/null; then

    # Count number of public UIDs
    num_of_public_uids="$( \
      awk '/^uid/{a++}END{print a}' \
      < <( $D_GPG_CMD --with-colons --fixed-list-mode \
        --list-keys "$D_GPG_UID" ) \
    )"

    # Check that number is counted correctly
    [[ "$num_of_public_uids" =~ ^[0-9]+$ ]] || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to count UIDs using public keys'
      return 1
    }

    # Check if multiple UIDs are detected
    [ "$num_of_public_uids" -gt 1 ] && multiple_uids=true
    
  fi

  # Check if any secret keys are present
  if $D_GPG_CMD --list-secret-keys "$D_GPG_UID" &>/dev/null; then

    # Count number of secret UIDs
    num_of_secret_uids="$( \
      awk '/^uid/{a++}END{print a}' \
      < <( $D_GPG_CMD --with-colons --fixed-list-mode \
        --list-secret-keys "$D_GPG_UID" ) \
    )"

    # Check that number is counted correctly
    [[ "$num_of_secret_uids" =~ ^[0-9]+$ ]] || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to count UIDs using secret keys'
      return 1
    }

    # Check if multiple UIDs are detected
    [ "$num_of_secret_uids" -gt 1 ] && multiple_uids=true

  fi

  # If multiple UIDs are detected, prompt user
  if $multiple_uids; then

    # Warn user of next event
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Multiple UIDs detected for '${BOLD}${D_GPG_UID}${NORMAL}'"
    printf >&2 '%s\n' \
      'in primary GnuPG directory at:'
    printf >&2 '  %s\n' \
      "$D_PRIMARY_GPG_DIR"

    # Prompt user
    printf '%s' "${YELLOW}Is this how you roll? [y/n] ${NORMAL}"

    # Wait for answer indefinitely (or until Ctrl-C)
    local input yes
    while true; do
      read -rsn1 input
      [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
      [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
    done
    printf '\n'

    # Check response
    $yes && return 0 || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'User refused to work with multiple UIDs'
      return 1
    }

  else

    # If no more than one UID, no questions
    return 0

  fi
}

d_subtask__confirm_multiple_keys_in_temp()
{
  # Storage variables
  local multiple_uids=false num_of_public_uids num_of_secret_uids

  # Check if any public keys are present
  if $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-keys "$D_GPG_UID" &>/dev/null; then

    # Count number of public UIDs
    num_of_public_uids="$( \
      awk '/^uid/{a++}END{print a}' \
      < <( $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" --with-colons \
        --fixed-list-mode --list-keys "$D_GPG_UID" ) \
    )"

    # Check that number is counted correctly
    [[ "$num_of_public_uids" =~ ^[0-9]+$ ]] || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to count UIDs using public keys'
      return 1
    }

    # Check if multiple UIDs are detected
    [ "$num_of_public_uids" -gt 1 ] && multiple_uids=true
    
  fi

  # Check if any secret keys are present
  if $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" &>/dev/null; then

    # Count number of secret UIDs
    num_of_secret_uids="$( \
      awk '/^uid/{a++}END{print a}' \
      < <( $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" --with-colons \
        --fixed-list-mode --list-secret-keys "$D_GPG_UID" ) \
    )"

    # Check that number is counted correctly
    [[ "$num_of_secret_uids" =~ ^[0-9]+$ ]] || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to count UIDs using secret keys'
      return 1
    }

    # Check if multiple UIDs are detected
    [ "$num_of_secret_uids" -gt 1 ] && multiple_uids=true

  fi

  # If multiple UIDs are detected, prompt user
  if $multiple_uids; then

    # Warn user of next event
    printf >&2 '\n%s %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Multiple UIDs detected for '${BOLD}${D_GPG_UID}${NORMAL}'"
    printf >&2 '%s\n' \
      'in temporary GnuPG directory at:'
    printf >&2 '  %s\n' \
      "$D_TEMP_GPG_DIR"

    # Prompt user
    printf '%s' "${YELLOW}Is this how you roll? [y/n] ${NORMAL}"

    # Wait for answer indefinitely (or until Ctrl-C)
    local imput yes
    while true; do
      read -rsn1 input
      [[ $input =~ ^(y|Y)$ ]] && { printf 'y'; yes=true;  break; }
      [[ $input =~ ^(n|N)$ ]] && { printf 'n'; yes=false; break; }
    done
    printf '\n'

    # Check response
    $yes && return 0 || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'User refused to work with multiple UIDs'
      return 1
    }

  else

    # If no more than one UID, no questions
    return 0

  fi
}

d_subtask__remove_all_keypairs_from_primary()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Removing all current keypairs for UID '$D_GPG_UID'"
  printf >&2 '%s\n' 'in primary GnuPG directory at:'
  printf >&2 '  %s\n' "$D_PRIMARY_GPG_DIR"

  # Status variable
  local anything_removed=false

  # Storage variables
  local lines line i last_keygrip key_fingerprint

  #
  # Remove secret keys
  #

  # Check if there are keys to remove and means to remove them
  if $D_GPG_CMD --list-secret-keys "$D_GPG_UID" &>/dev/null \
    && [ "$D_GPG_MAJOR_VERSION" -eq 2 ] \
    && gpg-connect-agent --version &>/dev/null; then

    # GnuPG v2
    # Delete using gpg-connect-agent "delete_key $KEYGRIP" /bye

    # Warn user of next prompt
    # (Optionally take description from caller)
    local prompt_desc="$1"; shift
    [ -n "$prompt_desc" ] || prompt_desc='secret key removal'
    next_up "$prompt_desc" || return $?

    # Get listing of gpg keys into an array
    lines=()
    while read line; do
      lines+=( "$line" )
    done < <( $D_GPG_CMD --with-colons --fixed-list-mode \
      --list-secret-keys "$D_GPG_UID" )

    # Iterate over array backward (remove keys last to first)
    for (( i=${#lines[@]}-1; i>=0; i-- )); do

      # Extract line contents
      line="${lines[$i]}"

      # Check type of current line
      if [[ $line =~ ^grp ]]; then

        # Store keygrip for future removal
        last_keygrip="$( awk -F: '{ print $10 }' <<<"$line" )"

      elif [[ $line =~ ^(ssb|sec) ]]; then

        # Check if keygrip has been previously stored
        [ -n "$last_keygrip" ] || {
          printf >&2 '\n%s %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            'Unable to remove key without keygrip'
          printf >&2 '%s\n' \
            "ID of key in question: $( awk -F: '{ print $5 }' <<<"$line" )"
          return 1
        }

        # Check if this key is present in keychain
        [ "$( awk -F: '{ print $15 }' <<<"$line" )" = '#' ] && {
          # Forget last keygrip
          last_keygrip=
          # Skip
          continue
        }

        # Attempt to remove this key
        gpg-connect-agent "delete_key $last_keygrip" /bye || {
          printf >&2 '\n%s %s\n' \
            "${BOLD}${RED}==>${NORMAL}" \
            "Failed to remove secret key from UID '$D_GPG_UID'"
          printf >&2 '%s\n' \
            "Keygrip of key in question: $last_keygrip"
          return 1
        }
      
        # Forget last keygrip
        last_keygrip=

        # Store status
        anything_removed=true

      fi

    # Done iterating over key listing
    done

    # Check if key removal succeeded
    $D_GPG_CMD --list-secret-keys "$D_GPG_UID" &>/dev/null && {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to remove all secret keys from UID '$D_GPG_UID'"
      return 1
    }

  elif $D_GPG_CMD --list-secret-keys "$D_GPG_UID" &>/dev/null \
    && [ "$D_GPG_MAJOR_VERSION" -eq 1 ]; then

    # GnuPG v1
    # No idea what to do yet

    printf >&2 '%s\n' 'Not yet implemepted'
    return 1

  fi

  #
  # Remove public keys
  #

  while $D_GPG_CMD --list-keys "$D_GPG_UID" &>/dev/null; do

    # Get listing of gpg keys
    while read line; do

      # Grab first fingerprint
      if [[ $line =~ ^fpr ]]; then

        # Extract fingerprint
        key_fingerprint="$( awk -F: '{ print $10 }' <<<"$line" )"
        
        # Attempt to delete key
        $D_GPG_CMD \
          --batch --yes --quiet \
          --delete-keys "$key_fingerprint" || {
            printf >&2 '\n%s %s\n' \
              "${BOLD}${RED}==>${NORMAL}" \
              "Failed to remove public key from UID '$D_GPG_UID'"
            printf >&2 '%s\n' \
              "Fingerprint of key in question: $key_fingerprint"
            return 1
          }
        
        # Forget fingerprint
        key_fingerprint=

        # Store status
        anything_removed=true

        # Removing first fingerprint must be enough
        break

      fi

    # Feed listing of public keys
    done < <( $D_GPG_CMD --with-colons --fixed-list-mode \
      --list-keys "$D_GPG_UID" )

  # Done removing all keys
  done

  # Report status and return
  if $anything_removed; then
    printf >&2 '\n%s %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      "Successfully removed all current keypairs for UID '$D_GPG_UID'"
    printf >&2 '%s\n' 'in primary GnuPG directory at:'
    printf >&2 '  %s\n' "$D_PRIMARY_GPG_DIR"
  else
    printf >&2 '\n%s %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      "Nothing to remove for UID '$D_GPG_UID'"
    printf >&2 '%s\n' 'in primary GnuPG directory at:'
    printf >&2 '  %s\n' "$D_PRIMARY_GPG_DIR"
  fi
  return 0
}

d_subtask__export_from_temp__pub()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Exporting all public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"

  # Check if public keys for uid exist
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "No public keys found for '$D_GPG_UID'"
      return 1
    }

  # Export public keys
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --output "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME" \
    --export "$D_GPG_UID" || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to export all public keys'
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully exported all public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
  return 0
}

d_subtask__export_from_temp__sec()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Exporting ${BOLD}all${NORMAL} secret keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"

  # Check if secret keys for uid exist
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "No secret keys found for '$D_GPG_UID'"
      return 1
    }
  
  # Check if primary secret key is present as well
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" \
    | grep -Fq 'sec#' && {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Primary secret key is missing for '$D_GPG_UID'"
      return 1
    }
  
  # Check if any of the secret keys is missing
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" \
    | grep -Fq 'ssb#' && {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "One of the secret subkeys is missing for '$D_GPG_UID'"
      return 1
    }

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='secret key passphrase (current)'
  next_up "$prompt_desc" || return $?
  
  # Export secret keys
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --output "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" \
    --export-secret-keys "$D_GPG_UID" || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to export ${BOLD}all${NORMAL} secret keys"
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully exported ${BOLD}all${NORMAL} secret keys" \
    "for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
  return 0
}

d_subtask__export_from_temp__ssb()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Exporting secret ${BOLD}sub${NORMAL}keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"

  # Check if secret keys for uid exist
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "No secret keys found for '$D_GPG_UID'"
      return 1
    }
  
  # Check if any of the secret keys is missing
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" \
    | grep -Fq 'ssb#' && {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "One of the secret subkeys is missing for '$D_GPG_UID'"
      return 1
    }

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='secret key passphrase (current)'
  next_up "$prompt_desc" || return $?
  
  # Export secret subkeys
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --output "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" \
    --export-secret-subkeys "$D_GPG_UID" || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to export secret ${BOLD}sub${NORMAL}keys"
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully exported secret ${BOLD}sub${NORMAL}keys" \
    "for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
  return 0
}

d_subtask__export_from_primary__pub()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Exporting all public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"

  # Check if public keys for uid exist
  $D_GPG_CMD \
    --list-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "No public keys found for '$D_GPG_UID'"
      return 1
    }

  # Export public keys
  $D_GPG_CMD \
    --output "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME" \
    --export "$D_GPG_UID" || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to export all public keys'
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully exported all public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
  return 0
}

d_subtask__export_from_primary__sec()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Exporting ${BOLD}all${NORMAL} secret keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"

  # Check if secret keys for uid exist
  $D_GPG_CMD \
    --list-secret-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "No secret keys found for '$D_GPG_UID'"
      return 1
    }
  
  # Check if primary secret key is present as well
  $D_GPG_CMD \
    --list-secret-keys "$D_GPG_UID" \
    | grep -Fq 'sec#' && {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Primary secret key is missing for '$D_GPG_UID'"
      return 1
    }

  # Check if any of the secret keys is missing
  $D_GPG_CMD \
    --list-secret-keys "$D_GPG_UID" \
    | grep -Fq 'ssb#' && {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "One of the secret subkeys is missing for '$D_GPG_UID'"
      return 1
    }

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='secret key passphrase (current)'
  next_up "$prompt_desc" || return $?
  
  # Export secret keys
  $D_GPG_CMD \
    --output "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" \
    --export-secret-keys "$D_GPG_UID" || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to export ${BOLD}all${NORMAL} secret keys"
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully exported ${BOLD}all${NORMAL} secret keys" \
    "for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
  return 0
}

d_subtask__export_from_primary__ssb()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Exporting secret ${BOLD}sub${NORMAL}keys for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"

  # Check if secret keys for uid exist
  $D_GPG_CMD \
    --list-secret-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "No secret keys found for '$D_GPG_UID'"
      return 1
    }
  
  # Check if any of the secret keys is missing
  $D_GPG_CMD \
    --list-secret-keys "$D_GPG_UID" \
    | grep -Fq 'ssb#' && {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "One of the secret subkeys is missing for '$D_GPG_UID'"
      return 1
    }

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='secret key passphrase (current)'
  next_up "$prompt_desc" || return $?
  
  # Export secret subkeys
  $D_GPG_CMD \
    --output "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" \
    --export-secret-subkeys "$D_GPG_UID" || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to export secret ${BOLD}sub${NORMAL}keys"
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully exported secret ${BOLD}sub${NORMAL}keys" \
    "for UID '$D_GPG_UID'"
  printf >&2 '  %s -> %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
  return 0
}

d_subtask__import_to_temp__pub()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Importing public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"

  # Import public keys
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --import "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to import public keys'
      return 1
    }
  
  # Check if public keys belong to correct uid
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Public keys from '$D_GPG_PUBKEY_FILENAME'"
        "do not belong to '$D_GPG_UID'"
      return 1
    }
  
  # Remove original storage file
  rm -f -- "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to remove temporary storage file at:'
    printf >&2 '  %s\n' \
      "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
    return 1
  }

  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully imported public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
}

d_subtask__import_to_temp__sec()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Importing secret keys for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='secret key passphrase (current)'
  next_up "$prompt_desc" || return $?

  # Import secret keys
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --import "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to import secret keys"
      return 1
    }
  
  # Check if secret keys belong to correct uid
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Secret keys from '$D_GPG_SECKEY_FILENAME'"
        "do not belong to '$D_GPG_UID'"
      return 1
    }
  
  # Remove original storage file
  rm -f -- "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to remove temporary storage file at:'
    printf >&2 '  %s\n' \
      "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
    return 1
  }

  # If made it here, report success
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully imported secret keys" \
    "for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_TEMP_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
}

d_subtask__import_to_primary__pub()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Importing public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"

  # Import public keys
  $D_GPG_CMD \
    --import "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to import public keys'
      return 1
    }
  
  # Check if public keys belong to correct uid
  $D_GPG_CMD \
    --list-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Public keys from '$D_GPG_PUBKEY_FILENAME'"
        "do not belong to '$D_GPG_UID'"
      return 1
    }
  
  # Remove original storage file
  rm -f -- "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to remove temporary storage file at:'
    printf >&2 '  %s\n' \
      "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
    return 1
  }

  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully imported public keys for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
}

d_subtask__import_to_primary__sec()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Importing secret keys for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='secret key passphrase (current)'
  next_up "$prompt_desc" || return $?

  # Import secret keys
  $D_GPG_CMD \
    --import "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to import secret keys"
      return 1
    }
  
  # Check if secret keys belong to correct uid
  $D_GPG_CMD \
    --list-secret-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Secret keys from '$D_GPG_SECKEY_FILENAME'"
        "do not belong to '$D_GPG_UID'"
      return 1
    }
  
  # Remove original storage file
  rm -f -- "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME" || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'Failed to remove temporary storage file at:'
    printf >&2 '  %s\n' \
      "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
    return 1
  }

  # If made it here, report success
  printf >&2 '\n%s %s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully imported secret keys" \
    "for UID '$D_GPG_UID'"
  printf >&2 '  %s <- %s\n' \
    "$D_PRIMARY_GPG_DIR" "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
}

d_subtask__create_fresh_keypair_in_temp()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Creating fresh keypair for UID '$D_GPG_UID'"
  printf >&2 '%s\n' 'in temporary GnuPG directory at:'
  printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"

  ## Make sure, can file does not already exist
  #
  ## Reasoning here: it's okey to overwrite can file when tinkering with 
  #. existing keys, but for new keypair, it's better to use new location, or at 
  #. least manually erase old one
  #
  [ -e "$D_GPG_KEY_CAN_LOCATION" ] && {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Can file already exists at:"
    printf >&2 '  %s\n' "$D_GPG_KEY_CAN_LOCATION"
    printf >&2 '%s\n' '(Use non-existent can file location for fresh keypair)'
    return 1
  }

  # Warn user of next prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='gpg --full-generate-key'
  next_up "$prompt_desc" || return $?

  # Create fresh keypair
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --full-generate-key || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Failed to create fresh keypair in temporary GnuPG directory'
      return 1
    }
  
  # Check if new public keys belong to correct uid
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Fresh public keys do not belong to UID '$D_GPG_UID'"
      return 1
    }

  # Check if new secret keys belong to correct uid
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --list-secret-keys "$D_GPG_UID" \
    &>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Fresh public keys do not belong to UID '$D_GPG_UID'"
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully created fresh keypair for UID '$D_GPG_UID'"
  printf >&2 '%s\n' 'in temporary GnuPG directory at:'
  printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"
  return 0
}

d_subtask__tinker_with_keypairs_in_temp()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    "Tinkering with current keypairs for UID '$D_GPG_UID'"
  printf >&2 '%s\n' 'in temporary GnuPG directory at:'
  printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"

  # Warn user of next prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='gpg --edit-key'
  next_up "$prompt_desc" || return $?

  # Tinker with keypairs
  $D_GPG_CMD --homedir "$D_TEMP_GPG_DIR" \
    --edit-key "$D_GPG_UID" || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${GREEN}==>${NORMAL}" \
        "Failed while tinkering with current keypairs for UID '$D_GPG_UID'"
      printf >&2 '%s\n' 'in temporary GnuPG directory at:'
      printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"
      return 1
    }
  
  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    "Successfully tinkered with current keypairs for UID '$D_GPG_UID'"
  printf >&2 '%s\n' 'in temporary GnuPG directory at:'
  printf >&2 '  %s\n' "$D_TEMP_GPG_DIR"
  return 0
}

d_subtask__pack_can_file_from_ramdisk()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Packing can file at:'
  printf >&2 '  %s\n' "$D_GPG_KEY_CAN_LOCATION"

  # Ensure tar is available
  tar --version &>/dev/null || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      'tar executable not found'
    return 1
  }

  # Check that appropriate files are present
  local extracted_file
  extracted_file="$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
  [ -r "$extracted_file" -a -f "$extracted_file" ] || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Missing file '$D_GPG_PUBKEY_FILENAME' at:"
    printf >&2 '  %s\n' "$D_RAMDISK_DIR/$D_GPG_PUBKEY_FILENAME"
    return 1
  }
  extracted_file="$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
  [ -r "$extracted_file" -a -f "$extracted_file" ] || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Missing file '$D_GPG_SECKEY_FILENAME' at:"
    printf >&2 '  %s\n' "$D_RAMDISK_DIR/$D_GPG_SECKEY_FILENAME"
    return 1
  }

  # Check if can file already exists
  if [ -e "$D_GPG_KEY_CAN_LOCATION" ]; then

    # User approval required

    # Prompt user if they are willing to overwrite
    printf >&2 '\n%s %s\n  %s\n' \
      "${BOLD}${YELLOW}==>${NORMAL}" \
      "Can file already exists at:" \
      "$D_GPG_KEY_CAN_LOCATION"

    # Prompt user
    d__prompt -p 'Overwrite?' || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${WHITE}==>${NORMAL}" \
        "Aborting task"
      return 3
    }

  else

    # Can file does not exist, parent directory might not either

    # Extract can's parent directory
    local can_parent_dir
    can_parent_dir=$( dirname -- "$D_GPG_KEY_CAN_LOCATION" )

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
  can_name="$( basename -- "$D_GPG_KEY_CAN_LOCATION" )"

  # Tar files
  tar -C "$D_RAMDISK_DIR" -cf "$D_RAMDISK_DIR/$can_name" \
    "$D_GPG_PUBKEY_FILENAME" \
    "$D_GPG_SECKEY_FILENAME" \
    || {
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "Failed to create tar file '$can_name' at:"
    printf >&2 '  %s\n' "$D_RAMDISK_DIR/$can_name"
    return 1
  }

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
    --output "$D_GPG_KEY_CAN_LOCATION" \
    --symmetric "$D_RAMDISK_DIR/$can_name" \
  )

  # Warn user of next passphrase prompt
  # (Optionally take description from caller)
  local prompt_desc="$1"; shift
  [ -n "$prompt_desc" ] || prompt_desc='can file passphrase (new)'
  next_up "$prompt_desc" || return $?

  # Carry out command
  $D_GPG_CMD "${gpg_opts[@]}" 2>/dev/null || {
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        "Failed to encrypt can '$can_name' at:"
      printf >&2 '  %s\n' "$D_GPG_KEY_CAN_LOCATION"
      return 1
    }

  # If made it here, report success
  printf >&2 '\n%s %s\n' \
    "${BOLD}${GREEN}==>${NORMAL}" \
    'Successfully packed can file at:'
  printf >&2 '  %s\n' "$D_GPG_KEY_CAN_LOCATION"
  return 0
}

d_subtask__destroy_ramdisk()
{
  # Report start
  printf >&2 '\n%s %s\n' \
    "${BOLD}${YELLOW}==>${NORMAL}" \
    'Destroying RAM disk at:'
  printf >&2 '  %s\n' "$D_RAMDISK_DIR"

  # Status variable
  local all_good=true

  # Check current OS and act accordingly
  case "$D__OS_FAMILY" in

    macos)
      # Unmount ramdisk directory
      diskutil umount force "$D_RAMDISK_DIR" &>/dev/null || {
        all_good=false
        printf >&2 '\n%s %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to unmount directory: $D_RAMDISK_DIR"
      }
      # Detach drive
      hdiutil detach $D_RAMDISK_DEV &>/dev/null || {
        all_good=false
        printf >&2 '\n%s %s\n' \
          "${BOLD}${RED}==>${NORMAL}" \
          "Failed to detach drive: $D_RAMDISK_DEV"
      }
      ;;

    linux)
      # Under construction
      return 1
      ;;

    *)
      printf >&2 '\n%s %s\n' \
        "${BOLD}${RED}==>${NORMAL}" \
        'Current OS family is not supported'
      return 1
      ;;

  esac

  # Call attention to any errors
  if $all_good; then
    printf >&2 '\n%s %s\n' \
      "${BOLD}${GREEN}==>${NORMAL}" \
      'Successfully destroyed RAM disk at:'
    printf >&2 '  %s\n' "$D_RAMDISK_DIR"
    return 0
  else
    # RAM disk is not properly destroyed, recommend reboot
    printf >&2 '\n%s %s\n' \
      "${BOLD}${RED}==>${NORMAL}" \
      "RAM clean-up failed. Please, consider ${BOLD}rebooting${NORMAL}."
    return 1
  fi
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