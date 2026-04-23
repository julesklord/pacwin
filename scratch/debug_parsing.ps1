Import-Module ./pacwin.psm1 -Force
function test-parsing {
    pacwin -S "wget" -Manager winget -WhatIf
}
test-parsing
