# Variables
$tenantId = "<your tenant id>"
$clientID = "<your service principal Application (client) ID>"
$clientSecret = "<your service principal secret>"
$clientPassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($clientID, $clientPassword)

###############################
#  _                _
# | |    ___   __ _(_)_ __
# | |   / _ \ / _` | | '_ \
# | |__| (_) | (_| | | | | |
# |_____\___/ \__, |_|_| |_|
#             |___/
###############################

Connect-AzAccount -Credential $credentials -ServicePrincipal -TenantId $tenantId

# OR
$thumbprint = "<your thumbprint>"
Connect-AzAccount -ServicePrincipal -ApplicationId $clientID -Tenant $tenantId -CertificateThumbprint $thumbprint

################################
#  _____     _
# |_   _|__ | | _____ _ __
#   | |/ _ \| |/ / _ \ '_ \
#   | | (_) |   <  __/ | | |
#   |_|\___/|_|\_\___|_| |_|
# 
################################

(Get-AzAccessToken -ResourceUrl https://management.azure.com/).Token | clip
# Study token content in https://jwt.ms

###################### 
#     _    ____ ___
#    / \  |  _ \_ _|
#   / _ \ | |_) | |
#  / ___ \|  __/| |
# /_/   \_\_|  |___|
######################


# You can use basic PowerShell capabilities:
$body = ConvertTo-Json @{
    "specversion" = "1.0"
    "id"          = "C1234-1234-1234"
    "data"        = @{
        "appinfoC" = $true
    }
}

Invoke-RestMethod -Uri $url
Invoke-WebRequest -UseBasicParsing -Uri $url
Invoke-RestMethod `
    -Body $body `
    -ContentType "application/atom+xml;type=entry;charset=utf-8" `
    -Method "POST" `
    -Authentication Bearer `
    -Token $accessToken `
    -Uri $url

# Better way is to use Invoke-AzRestMethod:
Get-Help Invoke-AzRestMethod

Invoke-AzRestMethod `
    -Method "GET" `
    -Path $url

Invoke-AzRestMethod `
    -Method "POST" `
    -Payload $body `
    -Path $url
