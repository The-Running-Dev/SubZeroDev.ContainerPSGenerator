@{
    Commands = @(
        @{
            Name        = 'Invoke-Example'
            Description = 'Runs the example container command.'

            Parameters = @(
                @{
                    Name      = 'Message'
                    Type      = 'string'
                    Mandatory = $true
                }
            )
        }
    )
}
