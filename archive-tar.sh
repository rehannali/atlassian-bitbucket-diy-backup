# -------------------------------------------------------------------------------------
# An archive strategy using Tar and Gzip
# -------------------------------------------------------------------------------------

check_command "tar"

function archive_backup {
    check_config_var "BITBUCKET_BACKUP_ARCHIVE_ROOT"
    check_config_var "INSTANCE_NAME"
    check_config_var "BITBUCKET_BACKUP_ROOT"

    mkdir -p "${BITBUCKET_BACKUP_ARCHIVE_ROOT}"
    BITBUCKET_BACKUP_ARCHIVE_NAME="${INSTANCE_NAME}-${TIMESTAMP}.tar.gz"
    run tar -czf "${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}" -C "${BITBUCKET_BACKUP_ROOT}" .
}

function prepare_restore_archive {
    BITBUCKET_BACKUP_ARCHIVE_NAME=$1

    if [ -z "${BITBUCKET_BACKUP_ARCHIVE_NAME}" ]; then
        print "Usage: $0 <backup-file-name>.tar.gz"
        if [ ! -d "${BITBUCKET_BACKUP_ARCHIVE_ROOT}" ]; then
            error "'${BITBUCKET_BACKUP_ARCHIVE_ROOT}' does not exist!"
        else
            available_backups
        fi
        exit 99
    fi

    if [ -f "${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}" ]; then
        # Archive name includes .tar.gz extension. It must be trimmed to make the snapshot compatible with other strategies
        BITBUCKET_BACKUP_ARCHIVE_NAME="$(echo "${BITBUCKET_BACKUP_ARCHIVE_NAME}" | sed -e 's/\.tar\.gz$//')"
    fi

    if [ ! -f "${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}.tar.gz" ]; then
        error "'${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}.tar.gz' does not exist!"
        available_backups
        exit 99
    fi

    # Check and create BITBUCKET_HOME
    if [ -e "${BITBUCKET_HOME}" ]; then
        bail "Cannot restore over existing contents of '${BITBUCKET_HOME}'. Please rename or delete this first."
    fi

    check_config_var "BITBUCKET_UID"
    check_config_var "BITBUCKET_GID"

    run mkdir -p "${BITBUCKET_HOME}"
    run chown "${BITBUCKET_UID}":"${BITBUCKET_GID}" "${BITBUCKET_HOME}"

    # Setup restore paths
    BITBUCKET_RESTORE_ROOT=$(mktemp -d /tmp/bitbucket.diy-restore.XXXXXX)
    BITBUCKET_RESTORE_DB="${BITBUCKET_RESTORE_ROOT}/bitbucket-db"
    BITBUCKET_RESTORE_HOME="${BITBUCKET_RESTORE_ROOT}/bitbucket-home"
}

function restore_archive {
    check_config_var "BITBUCKET_BACKUP_ARCHIVE_ROOT"
    check_var "BITBUCKET_BACKUP_ARCHIVE_NAME"
    check_var "BITBUCKET_RESTORE_ROOT"
    run tar -xzf "${BITBUCKET_BACKUP_ARCHIVE_ROOT}/${BITBUCKET_BACKUP_ARCHIVE_NAME}.tar.gz" -C "${BITBUCKET_RESTORE_ROOT}"
}

function cleanup_old_archives {
    # Cleanup of old backups is not currently implemented
    no_op
}

function available_backups {
    check_config_var "BITBUCKET_BACKUP_ARCHIVE_ROOT"
    print "Available backups:"
    ls "${BITBUCKET_BACKUP_ARCHIVE_ROOT}" | sed -e 's/\.tar\.gz$//g'
}
