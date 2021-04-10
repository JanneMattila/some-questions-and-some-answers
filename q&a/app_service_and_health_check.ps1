$appServiceName = "healthcheck000001"
$resourceGroup = "rg-health-check"

$uri = "https://" + $(az webapp show --name $appServiceName --resource-group $resourceGroup --query hostNames[0] -o tsv)
$uri

$targetServer = (Invoke-RestMethod -DisableKeepAlive -Uri $uri/api/healthcheck).server
"Health check target server: $targetServer"

$livenessDelay = 5
$livenessDelayIncrement = 15
$totalMilliseconds = 1000 * 60 * 10 # 10 minutes

while ($livenessDelay -lt 200) {
    "Started new round: delay $livenessDelay seconds"
    $roundStartTime = Get-Date
    $servers = @{}

    # Change health check response delay time for our target server
    while ($true) {
        $json = @{
            liveness              = $true # Health check is 👍
            livenessDelay         = $livenessDelay # Delay in health check response
            condition             = $targetServer
        }

        $body = ConvertTo-Json $json
        $updateResponse = Invoke-RestMethod -Body $body -ContentType "application/json" -Method "POST" -DisableKeepAlive -Uri "$uri/api/healthcheck" -SkipHttpErrorCheck
        if ($updateResponse.server -ne $targetServer) {
            "Not target server: $targetServer (was $($updateResponse.server))"
            continue
        }

        "Health check delay changed to $livenessDelay"
        break
    }

    while ($totalMilliseconds -gt 0) {
        $startTime = Get-Date
        try {
            $response = Invoke-RestMethod -DisableKeepAlive -Uri "$uri/api/healthcheck"
            $servers[$response.server]++

            $endTime = Get-Date
            $executionTime = ($endTime - $startTime).TotalMilliseconds -as [int]
            $roundProgressTime = ($endTime - $roundStartTime).TotalSeconds -as [int]
            $serverList = $servers | ConvertTo-Json -Compress
            Write-Output "$roundProgressTime $executionTime $($response.server) $serverList"
            $totalMilliseconds -= $executionTime
        }
        catch {
            Write-Output "Request failed"
        }

        Start-Sleep -Seconds 1
        $totalMilliseconds -= 1000 # 5 seconds
    }

    $livenessDelay += $livenessDelayIncrement
}
