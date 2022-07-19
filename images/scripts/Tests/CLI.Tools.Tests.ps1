
Describe "Azure CLI" {
    It "Azure CLI" {
        "az --version" | Should -ReturnZeroExitCode
    }
}
