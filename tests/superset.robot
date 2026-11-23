*** Settings ***
Library    SSHLibrary

*** Variables ***
${TEST_HOST}    superset.ns8-ci.test

*** Test Cases ***
Install superset
    ${output}    ${rc}=    Execute Command    add-module ${IMAGE_URL} 1    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    ${result}=    Evaluate    ast.literal_eval($output)    modules=ast
    Set Suite Variable    ${module_id}    ${result}[module_id]

Configure superset
    ${rc}=    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false}'    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0

Check Web Response
    Wait Until Keyword Succeeds    5 min    5 sec    Check Health

Remove superset
    ${rc}=    Execute Command    remove-module --no-preserve ${module_id}    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0

*** Keywords ***
Check Health
    ${rc}=    Execute Command    curl -kfsS --resolve ${TEST_HOST}:443:127.0.0.1 https://${TEST_HOST}/health >/dev/null    return_stdout=False    return_rc=True
    Should Be Equal As Integers    ${rc}    0
