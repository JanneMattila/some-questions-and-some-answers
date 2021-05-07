
# Relevant links:
# https://docs.microsoft.com/en-us/rest/api/servicebus/send-message-to-queue

$serviceBusNamespace = "sb2lademo"
$queue = "q"

$url = "https://$serviceBusNamespace.servicebus.windows.net/$queue/messages?api-version=2014-01"
$url

$accessToken = ConvertTo-SecureString -AsPlainText -String (az account get-access-token --resource https://servicebus.azure.net --query accessToken -o TSV)

$count = 100
for ($i = 0; $i -lt $count; $i++) {
    Write-Progress -Activity "Send messages" -Status "$i / $count" -PercentComplete ($i/$count*100)
    $body = ConvertTo-Json @{
        "specversion"     = "1.0"
        "type"            = "ERP.Sales.Order.Created"
        "source"          = "/mycontext"
        "subject"         = $null
        "id"              = "C1234-1234-1234"
        "time"            = [System.DateTime]::UtcNow
        "datacontenttype" = "application/json"
        "data"            = @{
            "appinfoA" = "abc"
            "appinfoB" = 1
            "appinfoC" = $true
        }
    }

    Invoke-RestMethod `
        -Body $body `
        -ContentType "application/atom+xml;type=entry;charset=utf-8" `
        -Method "POST" `
        -Authentication Bearer `
        -Token $accessToken `
        -Uri $url    
}
