#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k ft=beakerlib
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/database/postgresql
#   Description: Set of basic functions for postgresql
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

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1


rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport database/postgresql" || rlDie "Loading of 'database/postgresql' library failed."
    rlPhaseEnd

    rlPhaseStartTest "Internal methods selftest";
        rlRun -t -l "__postgresqlLogDebug \"Fake debug message\"";
        rlRun -t -l "__postgresqlLogTrace \"Fake trace message\"";
        postgresqlRegisterEC 127 "File not found, typo in test?";
        rlRun "[[ ${!_postgresqlRegisteredErrors[@]} -eq 127 ]]" 0 "Return code 127 registered";
        trap | rlRun "grep 'ERR$'" 0 "Trap is set";
    rlPhaseEnd

    rlPhaseStartTest "API Selftest"
        rlLog "PostgreSQL service name: $postgresqlServiceName";
        rlRun "postgresqlExec 'psql --version' postgres";
        ls -lah ${postgresqlDataDir}
        rlRun "postgresqlCleanup";
        rlRun "postgresqlInitDB";
        rlRun -l "postgresqlGetDataDir";
        rlRun "postgresqlChangeAuth trust";
        rlRun -l "cat ${postgresqlDataDir}/pg_hba.conf | grep -v '^\\\s\\\?#'";
        rlRun "postgresqlStart";
        rlRun "postgresqlGetPort";
        rlRun "postgresqlPidFile";
        rlRun "postgresqlCreateDB \"anyBase\"";
        rlRun "postgresqlAddUser strangeuser commonPass";
        rlRun "postgresqlUDB \"fOo\" \"fOo\" \"bar\"";
        postgresqlQuery "\\\l";
        postgresqlQuery "\\\du";
        rlRun "postgresqlDropDB fOo";
        postgresqlQuery "\\\l";
        rlRun "postgresqlDeleteUser fOo";
        postgresqlQuery "\\\du";
        rlRun "postgresqlStop";
        rlRun "postgresqlCleanup";
    rlPhaseEnd

    rlPhaseStart WARN "This phase should fail";
        #foo;
    rlPhaseEnd

    rlPhaseStartCleanup
        rlPass "Nothing to do";
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
