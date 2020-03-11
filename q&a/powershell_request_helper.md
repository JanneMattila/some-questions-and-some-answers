# PowerShell web request Helper

Sometimes you need to test your web apps or rest APIs
when you're doing updates to see if there is noticable
impact to the end users. Here's example helper that
you can use to test that:

```powershell
Param (
    [Parameter(Mandatory=$true)] [string] $Url,
    [int] $Delay = 10,
    [int] $Count = 99999,
    [int] $TimeoutValue = 99999
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

For ($i=0; $i -lt $Count; $i++)
{
    $startTime = Get-Date
    try
    {
        $response = Invoke-WebRequest -Method GET -Uri $Url -DisableKeepAlive
        if ($response.StatusCode -ne 200)
        {
            Write-Output "$TimeoutValue"
        }
        else
        {
            $endTime = Get-Date
            $executionTime = ($endTime - $startTime).TotalMilliseconds -as [int]
            Write-Output "$executionTime ($Delay)"
        }
    }
    catch
    {
        Write-Output "Request failed"
    }

    if ([Console]::KeyAvailable)
    {
        $pressedKey = [Console]::ReadKey($true)
        $change = $Delay * 0.1
        if ($change -lt 1)
        {
            $change = 1
        }
        switch ($pressedKey.Key)
        {
            UpArrow
            {
                $Delay += $change
            }
            DownArrow
            {
                $Delay -= $change
                if (0 -gt $Delay)
                {
                    $Delay = 0
                }
            }
            Default {}
        }
    }

    Start-Sleep -Milliseconds $Delay
}
```

Save it to e.g. `WebTester.ps1` and use it like this:

```powershell
.\WebTester.ps1 -Url http://localhost:32000/api/games?api-version=1 -Delay 50
```

Above invokes target url every 50 milliseconds. You can change the
delay on the fly using up and down arrows. 
