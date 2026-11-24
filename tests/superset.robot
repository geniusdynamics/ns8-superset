*** Settings ***
Library    SSHLibrary
Library    String

*** Variables ***
${TEST_HOST}    superset.ns8-ci.test

*** Test Cases ***
Install superset
    ${output}    ${rc}=    Execute Command    add-module ${IMAGE_URL} 1    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${result}=    Evaluate    ast.literal_eval($output)    modules=ast
    Set Suite Variable    ${module_id}    ${result}[module_id]

Secrets are generated with restricted permissions
    ${rc}=    Execute Command
    ...    runagent -m ${module_id} bash -c 'cd "$AGENT_STATE_DIR" && test "$(stat -c %a postgres.env superset.env admin.env | sort -u)" = 600'
    ...    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${output}    ${rc}=    Execute Command
    ...    runagent -m ${module_id} bash -c 'grep -c "^SUPERSET_SECRET_KEY=.\\{32,\\}" "$AGENT_STATE_DIR"/superset.env'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0

Configure superset
    ${rc}=    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false,"http2https":true}'    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0

Configure rejects an invalid hostname
    ${rc}=    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"not_a_valid_host","lets_encrypt":false}'    return_stdout=False    return_rc=True
    Should Not Be Equal As Integers    ${rc}    0

Get configuration returns the settings and no secret
    ${output}    ${rc}=    Execute Command    api-cli run module/${module_id}/get-configuration    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${config}=    Evaluate    json.loads($output)    modules=json
    Should Be Equal    ${config}[output][host]    ${TEST_HOST}
    Should Be True    ${config}[output][http2https]
    ${password}=    Get admin password
    Should Not Contain    ${output}    ${password}
    Should Not Contain    ${output.lower()}    secret_key

Health endpoint answers
    Wait Until Keyword Succeeds    10 min    5 sec    Check Health

Login page is served
    ${output}    ${rc}=    Execute Command
    ...    curl -ksS -w '%{http_code}' --resolve ${TEST_HOST}:443:127.0.0.1 https://${TEST_HOST}/login/
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    Superset
    Should End With    ${output}    200

Initial administrator can sign in
    ${password}=    Get admin password
    ${output}    ${rc}=    Execute Command
    ...    curl -ksS --resolve ${TEST_HOST}:443:127.0.0.1 -H 'Content-Type: application/json' -d '{"username":"admin","password":"${password}","provider":"db"}' https://${TEST_HOST}/api/v1/security/login
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Contain    ${output}    access_token

Backup state is produced and cleaned up
    ${rc}=    Execute Command
    ...    runagent -m ${module_id} bash -ec 'cd "$AGENT_STATE_DIR" && "$AGENT_INSTALL_DIR/bin/module-dump-state" && test -s superset.pg_dump && test "$(stat -c %a superset.pg_dump)" = 600 && for f in $(grep ^state/ "$AGENT_INSTALL_DIR/etc/state-include.conf"); do test -e "$f" || { echo missing $f >&2; exit 1; }; done'
    ...    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${rc}=    Execute Command
    ...    runagent -m ${module_id} bash -ec 'cd "$AGENT_STATE_DIR" && "$AGENT_INSTALL_DIR/bin/module-cleanup-state" && test ! -e superset.pg_dump'
    ...    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0

Dump restores into an empty database
    # Same procedure as restore-module/40restore-postgres, on a fresh module
    ${rc}=    Execute Command
    ...    runagent -m ${module_id} bash -ec 'cd "$AGENT_STATE_DIR" && "$AGENT_INSTALL_DIR/bin/module-dump-state" && systemctl --user stop superset.service && podman volume rm superset-db && "$AGENT_INSTALL_DIR/actions/restore-module/40restore-postgres" && systemctl --user start superset.service superset-db.service superset-web.service && "$AGENT_INSTALL_DIR/bin/module-cleanup-state"'
    ...    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    10 min    5 sec    Check Health
    ${password}=    Get admin password
    ${output}    ${rc}=    Execute Command
    ...    curl -ksS --resolve ${TEST_HOST}:443:127.0.0.1 -H 'Content-Type: application/json' -d '{"username":"admin","password":"${password}","provider":"db"}' https://${TEST_HOST}/api/v1/security/login
    ...    return_rc=True
    Should Contain    ${output}    access_token

Remove superset
    ${rc}=    Execute Command    remove-module --no-preserve ${module_id}    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0

*** Keywords ***
Check Health
    ${rc}=    Execute Command    curl -kfsS --resolve ${TEST_HOST}:443:127.0.0.1 https://${TEST_HOST}/health >/dev/null    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0

Get admin password
    ${output}    ${rc}=    Execute Command    runagent -m ${module_id} superset-initial-credentials    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${password}=    Get Regexp Matches    ${output}    Password: (\\S+)    1
    RETURN    ${password}[0]
