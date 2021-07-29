Function Get-EikonVersion{
    <#
    .SYNOPSIS
    Function to check version of Eikon instead in a machine
    by Steven Wight
    .DESCRIPTION
    Get-EikonVersion -ComputerName <Hostname> -Domain <domain> (default = POSHYT)
    .EXAMPLE
    Get-EikonVersion Computer01
    .Notes
    You may need to Edit the Path to the override config file depending where Eikon is installed on your environment (find $OverideConfigPath)
    #>
    [CmdletBinding()]
    Param(
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $ComputerName,  
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $Domain = "POSHYT" 
    )

    #Clear Variables encase function has been used before in session (never know!)   
    $Computer = $EikonExePath = $EikonVer = $EikonFileVer = $uptime = $AdCheck = $OverideConfigPath = $DACSData = $DACSID = $job = $null

        # Get Computer info from AD
        try{
            $Computer = (Get-ADComputer $ComputerName -properties DNSHostname -server $Domain -ErrorAction stop | Select-Object DNSHOSTNAME).DNSHostname
            $AdCheck = $true
        }Catch{
            Write-Host -ForegroundColor Red "Machine $($ComputerName) not found in AD"
            $Computer = $_.Exception.Message
            $AdCheck = $false
        }

        # Check machine is online 
        if($True -eq $AdCheck){   
            $PathTest = Test-Connection -Computername $Computer -BufferSize 16 -Count 1 -Quiet
        } #End of If ADcheck is True

        #if Machine is online
        if($True -eq $PathTest) {
            
            #Output machine is online to the console
            Write-host -ForegroundColor Green "$($ComputerName) is online"
            #Get Eikon Version do as Job encase of hangs
            try{
            $job = (Get-WmiObject  win32_product -ComputerName $Computer -erroraction silentlycontinue  -AsJob  | Wait-Job -Timeout 180)
            
            if ($job.State -ne 'Completed') {
                Write-Host "$($ComputerName) timed out after 3 minute."
                $EikonVer = "TimeOut"
            }
            $EikonVer = $job | Receive-Job | where-object -property Name -like "*Eikon*"  
            }catch{ #Store error message if there was a issue
            $EikonVer = $_.Exception.Message
            }
            #If it can't find Eikon as an installed app
            if($null -eq $EikonVer){

                #Set $EikonVer with not installed message
                [string]$EikonVer = "Eikon not installed"
            }else{
                
                #Put Version in as string
                $EikonVer = [string]$EikonVer.Version
            }#End of if $EikonVer is Null

            #Get DACS ID from OverrideConfiguration.XML
            Try{
                $EikonPath = (Get-ChildItem -path "\\$($Computer)\c$\Program Files (x86)\Thomson Reuters\Eikon\" -Directory -erroraction silentlycontinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1) 
                $OverideConfigPath = "$($EikonPath.FullName)\Config\OverrideConfiguration.xml"
                [XML]$DACSData = Get-Content $OverideConfigPath -erroraction silentlycontinue
                $DACSID = $DACSData.Setting.ChildNodes | Where-Object -Property Name -EQ "COMMON.PIXL.CUSTOMERMANAGED.DEFAULT.AUTHENTICATION.STANDARD.USERNAME"
                $DACSID = $DACSID.'#text'
            }catch{ #Store error message if there was a issue
                $DACSID = $_.Exception.Message
            }

            #If it can't find any DACS ID
            if($null -eq $DACSID){

                #Set $VDAversion with not installed message
                $DACSID = "DACS ID not found"
            } #End of if $DACSData is Null

            # Get Machine uptime
            Try{
                $uptime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem -ComputerName $Computer).LastBootUpTime) 
                $uptime = "$($Uptime.Days) D $($Uptime.Hours) H $($Uptime.Minutes) M"
            }catch{# any issues store error in $uptime
                $uptime = $_.Exception.Message
            }#End of Try..Catch for uptime

            #Get Eikon.exe file version
            Try{
                $EikonExePath = "$($EikonPath.FullName)\bin\Eikon.exe" 
                $EikonFileVer = (Get-ChildItem $EikonExePath -erroraction SilentlyContinue).VersionInfo.FileVersion 
            }catch{ #Store error message if there was a issue
                $EikonFileVer = $_.Exception.Message
            }

            if($null -eq $EikonFileVer){
            $EikonFileVer = "Can't Find Eikon.exe"}
            
            #output info to console
            Write-host "$Computer, $EikonVer,$EikonFileVer, $DACSID, $uptime"

            #Return Info
            return $Computer, $EikonVer,$EikonFileVer, $DACSID, $uptime

        }else{#If machine wasn't online 
            
            #Output machine is online to the console
            Write-host -ForegroundColor Red "$($ComputerName) is offline"

            $EikonVer = "Offline"
            $EikonFileVer = "Offline"
            $DACSID = "Offline"
            $uptime = "Offline"

            #Return Info
            return $Computer, $EikonVer,$EikonFileVer, $DACSID, $uptime

        }# End of If
}# end of Function

Function Get-EikonVersionListFromCSV{
    <#
    .SYNOPSIS
    Function to pull Eikon info from List of CSV to CSV
    by Steven Wight
    .DESCRIPTION
    Get-EikonVersionListFromCSV -Inputfile <Input file of hostnames> Default = "C:\temp\Posh_inputs\EikonHostnames.csv"
    -OutputFile <Name and loacation of output csv> Default = "C:\temp\Posh_outputs\EikonVersion_$(get-date -f yyyy-MM-dd-HH).csv",
    -Domain <domain> (default = POSHYT)
    .EXAMPLE
    Get-EikonVersionListFromCSV 
    .Notes
    You need to have load function Get-EikonVersion or Imported Module CIB_Refinitiv_Tools to use this
    #>
    [CmdletBinding()]
    Param(
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $Inputfile = "C:\temp\Posh_inputs\EikonHostnames.csv" ,
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $OutputFile = "C:\temp\Posh_outputs\EikonVersion_$(get-date -f yyyy-MM-dd-HH).csv",   
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $Domain = "POSHYT" 
    )

#Loop through the Computer Names in $Inputfile CSV
    Import-CSV $Inputfile -Header ComputerName | Foreach-Object{

        #Clear Variables at start of loop
        $ComputerName = $Computer = $EikonVer = $EikonFileVer = $DACSID = $uptime = $null

        #Load latest ComputerName from CSV into Variable
        $ComputerName = $_.ComputerName

        #pass Computername and Domain parameters to get-EikonVersion
        $Computer,$EikonVer,$EikonFileVer, $DACSID, $uptime = (Get-EikonVersion -ComputerName $ComputerName -Domain $Domain)

        #create object with data passed from get-EikonVersion and pipe to csv file
        [pscustomobject][ordered] @{
            ComputerName =  $Computer
            "Eikon Version" = $EikonVer
            "Eikon.exe Version" = $EikonFileVer
            "DACS ID" = $DACSID
            "uptime (days)" = $uptime
        }  | Export-Csv $OutputFile -Append -NoTypeInformation
    } # End of ForEach-Object Loop
} # End of Function
