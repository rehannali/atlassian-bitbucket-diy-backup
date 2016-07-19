#!/bin/bash

# -------------------------------------------------------------------------------------
# A backup and restore strategy for Amazon EBS
# -------------------------------------------------------------------------------------

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/aws-common.sh"
source "${SCRIPT_DIR}/common.sh"

function prepare_backup_home {
    # Validate that all the configuration parameters have been provided to avoid bailing out and leaving Bitbucket locked
    if [ -z "${HOME_DIRECTORY_MOUNT_POINT}" ]; then
        error "The home directory mount point must be set as HOME_DIRECTORY_MOUNT_POINT in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${HOME_DIRECTORY_DEVICE_NAME}" ]; then
        error "The home directory volume device name must be set as HOME_DIRECTORY_DEVICE_NAME in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi

    BACKUP_HOME_DIRECTORY_VOLUME_ID="$(find_attached_ebs_volume "${HOME_DIRECTORY_DEVICE_NAME}")"

    if [ -z "${BACKUP_HOME_DIRECTORY_VOLUME_ID}" -o "${BACKUP_HOME_DIRECTORY_VOLUME_ID}" = "null" ]; then
        error "Device name ${HOME_DIRECTORY_DEVICE_NAME} specified in ${BACKUP_VARS_FILE} as HOME_DIRECTORY_DEVICE_NAME could not be resolved to a volume."
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi
}

function backup_home {
    # Freeze the home directory filesystem to ensure consistency
    freeze_home_directory

    snapshot_ebs_volume "${BACKUP_HOME_DIRECTORY_VOLUME_ID}" "Perform backup: ${PRODUCT} home directory snapshot"

    # Unfreeze the home directory as soon as the EBS snapshot has been taken
    unfreeze_home_directory
}

function prepare_restore_home {
    if [ -z "${BITBUCKET_HOME}" ]; then
        error "The ${PRODUCT} home directory must be set as BITBUCKET_HOME in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${BITBUCKET_UID}" ]; then
        error "The ${PRODUCT} home directory owner account must be set as BITBUCKET_UID in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${AWS_AVAILABILITY_ZONE}" ]; then
        error "The availability zone for new volumes must be set as AWS_AVAILABILITY_ZONE in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${RESTORE_HOME_DIRECTORY_VOLUME_TYPE}" ]; then
        error "The type of volume to create when restoring the home directory must be set as RESTORE_HOME_DIRECTORY_VOLUME_TYPE in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    elif [ "io1" = "${RESTORE_HOME_DIRECTORY_VOLUME_TYPE}" -a -z "${RESTORE_HOME_DIRECTORY_IOPS}" ]; then
        error "The provisioned iops must be set as RESTORE_HOME_DIRECTORY_IOPS in ${BACKUP_VARS_FILE} when choosing 'io1' volume type for the home directory EBS volume"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${HOME_DIRECTORY_DEVICE_NAME}" ]; then
        error "The home directory volume device name must be set as HOME_DIRECTORY_DEVICE_NAME in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi

    if [ -z "${HOME_DIRECTORY_MOUNT_POINT}" ]; then
        error "The home directory mount point must be set as HOME_DIRECTORY_MOUNT_POINT in ${BACKUP_VARS_FILE}"
        bail "See bitbucket.diy-backup.vars.sh.example for the defaults."
    fi
}

function restore_home {
    unmount_device

    if [ -n "${BACKUP_HOME_DIRECTORY_VOLUME_ID}" ]; then
        detach_volume
    fi

    info "Restoring home directory from snapshot '${RESTORE_HOME_DIRECTORY_SNAPSHOT_ID}' into a '${RESTORE_HOME_DIRECTORY_VOLUME_TYPE}' volume"
    
    create_and_attach_volume "${RESTORE_HOME_DIRECTORY_SNAPSHOT_ID}" "${RESTORE_HOME_DIRECTORY_VOLUME_TYPE}" \
            "${RESTORE_HOME_DIRECTORY_IOPS}" "${HOME_DIRECTORY_DEVICE_NAME}" "${HOME_DIRECTORY_MOUNT_POINT}"

    remount_device

    cleanup_locks "${BITBUCKET_HOME}"
}

function freeze_home_directory {
    freeze_mount_point "${HOME_DIRECTORY_MOUNT_POINT}"

    # Add a clean up routine to ensure we always unfreeze the home directory filesystem
    add_cleanup_routine unfreeze_home_directory
}

function unfreeze_home_directory {
    remove_cleanup_routine unfreeze_home_directory

    unfreeze_mount_point "${HOME_DIRECTORY_MOUNT_POINT}"
}