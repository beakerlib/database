#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/database/mysql
#   Description: Set of basic functions for mysql
#   Author: Branislav Blaskovic <bblaskov@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
#   library-prefix = mysql
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

database/mysql - set of basic functions for MySQL

=head1 DESCRIPTION

This is basic library for MySQL.

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

=item mysqlCnf

Config file (my.cnf) location.

=item mysqlCnfDir

Directory that should contain the config file.

=item mysqlCnfIncDir

Directory where the other configuration files are included from.
BEWARE: This will be set to empty string in versions that do not use
includes by default, be sure to test this and fall back to using
the common configuration file (my.cnf) if appropriate!

=item mysqlCnfServer

Server specific config file location. (Equals to mysqlCnf if there
is just the common configuration file by default.)

=item mysqlDbDir

Directory that holds the actual database datafiles.

=item mysqlLockFile

Mysql daemon lock file location.

=item mysqlLog

Log file (mysqld.log) location.

=item mysqlLogDir

Directory where the log file (mysqld.log) is stored.

=item mysqlPidFile

Mysql daemon pidfile default location.

=item mysqlPkgPrefix

Collection packages prefix, empty otherwise.

=item mysqlRootDir

Collection root directory, empty otherwise.

=item mysqlServiceName

Name of the service.

=item mysqlSocket

Socket file as configured in my.cnf.

=item mysqlCollection

Set to collection name to use with scl enable when running in collection,
empty string otherwise.

=back

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 FUNCTIONS

=cut

true <<'=cut'
=head2 mysqlStart

Starts MySQL daemon.

    mysqlStart [port]

Note that since RHEL7 / mysql55 the daemon does not automatically re-create
the logfile, so the mysqlStart function does that for you if needed. In case
of nonstandard logfile location, just export proper mysqlLog value.

=over

=back

Returns 0 when MySQL is successfully started, non-zero otherwise.

=cut

# FIXME: needs to change port and socket file in case of parallel run
mysqlStart() {
    # since RHEL7 / mysql55, the daemon does not automatically re-create the logfile if it is missing
    # and since mysql56, it re-creates it again, oh my ...
    # but on Fedora it fails to re-create it because of lack of permissions to /var/log, OH MY!
    checklog() {
        if ! [[ -e $mysqlLog ]] ; then
           rlLogInfo "Restoring the log file (workaround)"
           rlRun "touch $mysqlLog" 0 "Creating the logfile"
           rlRun "chown mysql:mysql $mysqlLog" 0 "Fixing ownership of the logfile"
           rlRun "chmod 640 $mysqlLog" 0 "Fixing permissions of the logfile"
           # note that it gets installed with system_u but restorecon sets unconfined_u ... doesn't seem to break anything
           rlRun "restorecon $mysqlLog" 0 "Restoring SELinux context of the logfile"
           # can't test directly via rlRun as reconfiguring logfile location would break the assert
           if rpm -Vf "$mysqlLog" ; then
               rlLogInfo "GOOD, 'rpm -Vf $mysqlLog' does not complain'"
           else
               rlLogWarning "WARNING, 'rpm -Vf $mysqlLog' has failed'"
           fi
        fi
    }
    case $mysqlVersion in
        5.5.*) checklog ;;
        5.7.*) if rlIsFedora ; then checklog ; fi ;;
        *) true ;;
    esac
    rlRun "rlServiceStart \"$mysqlServiceName\""
    rlRun "service $mysqlServiceName status"

    return $?
}

true <<'=cut'
=head2 mysqlStop

Stops MySQL daemon.

    mysqlStop

=over

=back

Returns 0 when MySQL is successfully stopped, non-zero otherwise.

=cut

mysqlStop() {

    rlRun "rlServiceStop \"$mysqlServiceName\""

    return $?
}

true <<'=cut'
=head2 mysqlRestore

Restores mysql daemon.

    mysqlRestore

=over

=back

Returns 0 when mysql is successfully restored, non-zero otherwise.

=cut

mysqlRestore() {
    rlRun "rlServiceRestore \"$mysqlServiceName\""
    return $?
}

true <<'=cut'
=head2 mysqlCreateTestDB

Since MySQL 5.6, the 'test' database is no longer installed.
This function creates it and sets the same privileges as the
mysql_install_db script with mysql_system_tables_data.sql used to do.
If the 'test' database exists, it drops it before re-creating.
(Note that it is not supposed to be purged at the end of a test
- please use mysqlCleanup to drop 'test' with newer versions.)

    mysqlCreateTestDB

=over

=back

Returns 0 when 'test' is successfully created, non-zero otherwise.

=cut

mysqlCreateTestDB() {
    mysql -u root <<< "DROP DATABASE IF EXISTS test;"
    mysql -u root <<< "DELETE FROM mysql.db WHERE db = 'test';"
    mysql -u root <<< "CREATE DATABASE test;"
    # do we have columns added in MySQL 5.1.6?
    if mysql -e "select Trigger_priv,Event_priv from mysql.db;" &> /dev/null ; then
        # for MySQL >= 5.1.6
        mysql -u root <<< "INSERT INTO mysql.db VALUES ('%','test','','Y','Y','Y','Y','Y','Y','N','Y','Y','Y','Y','Y','Y','Y','Y','N','N','Y','Y');"
    else
        # for MySQL >= 5.0.3 < 5.1.6
        mysql -u root <<< "INSERT INTO mysql.db VALUES ('%','test','','Y','Y','Y','Y','Y','Y','N','Y','Y','Y','Y','Y','Y','Y','Y','N','N');"
    fi
    return $?
}

true <<'=cut'
=head2 mysqlAddUser

Add user with password.

    mysqlAddUser user password

=over

=item user

User name.

=item password

Password for user.

=back

Returns 0 when user is successfully added, non-zero otherwise.

=cut

mysqlAddUser() {

    local user=$1
    local pass=$2

    mysql -u root <<< "CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass';"
    return $?
}

true <<'=cut'
=head2 mysqlDeleteUser

Delete user.

    mysqlDeleteUser user

=over

=item user

User name to delete.

=back

Returns 0 when user is successfully deleted, non-zero otherwise.

=cut

mysqlDeleteUser() {

    local user=$1

    mysql -u root <<< "DROP USER '$user'@'localhost';"
    return $?
}

true <<'=cut'
=head2 mysqlCheckSqlMode

Logs actual sql_mode read from configuration file; if it is not set explicitly,
it adds the appropriate configuration option with default values as documented:
https://dev.mysql.com/doc/refman/5.7/en/sql-mode.html

Don''t forget to run mysqlCleanup if you use this.

    mysqlCheckSqlMode

=over

=back

Returns 0 on success, non-zero otherwise.

=cut

mysqlCheckSqlMode() {
    mysqlGetDefaultSqlMode() {
        ver() {
            printf "10#%02d%02d%02d" ${1//./" "}
        }
        if [[ $(ver $mysqlVersion) -le $(ver 5.6.5) ]] ; then
            echo ""
        elif [[ $(ver $mysqlVersion) -le $(ver 5.7.4) ]] ; then
            echo "NO_ENGINE_SUBSTITUTION"
        elif [[ $(ver $mysqlVersion) -le $(ver 5.7.6) ]] ; then
            echo "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION"
        elif [[ $(ver $mysqlVersion) -eq $(ver 5.7.7) ]] ; then
            echo "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
        elif [[ $(ver $mysqlVersion) -lt $(ver 8.0.0) ]] ; then
            echo "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
        else
            echo "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
        fi
    }

    if grep sql_mode ${mysqlCnfSql_mode} &>/dev/null ; then
        rlLogDebug "sql_mode set already in ${mysqlCnfSql_mode}, not touching it"
    else
        if grep "\[server\]" ${mysqlCnfSql_mode} &>/dev/null ; then
            sed -i -e "/\[server\]/a sql_mode = $(mysqlGetDefaultSqlMode)" ${mysqlCnfSql_mode}
        else
            echo "[server]" >> ${mysqlCnfSql_mode}
            echo "sql_mode = $(mysqlGetDefaultSqlMode)" >> ${mysqlCnfSql_mode}
        fi
    fi
    rlLogInfo "Actual sql_mode: $(sed -n 's/^sql_mode = //p' ${mysqlCnfSql_mode})"
}

true <<'=cut'
=head2 mysqlModeAutoCreateUser

Configure sql_mode so that NO_AUTO_CREATE_USER is not present.
(This is for backwards compatibility when users got added
by simple GRANT call.)
Don''t forget to run mysqlCleanup if you use this.

    mysqlModeAutoCreateUser

=over

=back

Returns 0 on success, non-zero otherwise.

=cut

mysqlModeAutoCreateUser() {
    ver() {
        printf "10#%02d%02d%02d" ${1//./" "}
    }
    if [[ $(ver $mysqlVersion) -ge $(ver 8.0.0) ]] ; then
        rlDie "Since 8.0, auto create user functionality has been disabled, please update your test!"
    fi
    mysqlCheckSqlMode
    rlRun "sed -i -e 's/NO_AUTO_CREATE_USER//' -e '/sql_mode/ s/,,/,/' -e '/sql_mode/ s/,$//' -e 's/sql_mode = ,/sql_mode = /' ${mysqlCnfSql_mode}" 0 "Trying to remove 'NO_AUTO_CREATE_USER'"
    mysqlCheckSqlMode
    rlLogInfo "Do not forget to restart the server for changes to apply"
}

true <<'=cut'
=head2 mysqlModeNoOnlyFullGroupBy

Configure sql_mode so that ONLY_FULL_GROUP_BY is not present.
Don''t forget to run mysqlCleanup if you use this.

    mysqlModeNoOnlyFullGroupBy

=over

=back

Returns 0 on success, non-zero otherwise.

=cut

mysqlModeNoOnlyFullGroupBy() {
    mysqlCheckSqlMode
    rlRun "sed -i -e 's/ONLY_FULL_GROUP_BY//' -e '/sql_mode/ s/,,/,/' -e '/sql_mode/ s/,$//' -e 's/sql_mode = ,/sql_mode = /' ${mysqlCnfSql_mode}" 0 "Trying to remove 'ONLY_FULL_GROUP_BY'"
    mysqlCheckSqlMode
    rlLogInfo "Do not forget to restart the server for changes to apply"
}


true <<'=cut'
=head2 mysqlModeNoStrictTransTables

Configure sql_mode so that STRICT_TRANS_TABLES is not present.
Don''t forget to run mysqlCleanup if you use this.

    mysqlModeNoStrictTransTables

=over

=back

Returns 0 on success, non-zero otherwise.

=cut

mysqlModeNoStrictTransTables() {
    mysqlCheckSqlMode
    rlRun "sed -i -e 's/STRICT_TRANS_TABLES//' -e '/sql_mode/ s/,,/,/' -e '/sql_mode/ s/,$//' -e 's/sql_mode = ,/sql_mode = /' ${mysqlCnfSql_mode}" 0 "Trying to remove 'STRICT_TRANS_TABLES'"
    mysqlCheckSqlMode
    rlLogInfo "Do not forget to restart the server for changes to apply"
}

true <<'=cut'
=head2 mysqlCleanup

Tries to remove various cruft that may have been created during testing.

    mysqlCleanup

=over

=back

Returns 0.

=cut

mysqlCleanup() {
    ver() {
        printf "10#%02d%02d%02d" ${1//./" "}
    }

    if [[ ${mysqlCnfSql_mode} != ${mysqlCnfServer} ]] && [[ -e ${mysqlCnfSql_mode} ]]; then
        rlRun "rm ${mysqlCnfSql_mode}" 0 "Removing ${mysqlCnfSql_mode}"
    else
        rlLogInfo "Separate ${mysqlCnfSql_mode} not found, good"
    fi

    if [[ $(ver $mysqlVersion) -lt $(ver 5.6.0) ]] ; then
        rlLogInfo "Running on mysql older than 5.6 ($mysqlVersion), not trying to drop the database 'test'"
    else
        rlRun 'mysql -u root <<< "DROP DATABASE IF EXISTS test;"' 0 "Try to drop the database 'test' (on mysql 5.6 and newer; current=$mysqlVersion)"
    fi
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

mysqlLibraryLoaded() {
    rlLogDebug "Library database/mysql is loaded."

    if rlIsFedora ">18"; then
        RUN_ON_DB="community"
    fi

    # recognize parameter to set collection via tcms case
    RUN_ON_DB=${RUN_ON_DB:-"$COLLECTIONS"}

    # Set variables according to collection
    # FIXME: this must handle selection from multiple matches in the future
    # (or the scheduling tools must ensure only one match)
    case "$RUN_ON_DB" in
        community)
            mysqlCollection=""
            mysqlPkgPrefix="community-"
            mysqlRootDir=""
            mysqlServiceName="mysqld"
            mysqlCnfIncDir="/etc/my.cnf.d"
            mysqlCnfServer="${mysqlCnfIncDir}/${mysqlPkgPrefix}mysql-server.cnf"
            mysqlCnfSql_mode="${mysqlCnfIncDir}/sql_mode.cnf"
            ;;
        *mysql51*)
            # We are running with collection mysql51
            mysqlCollection="mysql51"
            mysqlPkgPrefix="mysql51-"
            mysqlRootDir="/opt/rh/mysql51/root"
            mysqlServiceName="mysql51-mysqld"
            mysqlPidFile="${mysqlRootDir}/var/run/mysqld/mysqld.pid"
            ;;
        *mysql55*)
            # We are running with collection mysql55
            mysqlCollection="mysql55"
            mysqlPkgPrefix="mysql55-"
            mysqlRootDir="/opt/rh/mysql55/root"
            mysqlServiceName="mysql55-mysqld"
            mysqlPidFile="${mysqlRootDir}/var/run/mysqld/mysqld.pid"
            ;;
        *rh-mysql56*)
            # We are running with collection rh-mysql56
            mysqlCollection="rh-mysql56"
            mysqlPkgPrefix="rh-mysql56-"
            mysqlRootDir="/opt/rh/rh-mysql56/root"
            mysqlServiceName="rh-mysql56-mysqld"
            mysqlCnfDir="/etc/opt/rh/rh-mysql56"
            mysqlCnfIncDir="${mysqlCnfDir}/my.cnf.d"
            mysqlCnfServer="${mysqlCnfIncDir}/mysql-server.cnf"
            mysqlCnfSql_mode="${mysqlCnfIncDir}/sql_mode.cnf"
            mysqlDbDir="/var/opt/rh/rh-mysql56/lib/mysql"
            mysqlLogDir="/var/opt/rh/rh-mysql56/log/mysql"
            mysqlLog="${mysqlLogDir}/mysqld.log"
            ;;
        *rh-mysql57*)
            # We are running with collection rh-mysql57
            mysqlCollection="rh-mysql57"
            mysqlPkgPrefix="rh-mysql57-"
            mysqlRootDir="/opt/rh/rh-mysql57/root"
            mysqlServiceName="rh-mysql57-mysqld"
            mysqlCnfDir="/etc/opt/rh/rh-mysql57"
            mysqlCnfIncDir="${mysqlCnfDir}/my.cnf.d"
            mysqlCnfServer="${mysqlCnfIncDir}/${mysqlPkgPrefix}mysql-server.cnf"
            mysqlCnfSql_mode="${mysqlCnfIncDir}/sql_mode.cnf"
            mysqlDbDir="/var/opt/rh/rh-mysql57/lib/mysql"
            mysqlLogDir="/var/opt/rh/rh-mysql57/log/mysql"
            mysqlLog="${mysqlLogDir}/mysqld.log"
            ;;
        *rh-mysql80*)
            # We are running with collection rh-mysql57
            mysqlCollection="rh-mysql80"
            mysqlPkgPrefix="${mysqlCollection}-"
            mysqlRootDir="/opt/rh/${mysqlCollection}/root"
            mysqlServiceName="${mysqlCollection}-mysqld"
            mysqlCnfDir="/etc/opt/rh/${mysqlCollection}"
            mysqlCnfIncDir="${mysqlCnfDir}/my.cnf.d"
            mysqlCnfServer="${mysqlCnfIncDir}/mysql-server.cnf"
            mysqlCnfSql_mode="${mysqlCnfIncDir}/sql_mode.cnf"
            mysqlDbDir="/var/opt/rh/rh-mysql80/lib/mysql"
            mysqlLogDir="/var/opt/rh/rh-mysql80/log/mysql"
            mysqlLog="${mysqlLogDir}/mysqld.log"
            ;;
        *)
            # We are running without collection
            mysqlCollection=""
            mysqlPkgPrefix=""
            mysqlRootDir=""
            mysqlServiceName="mysqld"
            if rlIsRHEL 8 ; then
                mysqlLogDir="/var/log/mysql"
                mysqlCnfDir="/etc"
                mysqlCnfIncDir="${mysqlCnfDir}/my.cnf.d"
                mysqlCnfServer="${mysqlCnfIncDir}/mysql-server.cnf"
            fi
            ;;
    esac
    mysqlCnfDir="${mysqlCnfDir:-${mysqlRootDir}/etc}"
    mysqlCnfIncDir="${mysqlCnfIncDir:-}"
    mysqlCnf="${mysqlCnf:-${mysqlCnfDir}/my.cnf}"
    mysqlCnfServer="${mysqlCnfServer:-${mysqlCnf}}"
    mysqlCnfSql_mode="${mysqlCnfSql_mode:-${mysqlCnfServer}}"
    mysqlDbDir="${mysqlDbDir:-${mysqlRootDir}/var/lib/mysql}"
    mysqlLockFile="/var/lock/subsys/${mysqlServiceName}"
    mysqlLogDir="${mysqlLogDir:-/var/log/mysql}"
    mysqlLog="${mysqlLog:-${mysqlLogDir}/${mysqlServiceName}.log}"
    mysqlPidFile="${mysqlPidFile:-/var/run/${mysqlServiceName}/mysqld.pid}"
    mysqlSocket="${mysqlSocket:-$(sed -n -e "s/socket=//p" "${mysqlCnfServer}")}"

    PACKAGE="${mysqlPkgPrefix}mysql"
    mysqlVersion=`rpm -q --qf %{VERSION} ${PACKAGE}-server`

    # Write variables to screen
    rlLog "*** MySQL Library variables ***"
    rlLog "\$RUN_ON_DB        = $RUN_ON_DB"
    rlLog "\$COLLECTIONS      = $COLLECTIONS"
    rlLog "\$PACKAGE          = $PACKAGE"
    rlLog "\$mysqlCnf         = $mysqlCnf"
    rlLog "\$mysqlCnfDir      = $mysqlCnfDir"
    if [[ -z $mysqlCnfIncDir ]] ; then
        rlLog "\$mysqlCnfIncDir   = [this variable intentionally set empty]"
    else
        rlLog "\$mysqlCnfIncDir   = $mysqlCnfIncDir"
    fi
    rlLog "\$mysqlCnfServer   = $mysqlCnfServer"
    rlLog "\$mysqlCnfSql_mode = $mysqlCnfSql_mode"
    rlLog "\$mysqlCollection  = $mysqlCollection"
    rlLog "\$mysqlDbDir       = $mysqlDbDir"
    rlLog "\$mysqlLockFile    = $mysqlLockFile"
    rlLog "\$mysqlLogDir      = $mysqlLogDir"
    rlLog "\$mysqlLog         = $mysqlLog"
    rlLog "\$mysqlPidFile     = $mysqlPidFile"
    rlLog "\$mysqlPkgPrefix   = $mysqlPkgPrefix"
    rlLog "\$mysqlRootDir     = $mysqlRootDir"
    rlLog "\$mysqlServiceName = $mysqlServiceName"
    rlLog "\$mysqlSocket      = $mysqlSocket"
    rlLog "\$mysqlVersion     = $mysqlVersion"
    rlLog "*******************************"

    return 0
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
Karel Volny <kvolny@redhat.com>
Jakub Heger <jheger@redhat.com>

=back

=cut
