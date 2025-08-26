# Example:
# .\scan-vm-sku-details.ps1 -Locations "west europe","north europe" -VirtualMachineSKUs "Standard_E4a_v4","Standard_E32a_v4"
param (
    [Parameter(HelpMessage = "Prefix of the output file names.")]
    [string]$OutputFilePrefix = "vm-scan",

    [Parameter(HelpMessage = "Azure regions")]
    [string[]]$Locations,

    [Parameter(HelpMessage = "Virtual machine SKUs e.g., Standard_E4a_v4")]
    [string[]]$VirtualMachineSKUs
)

function Convert-ListPropertiesToString {
    param($obj)
    $custom = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        if (-not $prop.IsGetOnly) {
            $val = $prop.Value
            if ($prop.Name -eq 'Capabilities' -and $val) {
                $custom[$prop.Name] = ($val | ForEach-Object { "$( $_.Name )=$( $_.Value )" }) -join ","
            } elseif ($prop.Name -eq 'Restrictions' -and $val) {
                $custom[$prop.Name] = ($val | ForEach-Object {
                    $type = $_.Type
                    $values = $_.Values -join ","
                    $reason = $_.ReasonCode
                    "Type=$type;Values=$values;ReasonCode=$reason"
                }) -join "|"
            } elseif ($prop.Name -eq 'Costs' -and $val) {
                $custom[$prop.Name] = ($val | ForEach-Object { "${($_.MeterRegion)}:${($_.MeterID)}:${($_.Unit)}:${($_.Amount)}" }) -join ","
            } elseif ($prop.Name -eq 'LocationInfo' -and $val) {
                $custom[$prop.Name] = ($val | ForEach-Object {
                    $loc = $_.Location
                    $zones = if ($_.Zones) { $_.Zones -join "," } else { "" }
                    $zoneDetails = if ($_.ZoneDetails) { ($_.ZoneDetails | Measure-Object).Count } else { "" }
                    $extLoc = $_.ExtendedLocations
                    $type = $_.Type
                    "Location=$loc;Zones=$zones;ZoneDetails=$zoneDetails;ExtendedLocations=$extLoc;Type=$type"
                }) -join "|"                
            } elseif ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                $custom[$prop.Name] = ($val -join ",")
            } else {
                $custom[$prop.Name] = $val
            }
        }
    }
    return [PSCustomObject]$custom
}

$resultCsv = @()
$resultJson = @()

foreach ($location in $Locations) {
    foreach ($vmSku in $VirtualMachineSKUs) {
        $sku = Get-AzComputeResourceSku -Location $location  | Where-Object {$_.ResourceType -eq "virtualMachines" -and $_.name -eq $vmSku}
        if ($sku) {
            foreach ($item in $sku) {
                $resultCsv += Convert-ListPropertiesToString $item
                $resultJson += $item
            }
        }
    }
}

$resultCsv | Export-Csv -Path "$OutputFilePrefix.csv" -Delimiter ";" -NoTypeInformation
$resultJson | ConvertTo-Json -Depth 10 | Set-Content -Path "$OutputFilePrefix.json"

"Scan completed successfully."
