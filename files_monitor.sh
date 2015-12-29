#!/bin/bash
#
# Author: ladislav.babjak@gmail.com
# Version: 1.0
#
# At times I needed a simple tool to track changes in the selected files.
# I tested it on multiple platforms in the production environment.
# Script needed only one configuration file files_monitor.conf.
# One line, one file for monitoring.
# Comments in config file is not supported.
# Each change is recorded and sent by email.
# 
# This script I use on these OS:
# Red Hat Enterprise Linux Server release 5.10 (Tikanga), Debian 7.8, Kubuntu 14.04, NetBSD 6.1.3, FreeBSD 10.1, OpenBSD 5.6, AIX 7.1, Solaris 11.2, CYGWIN_NT-6.1
#
# some global variables
# config file name
export CONF="files_monitor.conf"
# log file name
export LOG_FILE="files_monitor.log"
# directory for store information about files
export DATA_DIR="files_monitor_data"

# date and time - format may be depend on OS implementation 
export DATE=$( date +'%F %T')

# email
export EMAIL_BODY="/tmp/email.$$"
export EMAIL_TO="root"
export EMAIL_SUBJECT="Changes of monitoring files"


##### Functions #####

whichOS() {
    OS=`uname -s`

    case "$OS" in
    "Linux"     )   export OS;;
    "NetBSD"    )   export OS;;
    "FreeBSD"   )   export OS;;
    "OpenBSD"   )   export OS;;
    "AIX"       )   export OS;;
    "SunOS"     )   export OS;;
    *"CYGWIN_NT"* ) export OS="CYGWIN";;
    *           )   unset OS ;; 
    esac

}


cksumString_Linux() {
    export CKSUM_FILE_NAME=`echo $1 | /usr/bin/md5sum | /usr/bin/cut -f1 -d' '`
}


cksumFile_Linux() {
    export CKSUM_FILE_DATA=`/usr/bin/md5sum $1 | /usr/bin/cut -f1 -d' '`
}


statFile_Linux() {
    export STAT_FILE=`/usr/bin/stat -c 'right:%A size:%s owner:%U group:%G modification:%y change:%z' $1`
}



cksumString_SunOS() {
    export CKSUM_FILE_NAME=`echo $1 | /usr/bin/md5sum | /usr/bin/cut -f1 -d' '`
}


cksumFile_SunOS() {
    export CKSUM_FILE_DATA=`/usr/bin/md5sum $1 | /usr/bin/cut -f1 -d' '`
}


statFile_SunOS() {
    # Solaris 11 adopted gnu stat version
    export STAT_FILE=`/usr/bin/stat -c '%A %s %U %G %y %z' $1`
}



cksumString_NetBSD() {
    export CKSUM_FILE_NAME=`echo $1 | /usr/bin/md5`
}


cksumFile_NetBSD() {
    export CKSUM_FILE_DATA=`/usr/bin/md5 -n $1 | /usr/bin/cut -f1 -d' '`
}


statFile_NetBSD() {
    #S - string format output
    #p       File type and permissions (st_mode).
    #z       The size of file in bytes (st_size).
    #u, g    User ID and group ID of file's owner (st_uid, st_gid).
    #m       st_mtime
    #c       st_ctime 
    LTMP=`stat -f '%Sp %z %Su %Sg %Sm %Sc' $1`
    echo $LTMP > /tmp/stat.$$
    export STAT_FILE=`cat /tmp/stat.$$`
    rm -f /tmp/stat.$$
}



cksumString_FreeBSD() {
    export CKSUM_FILE_NAME=`echo $1 | /sbin/md5`
}


cksumFile_FreeBSD() {
    export CKSUM_FILE_DATA=`/sbin/md5 -q $1`
}


statFile_FreeBSD() {
    #S - string format output
    #p       File type and permissions (st_mode).
    #z       The size of file in bytes (st_size).
    #u, g    User ID and group ID of file's owner (st_uid, st_gid).
    #m       st_mtime
    #c       st_ctime 
    LTMP=`stat -f '%Sp %z %Su %Sg %Sm %Sc' $1`
    echo $LTMP > /tmp/stat.$$
    export STAT_FILE=`cat /tmp/stat.$$`
    rm -f /tmp/stat.$$

}



cksumString_OpenBSD() {
    export CKSUM_FILE_NAME=`echo $1 | /bin/md5`
}


cksumFile_OpenBSD() {
    export CKSUM_FILE_DATA=`/bin/md5 -q $1`
}


statFile_OpenBSD() {
    #S - string format output
    #p       File type and permissions (st_mode).
    #z       The size of file in bytes (st_size).
    #u, g    User ID and group ID of file's owner (st_uid, st_gid).
    #m       st_mtime
    #c       st_ctime 
    LTMP=`stat -f '%Sp %z %Su %Sg %Sm %Sc' $1`
    echo $LTMP > /tmp/stat.$$
    export STAT_FILE=`cat /tmp/stat.$$`
    rm -f /tmp/stat.$$
}


cksumString_AIX() {
    export CKSUM_FILE_NAME=`echo $1 | /usr/bin/cksum | /usr/bin/cut -f1 -d' '`
}


cksumFile_AIX() {
    export CKSUM_FILE_DATA=`/usr/bin/cksum $1 | /usr/bin/cut -f1 -d' '`
}


statFile_AIX() {
    LTMP=`ls -la $1`
    echo $LTMP > /tmp/stat.$$
    export STAT_FILE=`cat /tmp/stat.$$`
    rm -f /tmp/stat.$$
}



cksumString_CYGWIN() {
    export CKSUM_FILE_NAME=`echo $1 | /usr/bin/md5sum | /usr/bin/cut -f1 -d' '`
}


cksumFile_CYGWIN() {
    export CKSUM_FILE_DATA=`/usr/bin/md5sum $1 | /usr/bin/cut -f1 -d' '`
}


statFile_CYGWIN() {
    export STAT_FILE=`/usr/bin/stat -c 'right:%A size:%s owner:%U group:%G modification:%y change:%z' $1`
}



##### Main #####

whichOS

if [ -z ${OS+x} ]
then
    echo "Unknown OS type."
    exit 1
fi

# go to my working directory
cd $(dirname ${BASH_SOURCE[0]})

# I need config file
if [ ! -f ${CONF} ]
then
    echo "I can't find ${CONF} in my ${PWD} working directory."
    exit 1
fi

# test if file is empty
if [ ! -s ${CONF} ]
then
    echo "Config file ${CONF} is empty."
    exit 1
fi

# if data directory not exist, create it.
if [ ! -d ${DATA_DIR} ]
then
    mkdir ${DATA_DIR}
fi

# Stores contents of config file in an array
export FILES_LIST=( $(cat ${CONF}) )
# Replacement for "seq" utility. OpenBSD doesn't have "seq", but "jot".
SEQ="echo {0..$((${#FILES_LIST[@]} - 1))}"


### loop for monitor of files
for ELEMENT in $(eval $SEQ)
do
    # Name of file as checksum or hash
    cksumString_${OS} ${FILES_LIST[$ELEMENT]}

    # if file doesn't exist on FS
    if [ ! -f ${FILES_LIST[$ELEMENT]} ]
    then
        # File was deleted
        if [[ -f ${DATA_DIR}/${CKSUM_FILE_NAME}.cksum && -f ${DATA_DIR}/${CKSUM_FILE_NAME}.stat ]]
        then
            echo "${DATE} ${FILES_LIST[$ELEMENT]} was probably deleted" | tee -a ${EMAIL_BODY} >> ${LOG_FILE}
            mv ${DATA_DIR}/${CKSUM_FILE_NAME}.cksum ${DATA_DIR}/${CKSUM_FILE_NAME}.old_cksum
            mv ${DATA_DIR}/${CKSUM_FILE_NAME}.stat ${DATA_DIR}/${CKSUM_FILE_NAME}.old_stat
        else
            echo "${DATE} ${FILES_LIST[$ELEMENT]} doesn't exist" >> ${LOG_FILE}
            
        fi
        
        # if file doesn't exist skip it
        continue
    fi



    # Checksum or hash of data file
    cksumFile_${OS} ${FILES_LIST[$ELEMENT]}

    # monitoring of attributes of files
    statFile_${OS} ${FILES_LIST[$ELEMENT]}


    
    # Exist file in monitoring or not
    if [[ -f ${DATA_DIR}/${CKSUM_FILE_NAME}.cksum && -f ${DATA_DIR}/${CKSUM_FILE_NAME}.stat ]]
    then

        OLD_CKSUM_FILE_DATA=`cat ${DATA_DIR}/${CKSUM_FILE_NAME}.cksum`
        OLD_STAT=`cat ${DATA_DIR}/${CKSUM_FILE_NAME}.stat`

        # if cksum of file do not change
        if [[ ${OLD_CKSUM_FILE_DATA} == ${CKSUM_FILE_DATA} ]]
        then
            echo "${DATE} Data of ${FILES_LIST[$ELEMENT]} do not changed" >> ${LOG_FILE}
        else
            # content of file was changed it - logging 
            echo "${DATE} Data of ${FILES_LIST[$ELEMENT]} was changed old cksum: ${OLD_CKSUM_FILE_DATA} new cksum: ${CKSUM_FILE_DATA}" | tee -a ${EMAIL_BODY} >> ${LOG_FILE}
            # rename record for backup
            mv ${DATA_DIR}/${CKSUM_FILE_NAME}.cksum ${DATA_DIR}/${CKSUM_FILE_NAME}.old_cksum
            # actual cksum of data write to record
            echo ${CKSUM_FILE_DATA} > ${DATA_DIR}/${CKSUM_FILE_NAME}.cksum
        fi

        # if attributes is same
        if [[ ${OLD_STAT} == ${STAT_FILE} ]]
        then
            echo "${DATE} Attributes of ${FILES_LIST[$ELEMENT]} do not changed" >> ${LOG_FILE}
        else
            echo "${DATE} Attributes of ${FILES_LIST[$ELEMENT]} was changed old attributes: ${OLD_STAT} new attributes: ${STAT_FILE}" | tee -a ${EMAIL_BODY} >> ${LOG_FILE}
            # rename record for backup
            mv ${DATA_DIR}/${CKSUM_FILE_NAME}.stat ${DATA_DIR}/${CKSUM_FILE_NAME}.old_stat
            # actual attributes
            echo ${STAT_FILE} > ${DATA_DIR}/${CKSUM_FILE_NAME}.stat
        fi

    else
        # file is new for monitoring
        echo ${CKSUM_FILE_DATA} > ${DATA_DIR}/${CKSUM_FILE_NAME}.cksum
        echo ${STAT_FILE} > ${DATA_DIR}/${CKSUM_FILE_NAME}.stat
        echo "${DATE} ${FILES_LIST[$ELEMENT]} is new for monitoring" >> ${LOG_FILE}
    fi

done

# send email about changes if exist
if [ -f ${EMAIL_BODY} ]
then
    # send email
    mailx -s "${EMAIL_SUBJECT}" ${EMAIL_TO} < ${EMAIL_BODY}
    # remove temporary file
    rm -f ${EMAIL_BODY}
fi


