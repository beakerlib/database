# NAME

database/postgresql - set of basic functions for PostgreSQL

# DESCRIPTION

This is basic library for PostgreSQL.

# VARIABLES

Below is the list of global variables. When writing a new library,
please make sure that all global variables start with the library
prefix to prevent collisions with other libraries.

- postgresqlServiceName

    Name of service.

- postgresqlCollection

    Set to 1 when running in collection. 0 otherwise.

- postgresqlPackagePrefix

    Prefix which differ RHSCL package name from distribution.
    Where no software collection set is empty.

- postgresqlRootDir

    Path prefix for RHSCL root.

# FUNCTIONS

## version2number

Formates version to comparable number

    version2number <version>

- version

        Version aka 9.6

    Comparable number

## postgresqlRegisterEC

Register trap on specified error code and message which should be shown.

    postgresqlAssertRpms <return_code> <message>

- return\_code

        Return (exit) code to registration.

- message

        Message

## postgresqlAssertRpms

Check presence one of parametres as RPM package

    postgresqlAssertRpms <package_name1> [package_name2 [package_name3..]]

- package\_name\[1..N\]

        Packages names which have to be checked.

    Returns zero if at least one of packages is installed or number of packages which weren't found.

## postgresqlInitDB

Initialize postgresql datadir

    postgresqlStart

    Returns 0 when PostgreSQL is successfully initialized, non-zero otherwise.

## postgresqlStart

Starts PostgreSQL daemon.

    postgresqlStart

Returns 0 when PostgreSQL is successfully started, non-zero otherwise.

## postgresqlStop

Terminate PostgreSQL daemon.

    postgresqlStop

Returns 0 when PostgreSQL is successfully termminated, non-zero otherwise.

## postgresqlCleanup

Clean up DB files of postgresql.

    postgresqlCleanup [port]

Returns 0 if directory exists.

## postgresqlExec

Execute expression (as user).

    postgresqlExecBin <expr> [user]

- expr

    Expression to execute. If it is longer than one command or some parameters
    are included then expression must be quoted by double qoutes ("expr").

- user

    Name of user.

Returns return code of executed expression.

## postgresqlQuery

Execute SQL query / psql internal command in db

    postgresqlQuery schema query

- schema

    DB Schema (db name)

- query

    SQL query or internal command.

Returns 0 on suxcess, print result to STDOUT.

## postgresqlCreateDB

Create new schema inherited from schema(template1 by default)

    postgresqlQuery name [schema]

- name

    New db name

- query

    DB Schema (db name)

Returns 0 on suxcess.

## postgresqlDropDB

Drop database

    postgresqlDropDB name

- name

    Db name

Returns 0 on suxcess.

## postgresqlCreateLang

Create new lang

    postgresqlQuery name [schema]

- name

    language

- schema

    db name

Returns 0 on suxcess.

## postgresqlDropLang

Drop language

    postgresqlDropLang name

- name

    language

- schema

    Db name

Returns 0 on suxcess.

## postgresqlAddUser

Add user with password.

    postgresqlAddUser user password [schema]

- user

    User name.

- password

    Password for user.

Returns 0 when user is successfully added, non-zero otherwise.

## postgresqlDeleteUser

Delete user.

    postgresqlDeleteUser user [schema]

- user

    User name to delete.

- schema

    Schema name.

Returns 0 when user is successfully deleted, non-zero otherwise.

## postgresqlUDB

Add user, DB and grant acces for user.

    postgresqlUDB dbName user password

- dbName

    Name of DB which will be created.

- user

    User name to create.

- password

    User password.

Returns 0 when all is sucefully created.

## postgresqlPidFile

Returns postgresql pid file.

    postgresqlPidFile

Returns path to postgresql pid file if exists.

## postgresqlGetPid

Prints PID of the postmaster.

    postgresqlGetPid

Prints process ID of the current parent postmaster process.
Returns exit code 2 if the process is not running.

## postgresqlLockFile

Returns postgresql lock file.

    postgresqlLockFile

Returns path to postgresql lock file if exists.

## postgresqlGetDataDir

Returns path to postgresql data dir.

    postgresqlGetDataDir

Returns path to postgresql datadir (or where it may be).

## postgresqlGetPort

Returns port number where is/can be postgresql binded.

    postgresqlGetPort

Returns postgresql port number.

## postgresqlChangeAuth

Change authentification method for postgresql server.

    postgresqlChangeAut <method>

- method

    Autentification method, which will be set for all users/hosts.

Returns 0 on suxcess non zero in other cases.

# AUTHORS

- Branislav Blaskovic <bblaskov@redhat.com>
Jakub Prokes <jprokes@redhat.com>
Vacla Danek <vdanek@redhat.com>
