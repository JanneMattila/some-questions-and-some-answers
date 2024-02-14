# Do not return PowerShell objects because you cannot easily parse them from output
# https://github.com/Azure/azure-powershell/issues/9827
# So instead of this:
# [PSCustomObject][ordered]@{
#     Result1 = (Get-Date).ToString("yyyyMMddHHmmss")
#     Result2 = (Get-Date).DayOfWeek
#     Result3 = (Get-Date).Hour
#     Result4 = (Get-Date).Minute
# }
# Return a string that can be easily parsed:
(Get-Date).ToString("yyyyMMddHHmmss") + "," + (Get-Date).DayOfWeek + "," + (Get-Date).Hour + "," + (Get-Date).Minute