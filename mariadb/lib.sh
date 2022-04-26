#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Set of basic functions for mariadb
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012-2020 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = mariadb
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

database/mariadb - set of basic functions for MariaDB

=head1 DESCRIPTION

This is basic library for MariaDB.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 VARIABLES

Below is the list of global variables. When writing a new library,
please make sure that all global variables start with the library
prefix to prevent collisions with other libraries.

=over

=item mariadbCnf

Config file (my.cnf) location.

=item mariadbCnfDir

Path prefix for configuration files.

=item mariadbCnfIncDir

Directory where the other configuration files are included from.
BEWARE: This will be set to empty string in versions that do not use
includes by default, be sure to test this and fall back to using
the common configuration file (my.cnf) if appropriate!

=item mariadbCnfClient

Client config file (client.cnf) location; the same as mariadbCnf in older versions.

=item mariadbCnfServer

Server config file (mariadb-server.cnf) location; the same as mariadbCnf in older versions.

=item mariadbCollection

Set to 1 when running in collection. 0 otherwise.

=item mariadbCollectionName

Collection name (what to pass to `scl enable ...`)

=item mariadbDbDir

Path to database storage.

=item mariadbLockFile

Mysql (maria) daemon lock file location.

=item mariadbLog

Log file (mariadb.log) location.

=item mariadbLogDir

Directory where the log file (mariadb.log) is stored.

=item mariadbPidFile

Mysql (maria) daemon pidfile default location.

=item mariadbPkgPrefix

Collection packages prefix, empty otherwise.

=item mariadbRootDir

Root dir. If not running in collection - empty.

=item mariadbSclPrefix

Common path to files in collection, empty otherwise.

=item mariadbServiceName

Service name of mariadb.

=item mariadbSocket

Socket file (mysql.sock) location determined from server configuration.

=item mariadbVarDir

Path prefix for variable files.

=item mariadbVersion

Package (server) version.

=back

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ver() {
# undocumented helper :-)
    printf "10#%02d%02d%02d" ${1//./" "}
}

true <<'=cut'
=pod

=head1 FUNCTIONS

=cut

true <<'=cut'
=head2 mariadbStart

Starts MariaDB daemon.

    mariadbStart

=over

=back

Returns 0 when MariaDB is successfully started, non-zero otherwise.

=cut

mariadbStart() {
    if [[ "$1" != "-k" ]]; then
        # -k as 'keep' for keeping /var/lib/mysql and it's contents
        if [[ -d "$mariadbDbDir" ]]; then
            if rlServiceStatus "$mariadbServiceName" &>/dev/null; then
                rlLog "Stopping service before removing its content"
                rlServiceStop "$mariadbServiceName"
            fi
            rlRun "rm -rf $mariadbDbDir/*" 0 "Remove leftover $mariadbDbDir contents"
        else
            rlLogInfo "Creating $mariadbDbDir"
            rlRun "mkdir -p $mariadbDbDir"
            rlRun "chown mysql:mysql $mariadbDbDir"
        fi
    fi

    if ! [[ -e $mariadbLog ]] ; then
       rlLogInfo "Restoring the log file since it is missing"
       rlRun "mkdir -p `dirname $mariadbLog`"
       rlRun "touch $mariadbLog" 0 "Creating the logfile"
       rlRun "chown mysql:mysql $mariadbLog" 0 "Fixing ownership of the logfile"
       rlRun "chmod 640 $mariadbLog" 0 "Fixing permissions of the logfile"
       # note that it gets installed with system_u but restorecon sets unconfined_u ... doesn't seem to break anything
       rlRun "restorecon $mariadbLog" 0 "Restoring SELinux context of the logfile"
       # can't test directly via rlRun as reconfiguring logfile location would break the assert
       if rpm -Vf "$mariadbLog" ; then
           rlLogInfo "GOOD, 'rpm -Vf $mariadbLog' does not complain'"
       else
           rlLogInfo "WARNING, 'rpm -Vf $mariadbLog' has failed'"
       fi
       case "$COLLECTIONS" in
           *rh-mariadb10[1-9]*)
               #from version 101: its needed:
               echo '[mysqld]
sql_mode = NO_ENGINE_SUBSTITUTION' > $mariadbCnfIncDir/NO_ENGINE_SUBSTITUTION.cnf
               rlAssert0 "rh-mariadb101: add `cat $mariadbCnfIncDir/NO_ENGINE_SUBSTITUTION.cnf`" $?
       esac
    fi


    rlRun "rlServiceStart $mariadbServiceName"
    rlRun "service $mariadbServiceName status"
    ret_code=$?
    [[ $ret_code -eq 0 ]] || \
        rlLog "$mariadbLog:\n$(tail -n30 $mariadbLog)"
    return $ret_code
}

true <<'=cut'
=head2 mariadbStop

Stops MariaDB daemon.

    mariadbStop

=over

=back

Returns 0 when mariadb is successfully stopped, non-zero otherwise.

=cut

mariadbStop() {
    rlRun "rlServiceStop \"$mariadbServiceName\""
    if [[ "$1" != "-k" ]]; then
        rlRun "rm -rf $mariadbDbDir/*" 0 "Remove leftover $mariadbDbDir contents"
    fi
    ret_code=$?
    [[ $ret_code -eq 0 ]] || \
        rlLog "$mariadbLog:\n$(tail -n30 $mariadbLog)"
    return $ret_code
}

true <<'=cut'
=head2 mariadbRestore

Restores MariaDB daemon.

    mariadbRestore

=over

=back

Returns 0 when mariadb is successfully restored, non-zero otherwise.

=cut

mariadbRestore() {
    if [[ "$1" != "-k" ]]; then
        rlRun "rm -rf $mariadbDbDir/*" 0 "Remove leftover $mariadbDbDir contents"
    fi
    rlRun "rlServiceRestore \"$mariadbServiceName\""
    ret_code=$?
    [[ $ret_code -eq 0 ]] || \
        rlLog "$mariadbLog:\n$(tail -n30 $mariadbLog)"
    return $ret_code
}
true <<'=cut'
=head2 mariadbAddUser

Add user with password.

    mariadbAddUser user password

=over

=item user

User name.

=item password

Password for user.

=back

Returns 0 when user is successfully added, non-zero otherwise.

=cut

mariadbAddUser() {

    local user=$1
    local pass=$2

    mysql -u root <<< "CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass';"
    return $?
}

true <<'=cut'
=head2 mariadbDeleteUser

Delete user.

    mariadbDeleteUser user

=over

=item user

User name to delete.

=back

Returns 0 when user is successfully deleted, non-zero otherwise.

=cut

mariadbDeleteUser() {

    local user=$1

    mysql -u root <<< "DROP USER '$user'@'localhost';"
    return $?
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

mariadbLibraryLoaded() {
    # recognize parameter to set collection via tcms case
    RUN_ON_DB=${RUN_ON_DB:-"$COLLECTIONS"}
    RUN_ON_DB=${RUN_ON_DB:-"$SYSPATHS"}
    if ( [ -z "$RUN_ON_DB" ] || echo $RUN_ON_DB | grep -q '^mariadb' ) && ! rpm -q mariadb-server ; then
        rlLog "MariaDB is not installed. Install it."
        [ -d /var/lib/mysql ] && rlRun "rm -rf /var/lib/mysql"
        rlRun "yum install -y --disablerepo=beaker-tasks --allowerasing mariadb mariadb-server"
    fi

    if rpm=$(rpm -qa rh-mariadb*-mariadb || rpm -q mariadb55 || rpm -q mariadb); then
        rlLogDebug "Library mariadb/basic is loaded."

        # Set variables according to collection
        case "$RUN_ON_DB" in
            *rh-mariadb10*)
                mariadbCollection=1
                case "$RUN_ON_DB" in
                    *rh-mariadb100*)
                        mariadbCollectionName="rh-mariadb100" ;;
                    *rh-mariadb101*)
                        mariadbCollectionName="rh-mariadb101" ;;
                    *rh-mariadb102*)
                        mariadbCollectionName="rh-mariadb102" ;;
                    *rh-mariadb103*)
                        mariadbCollectionName="rh-mariadb103" ;;
                    *rh-mariadb105*)
                        mariadbCollectionName="rh-mariadb105" ;;
                esac
                mariadbSclPrefix="/opt/rh/${mariadbCollectionName}"
                mariadbRootDir="${mariadbSclPrefix}/root"
                mariadbCnfDir="/etc${mariadbSclPrefix}"
                mariadbCnfIncDir="${mariadbCnfDir}/my.cnf.d"
                mariadbCnf="${mariadbCnfDir}/my.cnf"
                mariadbCnfServer="${mariadbCnfIncDir}/mariadb-server.cnf"
                mariadbVarDir="/var${mariadbSclPrefix}"
                mariadbServiceName="${mariadbCollectionName}-mariadb"
                mariadbLogDir="${mariadbVarDir}/log/mariadb"
                mariadbDbDir="${mariadbVarDir}/lib/mysql"
                mariadbLockFile="/var/lock/subsys/${mariadbServiceName}"
                mariadbPidFile="/var/run/$mariadbServiceName/mariadb.pid"
                ;;
            *mariadb55*)
                # We are running with collection
                mariadbCollection=1
                mariadbCollectionName="mariadb55"
                mariadbSclPrefix="/opt/rh/${mariadbCollectionName}"
                mariadbRootDir="${mariadbSclPrefix}/root"
                if rlIsRHEL 6 ; then
                    mariadbServiceName="${mariadbCollectionName}-mysqld"
                else
                    mariadbServiceName="${mariadbCollectionName}-mariadb"
                fi
                mariadbPidFile="${mariadbRootDir}/var/run/mysqld/mysqld.pid"
                ;;
        esac

        # defaults
        mariadbCollection="${mariadbCollection:-0}"
        mariadbCollectionName="${mariadbCollectionName:-}"
        mariadbSclPrefix="${mariadbSclPrefix:-}"
        [[ -z $mariadbPkgPrefix ]] && mariadbPkgPrefix="${mariadbCollectionName:+${mariadbCollectionName}-}"

        PACKAGE="${mariadbPkgPrefix}mariadb"
        mariadbVersion=`rpm -q --qf %{VERSION} ${PACKAGE}`

        mariadbRootDir="${mariadbRootDir:-}"
        mariadbCnfDir="${mariadbCnfDir:-${mariadbRootDir}/etc}"
        mariadbCnf="${mariadbCnf:-${mariadbCnfDir}/my.cnf}"
        if [[ $(ver $mariadbVersion) < $(ver 10.3.0) ]]; then
            mariadbCnfIncDir="${mariadbCnfIncDir:-}"
            mariadbCnfClient="${mariadbCnfClient:-${mariadbCnf}}"
            mariadbCnfServer="${mariadbCnfServer:-${mariadbCnf}}"
        else
            mariadbCnfIncDir="${mariadbCnfIncDir:-${mariadbCnfDir}/my.cnf.d}"
            mariadbCnfClient="${mariadbCnfClient:-${mariadbCnfIncDir}/client.cnf}"
            mariadbCnfServer="${mariadbCnfServer:-${mariadbCnfIncDir}/mariadb-server.cnf}"
        fi
        mariadbVarDir="${mariadbVarDir:-${mariadbRootDir}/var}"
        mariadbServiceName="${mariadbServiceName:-mariadb}"
        if rlIsRHEL 6 ; then
            mariadbLogDir="${mariadbLogDir:-${mariadbVarDir}/log}"
            mariadbLog="${mariadbLog:-${mariadbLogDir}/${mariadbServiceName}.log}"
        else
            mariadbLogDir="${mariadbLogDir:-${mariadbVarDir}/log/${mariadbServiceName}}"
            mariadbLog="${mariadbLog:-${mariadbLogDir}/mariadb.log}"
        fi
        mariadbDbDir="${mariadbDbDir:-${mariadbRootDir}/var/lib/mysql}"
        mariadbLockFile="${mariadbLockFile:-${mariadbRootDir}/var/lock/subsys/${mariadbServiceName}}"
        mariadbPidFile="${mariadbPidFile:-${mariadbRootDir}/var/run/${mariadbServiceName}/${mariadbServiceName}.pid}"
        mariadbSocket=$(sed -n -e "s/socket=//p" "${mariadbCnfServer}")

    # Set variables according to syspaths
    case "$SYSPATHS" in
        *rh-mariadb102)
            mariadbServiceName="mariadb"
            ;;
    esac

        # Write variables to screen
        rlLog "*** Library variables ***"
        rlLog "\$RUN_ON_DB              = $RUN_ON_DB"
        rlLog "\$COLLECTIONS            = $COLLECTIONS"
        rlLog "\$PACKAGE                = $PACKAGE"
        rlLog "\$mariadbCollection      = $mariadbCollection"
        rlLog "\$mariadbCollectionName  = $mariadbCollectionName"
        rlLog "\$mariadbVersion         = $mariadbVersion"
        rlLog "\$mariadbPkgPrefix       = $mariadbPkgPrefix"
        rlLog "\$mariadbServiceName     = $mariadbServiceName"
        rlLog "\$mariadbSclPrefix       = $mariadbSclPrefix"
        rlLog "\$mariadbRootDir         = $mariadbRootDir"
        rlLog "\$mariadbCnf             = $mariadbCnf"
        rlLog "\$mariadbCnfDir          = $mariadbCnfDir"
        if [[ -z $mariadbCnfIncDir ]] ; then
            rlLog "\$mariadbCnfIncDir       = [this variable intentionally set empty]"
        else
            rlLog "\$mariadbCnfIncDir       = $mariadbCnfIncDir"
        fi
        rlLog "\$mariadbCnfClient       = $mariadbCnfClient"
        rlLog "\$mariadbCnfServer       = $mariadbCnfServer"
        rlLog "\$mariadbVarDir          = $mariadbVarDir"
        rlLog "\$mariadbDbDir           = $mariadbDbDir"
        rlLog "\$mariadbLockFile        = $mariadbLockFile"
        rlLog "\$mariadbPidFile         = $mariadbPidFile"
        rlLog "\$mariadbLog             = $mariadbLog"
        rlLog "\$mariadbLogDir          = $mariadbLogDir"
        rlLog "\$mariadbSocket          = $mariadbSocket"
        rlLog "*******************************"

        return 0
    else
        rlFail "Package *mariadb* is not installed."
        rlDie "Better not to continue.."
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Branislav Blaskovic <bblaskov@redhat.com>
Karel Volný <kvolny@redhat.com>
Lukas Zachar <lzachar@redhat.com>
Jakub Heger <jheger@redhat.com>

=back

=cut
