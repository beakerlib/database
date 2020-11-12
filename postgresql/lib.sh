#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/database/postgresql
#   Description: Set of basic functions for postgresql
#   Author: Branislav Blaskovic <bblaskov@redhat.com>
#   Author: Jakub Prokes <jprokes@redhat.com>
#   Author: Vaclav Danek <vdanek@redhat.com>
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
#   library-prefix = postgresql
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

database/postgresql - set of basic functions for PostgreSQL

=head1 DESCRIPTION

This is basic library for PostgreSQL.

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

=item postgresqlServiceName

Name of service.

=item postgresqlCollection

Set to 1 when running in collection. 0 otherwise.

=item postgresqlPackagePrefix

Prefix which differ RHSCL package name from distribution.
Where no software collection set is empty.

=item postgresqlRootDir

Path prefix for RHSCL root.

=back

=cut

#postgresqlCollection=0
#postgresqlServiceName="postgresql"
#postgresqlPackagePrefix="";
#postgresqlRootDir="";
#postgresqlMainPackage="postgresql";
declare -a _postgresqlRegisteredErrors;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head1 FUNCTIONS

=cut

## Local function for error tracing
__postgresqlLogTrace() {
    rlLogError "--------------- STACK  TRACE ---------------" >&2;
    rlLogError "An error has occurred near line ${BASH_LINENO[${#FUNCNAME[@]}-2]}: $1" >&2;
    local i;
    #for ((i=${#FUNCNAME[@]}-2; i>=0; i--)); do
    for ((i=0; i<${#FUNCNAME[@]}-1; i++)); do
       rlLogError "File: $(basename ${BASH_SOURCE[$i+1]}), line ${BASH_LINENO[$i]}, in ${FUNCNAME[$i+1]}" >&2;
       [[ $i -gt 1 ]] && rlLogError "    Call: $(sed -n "${BASH_LINENO[i]}s/^\s\+//p" ${BASH_SOURCE[$i+1]})" >&2;
    done
    rlLogError "--------------- STACK  TRACE ---------------" >&2;
}

__postgresqlLogDebug() {
    local msgPrefix="${FUNCNAME[${#FUNCNAME[@]}-2]}";
    local i;
    for ((i=${#FUNCNAME[@]}-3; i>0; i--)); do
        msgPrefix="$msgPrefix->${FUNCNAME[$i]}"
    done
    rlLogDebug "${msgPrefix} :: $1" >&2;
}

__postgresqlRun() {
    local cmd="$1";
    local rc=${2-0};
    local msg="$3"

    local msgPrefix="${FUNCNAME[${#FUNCNAME[@]}-3]}";
    local i;
    for ((i=${#FUNCNAME[@]}-4; i>0; i--)); do
        [[ ${FUNCNAME[$i]} != $FUNCNAME ]] && msgPrefix="$msgPrefix->${FUNCNAME[$i]}"
    done

    if [[ -z $msg ]]; then
        rlRun "$cmd" "$rc" "$msgPrefix: Internal assert";
    else
        rlRun "$cmd" "$rc" "$msgPrefix: $msg";
    fi
    
}

__postgresqlOnError() {
    local -i lastRC="${?}";
    local -i lineNO="$1";
    if [[ -n ${_postgresqlRegisteredErrors[$lastRC]} ]]; then
        for ((i=${#FUNCNAME[@]}; i>0; i--)); do
            if [[ -n $prefix ]]; then
                prefix="${prefix}->${FUNCNAME[$i]}";
            else
                prefix="${FUNCNAME[$i]}";
            fi
        done
        rlFail "$prefix: ${_postgresqlRegisteredErrors[$lastRC]}($lastRC) near $lineNO in '$(basename ${BASH_SOURCE[$i+1]})'";
    fi
}

true <<'=cut'
=head2 version2number

Formates version to comparable number

    version2number <version>

=over

=item version

    Version aka 9.6

=back

    Comparable number
=cut
version2number ()
{
    local old_IFS=$IFS
    local to_print= depth=${2-3} width=${3-2} sum=0 one_part
    IFS='.'
    set -- $1
    while test $depth -ge 1; do
        depth=$(( depth - 1 ))
        part=${1-0} ; shift || :
        printf "%0${width}d" "$part"
    done
    IFS=$old_IFS
}

true <<'=cut'
=head2 postgresqlRegisterEC

Register trap on specified error code and message which should be shown.

    postgresqlAssertRpms <return_code> <message>

=over

=item return_code

    Return (exit) code to registration.

=item message

    Message
=cut

postgresqlRegisterEC() {
    local -i ec=$1;
    shift;
    trap | grep ERR$ || trap '__postgresqlOnError ${LINENO}' ERR;
    _postgresqlRegisteredErrors[$ec]="$@";
}


true <<'=cut'
=head2 postgresqlAssertRpms

Check presence one of parametres as RPM package

    postgresqlAssertRpms <package_name1> [package_name2 [package_name3..]]

=over

=item package_name[1..N]

    Packages names which have to be checked.

=back

    Returns zero if at least one of packages is installed or number of packages which weren't found.
=cut

postgresqlAssertRpms() {
    __postgresqlRun "rpm -q $*" 0-$((${#@}-1)) "One of required packages was found";
    RC=$?;
    [[ $RC -lt ${#@} ]] && return 0;
    return $RC;
}


true <<'=cut'
=head2 postgresqlInitDB

Initialize postgresql datadir

    postgresqlStart

=over

=back

Returns 0 when PostgreSQL is successfully initialized, non-zero otherwise.

=cut

postgresqlInitDB() {
#    local distroMajor="$(lsb_release -rs | sed 's/^\([0-9]\+\).*/\1/')";
#    [[ $(lsb_release -i | sed '/Distributor ID/s/Distributor ID:\s\+//') = 'Fedora' ]] && distroMajor="Fedora";
    if rlIsRHEL 5; then
        distroMajor="5";
    elif rlIsRHEL 6; then
        distroMajor="6";
    elif rlIsRHEL 7; then
        distroMajor="7";
    elif rlIsRHEL 8; then
        distroMajor="8";
    else
        distroMajor="Fedora"
    fi

    case ${postgresqlServiceName}:${distroMajor} in
        rh-postgresql12-postgresql:7)
            __postgresqlRun "scl enable rh-postgresql12 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
        rh-postgresql10-postgresql:7)
            __postgresqlRun "scl enable rh-postgresql10 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
        rh-postgresql96-postgresql:7)
            __postgresqlRun "scl enable rh-postgresql96 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
        rh-postgresql96-postgresql:6)
            __postgresqlRun "scl enable rh-postgresql96 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
        rh-postgresql95-postgresql:7)
            __postgresqlRun "scl enable rh-postgresql95 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
            ## ;& that isnt supported on RHEL-5 :-(
        rh-postgresql95-postgresql:6)
            __postgresqlRun "scl enable rh-postgresql95 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
            ## ;& that isnt supported on RHEL-5 :-(
        rh-postgresql94-postgresql:7)
            __postgresqlRun "scl enable rh-postgresql94 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
            ## ;& that isnt supported on RHEL-5 :-(
        rh-postgresql94-postgresql:6)
            __postgresqlRun "scl enable rh-postgresql94 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
            ## ;& that isnt supported on RHEL-5 :-(
        postgresql92-postgresql:7)
            __postgresqlRun "scl enable postgresql92 'postgresql-setup initdb'" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
            ## ;& that isnt supported on RHEL-5 :-(
        postgresql:Fedora)
            ;&
        postgresql:8)
            ;&
        postgresql:7)
            __postgresqlRun "postgresql-setup initdb" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
        postgresql92-postgresql:6)
            __postgresqlRun "service $postgresqlServiceName initdb" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
            ## ;& that isnt supported on RHEL-5 :-(
        postgresql:6)
            __postgresqlRun "service $postgresqlServiceName initdb" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
            ## ;& that isnt supported on RHEL-5 :-(
        postgresql84:5)
            __postgresqlRun "service $postgresqlServiceName initdb" 0 "Initialising the database" || \
                __postgresqlLogTrace "Database initialization failed";
            ;;
        postgresql:5)
            rlServiceStart $postgresqlServiceName;
            rlServiceStop $postgresqlServiceName;
            ;;
        *)
            __postgresqlLogTrace "Unknown version of postgresql";
    esac;
    if [[ -d "$postgresqlDataDir" ]]; then
        if [[ -n "$(ls -A $postgresqlDataDir)" ]]; then
            return 0;
        else
            __postgresqlLogDebug "Datadir is empty!";
            return 1;
        fi
    else
        __postgresqlLogDebug "Datadir doesn't exist!";
        return 1;
    fi
    return 1;
}

true <<'=cut'
=head2 postgresqlStart

Starts PostgreSQL daemon.

    postgresqlStart

=over

=back

Returns 0 when PostgreSQL is successfully started, non-zero otherwise.

=cut

postgresqlStart() {
    files=($(ls $postgresqlDataDir))
    __postgresqlLogDebug "DATADIR: $postgresqlDataDir";
    ## when data directory does not exist or is empty, do initilization
    if [[ ! -d "$postgresqlDataDir" ]] || [[ -d $postgresqlDataDir ]] && [[ ${#files[@]} -eq 0 ]]; then
        [[ -d "$postgresqlDataDir" ]] && __postgresqlRun "[[ $(stat --printf="%a:%U:%G" $postgresqlDataDir) = "700:postgres:postgres" ]]" 0 "Directory has correct permissions"
        ## more debug information when previous one fails
        [[ $? -gt 0 ]] && __postgresqlRun -l "stat $postgresqlDataDir" 1;
        __postgresqlLogDebug "Initial start";
        __postgresqlRun "postgresqlInitDB"
    fi
    rlServiceStart "$postgresqlServiceName"
    sleep 5 # wait for 5 seconds to be sure that service is ready
    __postgresqlRun "service $postgresqlServiceName status"

    return $?
}

true <<'=cut'
=head2 postgresqlStop

Terminate PostgreSQL daemon.

    postgresqlStop

=over

=back

Returns 0 when PostgreSQL is successfully termminated, non-zero otherwise.

=cut

postgresqlStop() {   
   rlServiceStop $postgresqlServiceName
   __postgresqlRun "service $postgresqlServiceName status" 1,3
   [[ $? -gt 0 ]] && return 0 || return 1 
}


true <<'=cut'
=head2 postgresqlCleanup

Clean up DB files of postgresql.

    postgresqlCleanup [port]

=over

=back

Returns 0 if directory exists.

=cut

postgresqlCleanup() {
    if postgresqlStop; then
        if __postgresqlRun "[[ -d '$postgresqlDataDir' ]]" 0 "Directory ${postgresqlDataDir} have to exist!"; then
            __postgresqlLogDebug "$(rm -rfv ${postgresqlDataDir}/* | wc -l) files/directories removed";
            return $?;
        else
            __postgresqlLogTrace "Directory $postgresqlDataDir doesn't exist!";
        fi
    else
        __postgresqlLogTrace "Database is still running. Cleanup incomplete.";
    fi
    return 1;
}

true <<'=cut'
=head2 postgresqlExec

Execute expression (as user).

    postgresqlExecBin <expr> [user]

=over

=item expr

Expression to execute. If it is longer than one command or some parameters
are included then expression must be quoted by double qoutes ("expr").

=item user

Name of user.

=back

Returns return code of executed expression.

=cut

postgresqlExec() {
    local command="$1";
    local user="$2";
    if [[ -n $user ]]; then
        __postgresqlLogDebug "Executing: /bin/su \"$user\" -c \"$command\";"
        /bin/su "$user" -c "$command";
        rCode=$?;
    else
        __postgresqlLogDebug "Executing: $command";
        $command;
        rCode=$?;
    fi
        __postgresqlLogDebug "Exit status: ${rCode}."
    return $rCode;
}


true <<'=cut'
=head2 postgresqlQuery

Execute SQL query / psql internal command in db

    postgresqlQuery schema query

=over

=item schema

DB Schema (db name)

=item query

SQL query or internal command.

=back

Returns 0 on suxcess, print result to STDOUT.

=cut

postgresqlQuery() {
    local schema="$2";
    local query="$1";
    local param="-v ON_ERROR_STOP=ON";
    [[ -n $schema ]] && param="-d $schema";

    echo "$query" | postgresqlExec "psql $param" postgres;
    local RC=$?

    return $RC
}

true <<'=cut'
=head2 postgresqlCreateDB

Create new schema inherited from schema(template1 by default)

    postgresqlQuery name [schema]

=over

=item name

New db name

=item query

DB Schema (db name)

=back

Returns 0 on suxcess.

=cut

postgresqlCreateDB() {
    local name="$1";
    local schema="$2";
    postgresqlQuery "CREATE DATABASE \"${name}\";" "$schema";
    return $?
}

true <<'=cut'
=head2 postgresqlDropDB

Drop database

    postgresqlDropDB name

=over

=item name

Db name

=back

Returns 0 on suxcess.

=cut

postgresqlDropDB() {
    local name="$1";
    postgresqlQuery "DROP DATABASE \"${name}\"";
    return $?
}

true <<'=cut'
=head2 postgresqlCreateLang

Create new lang

    postgresqlQuery name [schema]

=over

=item name

language

=item schema

db name

=back

Returns 0 on suxcess.

=cut

postgresqlCreateLang() {
    local name="$1";
    local schema="$2";
    postgresqlQuery "CREATE LANGUAGE \"${name}\";" "$schema";
    return $?
}

true <<'=cut'
=head2 postgresqlDropLang

Drop language

    postgresqlDropLang name

=over

=item name

language

=item schema

Db name

=back

Returns 0 on suxcess.

=cut

postgresqlDropLang() {
    local name="$1";
    local schema="$2";
    postgresqlQuery "DROP LANGUAGE \"${name}\";" "$schema";
    return $?
}

true <<'=cut'
=head2 postgresqlAddUser

Add user with password.

    postgresqlAddUser user password [schema]

=over

=item user

User name.

=item password

Password for user.

=back

Returns 0 when user is successfully added, non-zero otherwise.

=cut

postgresqlAddUser() {
    local user="$1"
    local pass="$2"
    local schema="$3"

    __postgresqlLogDebug "Creating user '$user' with password $pass";
    postgresqlQuery "CREATE USER \"${user}\" WITH PASSWORD '$pass';" "$schema";
    return $?
}

true <<'=cut'
=head2 postgresqlDeleteUser

Delete user.

    postgresqlDeleteUser user [schema]

=over

=item user

User name to delete.

=item schema

Schema name.

=back

Returns 0 when user is successfully deleted, non-zero otherwise.

=cut

postgresqlDeleteUser() {
    local user="$1"
    local schema="$2"

    postgresqlQuery "DROP USER \"${user}\";" "$schema";
    return $?
}

true <<'=cut'
=head2 postgresqlUDB

Add user, DB and grant acces for user.

    postgresqlUDB dbName user password

=over

=item dbName

Name of DB which will be created.

=item user

User name to create.

=item password

User password.

=back

Returns 0 when all is sucefully created.

=cut

postgresqlUDB() {
    local name="$1";
    local dbUser="$2";
    local password="$3";
    local RC=0;

    __postgresqlLogDebug "Creating database '$name' and user '$dbUser' with password '$password'";
    postgresqlCreateDB "$name";
    RC=$(($RC+$?));
    postgresqlAddUser "$dbUser" "$password";
    RC=$(($RC+$?));
    postgresqlQuery "GRANT ALL PRIVILEGES ON DATABASE \"${name}\" TO \"$dbUser\";" "$name";
    RC=$(($RC+$?));
    return $RC
}


true <<'=cut'
=head2 postgresqlPidFile

Returns postgresql pid file.

    postgresqlPidFile

=over


=back

Returns path to postgresql pid file if exists.

=cut

postgresqlPidFile() {
    ## function postgresqlPidFile is obsoleted by variable
    echo "$postgresqlPidFile";
    __postgresqlLogDebug "Function postgresqlPidFile is obsoleted by global variable with same name"
}


true <<'=cut'
=head2 postgresqlGetPid

Prints PID of the postmaster.

    postgresqlGetPid

=over


=back

Prints process ID of the current parent postmaster process.
Returns exit code 2 if the process is not running.

=cut

postgresqlGetPid() {
    local pidFile=$(postgresqlPidFile);
    if [[ -f "$pidFile" ]]; then
        local pid=$(head -n 1 $pidFile)
    else
        __postgresqlLogTrace "Can't determine pid, file '$pidFile' does not exist"
        return 1;
    fi
    echo $pid
    if ps $pid &>/dev/null ; then
        return 0
    else
        __postgresqlLogTrace "Pid=$pid but process not running"
        return 2
    fi
}


true <<'=cut'
=head2 postgresqlLockFile

Returns postgresql lock file.

    postgresqlLockFile

=over


=back

Returns path to postgresql lock file if exists.

=cut

postgresqlLockFile() {
    echo "${postgresqlLockFile}";
    rlLogWarning "Function postgresqlLockFile is obsoleted by variable postgresqlLockFile";
}

true <<'=cut'
=head2 postgresqlGetDataDir

Returns path to postgresql data dir.

    postgresqlGetDataDir

=over


=back

Returns path to postgresql datadir (or where it may be).

=cut

postgresqlGetDataDir() {
    ## function persist due to compatibility issues, but is obsolete
    rlLogWarning "Function postgresqlGetDataDir is obsoleted by variable postgresqlDataDir";
    echo "$postgresqlDataDir";
}

true <<'=cut'
=head2 postgresqlGetPort

Returns port number where is/can be postgresql binded.

    postgresqlGetPort

=over


=back

Returns postgresql port number.

=cut

postgresqlGetPort() {
    echo $postgresqlDefaultPort
    rlLogWarning "Function postgresqlGetPort is obsoleted by variable postgresqlDefaultPort";
}

true <<'=cut'
=head2 postgresqlChangeAuth

Change authentification method for postgresql server.

    postgresqlChangeAut <method>

=over

=item method

Autentification method, which will be set for all users/hosts.

=back

Returns 0 on suxcess non zero in other cases.

=cut

postgresqlChangeAuth() {
    local method="$1";

    declare -a authMethods=(trust reject md5 password gss sspi krb5 ident peer ldap radius cert pam);
    local configFile="$(echo $postgresqlDataDir/pg_hba.conf | sed -e 's/^\s*//' -e 's/\s*$//')";

## argument validation against array of known auth. methods
    local isValid=false;
    for (( i=0; i<${#authMethods[@]}; i++)); do
        [[ ${authMethods[$i]} == $1 ]] && isValid=true;
    done
    if ! $isValid; then
        __postgresqlLogTrace "Argument '$method' is invalid postgresql authentification method."
        return 128;
    fi

## prepare reg. exp. from know keywords to change auth. method.
    local expression=""
    for (( i=0; i<=${#authMethods[@]}; i++)); do
        case $i in
            0)
                connector="\\(";
            ;;
            ${#authMethods[@]})
                connector="\\)";
            ;;
            *)
                connector="\\|"
            ;;
        esac
        expression="${expression}${connector}${authMethods[i]}";
    done
    expression="${expression}"
    __postgresqlLogDebug "$expression";

    __postgresqlLogDebug "pg_hba.conf: ==>$configFile<==";
    if ! [[ -f $configFile ]]; then
        __postgresqlLogTrace "$configFile does not exist"
        return 1;
    fi

    local tmpFile="$(mktemp)" || { __postgresqlLogTrace "Failed to create temp file"; return 1; }
    __postgresqlLogDebug "\$tmpFile=$tmpFile";
    echo "${FUNCNAME[@]}";

    cat $configFile | while read line; do
        if [[ $line =~ ^\s?'#' ]] || [[ $line == '' ]]; then
            echo $line >/dev/null
        else
            echo $line | sed "s/$expression/$1/"
        fi 
    done > $tmpFile;

    ## copy content from temp file to old config file
    local rc=0;
    cat $tmpFile > $configFile || rc=1;

    rm -f $tmpFile;
    return $rc;
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

postgresqlLibraryLoaded() {
    ## ugly workaround, prevent hanging test due to systemctl
    export PAGER="";
    rlLogInfo "PostgreSQL library constructor."
    if postgresqlAssertRpms postgresql rh-postgresql12 rh-postgresql10 rh-postgresql96 rh-postgresql95 rh-postgresql94 postgresql92 postgresql84; then
        __postgresqlLogDebug "Library database/postgresql is loaded."
        ## order is importatant!
        if rlIsRHEL "<6"; then
            __postgresqlLogDebug "Damm! This is RHEL-5!";
#            rlAssertRpm redhat-lsb || \
#                rlDie "redhat-lsb-core package is neccessary for database/postgresql library.";
        else
            __postgresqlLogDebug "RHEL-6 or later"
#            rlAssertRpm redhat-lsb-core || \
#                rlDie "redhat-lsb-core package is neccessary for database/postgresql library.";
        fi

        # recognize parameter to set collection via tcms case
        [ -n "$RUN_ON_DB" ] && COLLECTIONS="$RUN_ON_DB $COLLECTIONS"
        [ -n "$SYSPATHS" ] && COLLECTIONS="$SYSPATHS $COLLECTIONS"

        ## Set variables according to collection
#        local distroMajor="$(lsb_release -rs | sed 's/^\([0-9]\+\).*/\1/')";
#        [[ $(lsb_release -i | sed '/Distributor ID/s/Distributor ID:\s\+//') = 'Fedora' ]] && distroMajor="Fedora";
        if rlIsRHEL 5; then
            distroMajor="5";
        elif rlIsRHEL 6; then
            distroMajor="6";
        elif rlIsRHEL 7; then
            distroMajor="7";
        elif rlIsRHEL 8; then
            distroMajor="8";
        else
            distroMajor="Fedora"
        fi
        local collection="";
        for collection in $COLLECTIONS; do
            __postgresqlLogDebug "Looking for: '${collection}:${distroMajor}'";
            case ${collection}:${distroMajor} in
                rh-postgresql12:7)
                    __postgresqlLogDebug "Found collection: rh-postgresql12 on RHEL-7";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql12-";
                    if [[ $SYSPATHS == *'rh-postgresql12'* ]]; then
                        __postgresqlLogDebug "SYSPATHS detected, overriding variables";
                        readonly postgresqlServiceName="postgresql";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlPackagePrefix}${postgresqlServiceName}";
                    else
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    fi
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlLogDir="${postgresqlDataDir}/log"
                    break;
                ;;

                rh-postgresql10:7)
                    __postgresqlLogDebug "Found collection: rh-postgresql10 on RHEL-7";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql10-";
                    if [[ $SYSPATHS == *'rh-postgresql10'* ]]; then
                        __postgresqlLogDebug "SYSPATHS detected, overriding variables";
                        readonly postgresqlServiceName="postgresql";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlPackagePrefix}${postgresqlServiceName}";
                    else
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    fi
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlLogDir="${postgresqlDataDir}/log"
                    break;
                ;;

                rh-postgresql96:7)
                    __postgresqlLogDebug "Found collection: rh-postgresql96 on RHEL-7";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql96-";
                    if [[ $SYSPATHS == *'rh-postgresql96'* ]]; then
                        __postgresqlLogDebug "SYSPATHS detected, overriding variables";
                        readonly postgresqlServiceName="postgresql";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlPackagePrefix}${postgresqlServiceName}";
                    else
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    fi
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                rh-postgresql96:6)
                    __postgresqlLogDebug "Found collection: rh-postgresql96 on RHEL-6";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql96-";
                    if [[ $SYSPATHS == *'rh-postgresql96'* ]]; then
                        __postgresqlLogDebug "SYSPATHS detected, overriding variables";
                        readonly postgresqlServiceName="postgresql";
                        readonly postgresqlPidFile="/var/run/${postgresqlPackagePrefix}${postgresqlServiceName}.pid"
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlPackagePrefix}${postgresqlServiceName}";
                    else
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlPidFile="/var/run/${postgresqlServiceName}.pid"
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    fi
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                rh-postgresql95:7)
                    __postgresqlLogDebug "Found collection: rh-postgresql95 on RHEL-7";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql95-";
                    readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                    readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                rh-postgresql95:6)
                    __postgresqlLogDebug "Found collection: rh-postgresql95 on RHEL-6";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql95-";
                    readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="/var/run/${postgresqlServiceName}.pid"
                    readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                rh-postgresql94:7)
                    __postgresqlLogDebug "Found collection: rh-postgresql94 on RHEL-7";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql94-";
                    readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                    readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                rh-postgresql94:6)
                    __postgresqlLogDebug "Found collection: rh-postgresql94 on RHEL-6";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="rh-postgresql94-";
                    readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="/var/opt/rh/${postgresqlPackagePrefix%-}";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="/var/run/${postgresqlServiceName}.pid"
                    readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                postgresql92:7)
                    __postgresqlLogDebug "Found collection: rh-postgresql92 on RHEL-7";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="postgresql92-";
                    readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="${postgresqlRootDir}/var";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                postgresql92:6)
                    __postgresqlLogDebug "Found collection: rh-postgresql92 on RHEL-6";
                    readonly postgresqlCollection=1;
                    readonly postgresqlPackagePrefix="postgresql92-";
                    readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                    readonly postgresqlRootDir="/opt/rh/${postgresqlPackagePrefix%-}/root";
                    readonly postgresqlVarDir="${postgresqlRootDir}/var";
                    readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                    readonly postgresqlDefaultPort=5432;
                    readonly postgresqlPidFile="/var/run/${postgresqlServiceName}.${postgresqlDefaultPort}.pid";
                    readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";    ## possible wrong
                    readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                    readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                    break;
                ;;

                *)
                    __postgresqlLogDebug "Software collection $collection is unknown."
                    ;;
            esac
        done

        readonly postgresqlVersion=$(rpm -q --qf \"%{VERSION}\" ${postgresqlPackagePrefix}postgresql-server)

        if [[ $postgresqlCollection -eq 0 ]]; then
            rlLogInfo "Any collection not found. Trying to match system versions.";
            __postgresqlLogDebug "Possible variants: $PACKAGE $PACKAGES $(rpm -qa --qf "%{NAME}\n" \
                | grep postgresql)";
            local pgVariant="";
            for pgVariant in $PACKAGE $PACKAGES $(rpm -qa --qf "%{NAME}\n" | grep postgresql); do
                case ${pgVariant}:${distroMajor} in
                    postgresql:Fedora)
                        ;&
                    postgresql:8)
                        __postgresqlLogDebug "Found system's postgresql ${postgresqlVersion} on RHEL-8 or above";
                        rlRun "rpm -q libpq" 0 "Checking libpq version"
                        readonly postgresqlCollection=0;
                        readonly postgresqlPackagePrefix="";
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlRootDir="";
                        readonly postgresqlVarDir="${postgresqlRootDir}/var";
                        readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                        readonly postgresqlDefaultPort=5432;
                        readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";    ## possible wrong
                        readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                        local versionNumber=$(version2number $(echo $postgresqlVersion | tr -d \'\"))
                        readonly postgresqlVersionNumber=${versionNumber#0}
                        if [[ $postgresqlVersionNumber -ge $(version2number 10.0) ]]; then
                            readonly postgresqlLogDir="${postgresqlDataDir}/log"
                        else
                            readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                        fi
                        break;
                        ;;

                    postgresql:7)
                        __postgresqlLogDebug "Found system's postgresql on RHEL-7";
                        readonly postgresqlCollection=0;
                        readonly postgresqlPackagePrefix="";
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlRootDir="";
                        readonly postgresqlVarDir="${postgresqlRootDir}/var";
                        readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                        readonly postgresqlDefaultPort=5432;
                        readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";    ## possible wrong
                        readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                        readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                        break;
                        ;;

                    postgresql:6)
                        __postgresqlLogDebug "Found system's postgresql on RHEL-6";
                        readonly postgresqlCollection=0;
                        readonly postgresqlPackagePrefix="";
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlRootDir="";
                        readonly postgresqlVarDir="${postgresqlRootDir}/var";
                        readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                        readonly postgresqlDefaultPort=5432;
                        readonly postgresqlPidFile="${postgresqlDataDir}/postmaster.pid";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";    ## possible wrong
                        readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                        readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                        break;
                        ;;

                    postgresql84:5)
                        __postgresqlLogDebug "Found system's postgresql84 on RHEL-5";
                        readonly postgresqlCollection=0;
                        readonly postgresqlPackagePrefix="";
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlRootDir="";
                        readonly postgresqlVarDir="${postgresqlRootDir}/var";
                        readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                        readonly postgresqlDefaultPort=5432;
                        readonly postgresqlPidFile="/var/lib/pgsql/data/postmaster.pid";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";    ## possible wrong
                        readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql84"
                        readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                        break;
                        ;;

                    postgresql:5)
                        __postgresqlLogDebug "Found system's postgresql on RHEL-5";
                        readonly postgresqlCollection=0;
                        readonly postgresqlPackagePrefix="";
                        readonly postgresqlServiceName="${postgresqlPackagePrefix}postgresql";
                        readonly postgresqlRootDir="";
                        readonly postgresqlVarDir="${postgresqlRootDir}/var";
                        readonly postgresqlDataDir="${postgresqlVarDir}/lib/pgsql/data/";
                        readonly postgresqlDefaultPort=5432;
                        readonly postgresqlPidFile="/var/lib/pgsql/data/postmaster.pid";
                        readonly postgresqlLockFile="/var/lock/subsys/${postgresqlServiceName}";    ## possible wrong
                        readonly postgresqlMainPackage="${postgresqlPackagePrefix}postgresql"
                        readonly postgresqlLogDir="${postgresqlDataDir}/pg_log"
                        break;
                        ;;

                    *)
                        __postgresqlLogDebug "Variation ${pgVariant} on ${distroMajor} not found!";
                        ;;

                esac;
            done;
        fi;

        # Some information about library on the screen
        if [[ -n "$COLLECTIONS" ]]; then
            rlLogDebug "******** Software collections detected **********"
            rlLogDebug "\$COLLECTIONS=\"$COLLECTIONS\""
        fi
        rlLogDebug "*************** Library variables ***************"
        set | sed -ne '/^postgresql[a-zA-Z]\+=/s/=/="/' -e '/^postgresql[a-zA-Z]\+=/s/$/"/p' | while read line; do
            rlLogDebug "\$${line}";
        done
        rlLogDebug "*************** Library routines ****************"
        set | grep -E '^postgresql[a-zA-Z]+\s()' | grep -v "$FUNCNAME" | while read line; do
            rlLogDebug "$line";
        done
        if [[ $postgresqlCollection -eq 1 ]]; then
            rlLogDebug "********** Key RHSCL packages versions **********";
                rpm -q ${postgresqlPackagePrefix%-} &>/dev/null && \
                    rlLogDebug "${postgresqlPackagePrefix%-}: \
                    $(rpm -q --qf \"%{VERSION}-%{RELEASE}\" ${postgresqlPackagePrefix%-})";
                rpm -q ${postgresqlPackagePrefix}runtime &>/dev/null && \
                    rlLogDebug "${postgresqlPackagePrefix}runtime: \
                    $(rpm -q --qf \"%{VERSION}-%{RELEASE}\" ${postgresqlPackagePrefix}runtime)";
                rpm -q ${postgresqlPackagePrefix}postgresql-server &>/dev/null && \
                    rlLogDebug "${postgresqlPackagePrefix}postgresql-server: \
                    $(rpm -q --qf \"%{VERSION}-%{RELEASE}\" ${postgresqlPackagePrefix}postgresql-server)";
            rlLogDebug "*************************************************";

            ## Check enviroment settings (is tortilla working?)
            pid=$$;

            while [[ pid -ne 1 ]]; do
                [[ $(ps h -o comm $pid) = "scl" ]] && break;
                pid=$(ps h -o ppid $pid);
            done

            if [[ $pid -eq 1 ]]; then
                rlLogError "There is no procesess 'scl' detected as predecesor, is tortilla working?"
            fi

            for tuple in $(sed -n -e '/export/s/^\s*export\s\+\([A-Z0-9_]\+\)=\([a-zA-Z0-9\/]\+\).*/\1;\2/p' \
                    /opt/rh/${postgresqlPackagePrefix%-}/enable); do
                varName="$(echo $tuple | cut -d ';' -f 1)";
                expectedValue="$(echo $tuple | cut -d ';' -f 2)";
                if ! echo "${!varName}" | grep -q "${expectedValue}"; then
                    rlLogError "${varName} doesn't contain ${expectedValue}";
                fi
            done;
        else
            rlLogInfo "*************************************************";
        fi


        return 0
    else
        __postgresqlLogTrace "Package postgresql is not installed."
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
Jakub Prokes <jprokes@redhat.com>
Vacla Danek <vdanek@redhat.com>

=back

=cut
