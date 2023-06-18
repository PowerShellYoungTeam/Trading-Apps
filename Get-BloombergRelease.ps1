function Get-BloombergRelease{
	<#
	.SYNOPSIS
	Function to check for new releases of Bloomberg Terminal
	by Steven Wight
	.DESCRIPTION
	Get-BloombergRelease <URL> (default https://www.bloomberg.com/professional/support/software-updates/)
	.EXAMPLE
	Get-BloombergRelease
	.Notes
	You can change and even pipe the URL, but unless Bloomberg change the URL, it's pretty pointless to be fair, more of a personal exercise me doing it. NB currently only works with Windows PowerShell
	#>

	[CmdletBinding()]
	Param
	(
		[Parameter(ValueFromPipeline=$true,Position=0)]
		$URL = 'https://www.bloomberg.com/professional/support/software-updates/'	
	)

	Begin {

		$Start = Get-Date
		Write-Verbose "Scraping $($URL) for data at $((Get-Date).ToString('yyyy-MM-dd HH:MM:ss'))"

	}

	Process {

		Write-Verbose "Extracting Data from $($URL)"
		$page = Invoke-WebRequest -Uri $URL

		#got through the page data and find the Table Row with the text we are looking for
		$TRwithData = $page.ParsedHtml.getElementsByTagName('tr') | Where-Object { $_.innerText -like "Bloomberg Terminal - New/Upgrade Installation*"}
		$HTMLwithData = $TRwithData.outerHTML

		#use regex to grab the month text, lets set the strings we need
		$firstString = '<td class="date">'
		$secondString = '</td>'

		#Regex pattern to compare two strings
		$pattern = "$firstString(.*?)$secondString"

		#Perform the match operation to grab the moth string
		$ReleaseMonth = [regex]::Match($HTMLwithData,$pattern).Groups[1].Value

		if ($null -eq $ReleaseMonth){

			Write-Verbose "Can't find the Download in $($URL)"
			break

		}else{

			Write-Verbose "Found $($ReleaseMonth) Month in $($URL)"

		}
	}

 End {

	$End = Get-Date

	Write-Verbose "Script finished at $((Get-Date).ToString('yyyy-MM-dd HH:MM:ss'))"
	Write-Verbose "This script took $((New-TimeSpan -Start $Start -End $End).TotalSeconds) seconds to complete"

	Return $ReleaseMonth
	}
}
