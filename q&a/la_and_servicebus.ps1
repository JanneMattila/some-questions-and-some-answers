$serviceBusNamespace = "sb2lademo"
$queue = "no-sessions"

$url = "https://$serviceBusNamespace.servicebus.windows.net/$queue/messages?api-version=2014-01"
$url

$accessToken = ConvertTo-SecureString -AsPlainText -String (az account get-access-token --resource https://servicebus.azure.net --query accessToken -o TSV)
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
        "appinfoB" = 123
        "appinfoC" = $true
    }
}
$body

Invoke-RestMethod `
    -Body $body `
    -ContentType "application/atom+xml;type=entry;charset=utf-8" `
    -Method "POST" `
    -Authentication Bearer `
    -Token $accessToken `
    -Uri $url
