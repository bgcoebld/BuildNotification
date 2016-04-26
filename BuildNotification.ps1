###############################################################################

###########Define Variables########

param
(
    [parameter(mandatory=$true)][string]$MailFrom,
    [parameter(mandatory=$true)][string]$MailTo,
    [parameter(mandatory=$false)][string]$MailCc,
    [parameter(mandatory=$false)][string]$MailBcc,
    [parameter(mandatory=$true)][string]$SmtpServer,
    [parameter(mandatory=$true)][string]$SMTPPort,
    [parameter(mandatory=$true)][string]$BannerHeader,
    [parameter(mandatory=$true)][string]$MailPwd,
    [parameter(mandatory=$true)][string]$PAT
)

function Create-Header
{
    $basicAuth = ("{0}:{1}" -f $VSOUserName,$PAT)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    $headers = @{Authorization=("Basic {0}" -f $basicAuth)}

    return $headers
}

function Get-BuildInfo
{
    $Headers=Create-Header

    $BuildInfo = Invoke-RestMethod -Uri ($TeamFoundationCollectionUri + "/$TeamProjectName" + "/_apis/build/builds/$buildId`?api`-version=2.0") -Method GET -Headers $Headers

	if($BuildInfo.uri -eq $null)
    {
        throw "Received empty response from VSO Api.. Please verify that the PAT Number is correct and its valid."
    }

    return $BuildInfo
}

function Get-BuildTasks
{
    $Headers=Create-Header

    $BuildTimeline = Invoke-RestMethod -Uri ($TeamFoundationCollectionUri + "/$TeamProjectName" + "/_apis/build/builds/$buildId/timeline?api-version=2.0") -Method GET -Headers $Headers | Sort-Object order

    $BuildTasks = $BuildTimeline.records | where {$_.type -eq "Task" -and $_.Name -ne "BuildvNextNotification"} | Sort-Object order

    return $BuildTasks
}

function Parse-BuildDetails
{
    $BuildDetails = Get-BuildInfo

    $MailBodyData=@{}
    $MailBodyData+=@{buildReason=$BuildDetails.reason}
    $MailBodyData+=@{buildResult=$BuildDetails.result}
    $MailBodyData+=@{buildProject=$BuildDetails.project.name}
    $MailBodyData+=@{buildRequestingUser=$BuildDetails.requestedBy.displayName}
    $MailBodyData+=@{buildNumber=$BuildDetails.buildNumber}
    $MailBodyData+=@{teamProjectCollectionUrl=$BuildDetails.project.url}
    $MailBodyData+=@{sourceBranch=$BuildDetails.sourceBranch}
    $MailBodyData+=@{queuename=$BuildDetails.queue.name}
    $MailBodyData+=@{repositorytype=$BuildDetails.repository.type}
    $MailBodyData+=@{teambuildinformation=$BuildDetails.url}
    $MailBodyData+=@{buildefinitionname=$BuildDetails.definition.name}
    $MailBodyData+=@{buildId=$BuildDetails.id}

    $PassedFeatures=@()
    $FailedFeatures=@()
    $SucceededwithIssues=@()

    $BuildTasks = Get-BuildTasks

    foreach($Task in $BuildTasks)
    {
        
        
        if($task.result -ieq "succeeded")
        {
            $PassedFeatures+=@(" o $($task.name)")
            
        }

        if(($task.result -ieq "failed") -or ($task.result -ieq "succeededwithIssues") )
        {
            $FailedFeatures+=@(" o Build Script error while executing : $($task.name).")
            
        }

        if($task.result -ieq "succeededwithIssues")
        {
            $SucceededwithIssues+=@("$($task.name)")
        }
    }

    $MailBodyData+=@{PassedFeatures=$PassedFeatures}
    $MailBodyData+=@{FailedFeatures=$FailedFeatures}
    $MailBodyData+=@{SucceededwithIssues=$SucceededwithIssues}

    return $MailBodyData
}

function Prepare-MailBody
{
    $BuildDetails = Parse-BuildDetails

    $passedFeatures=[string]::Join(" <br> ",$BuildDetails.PassedFeatures)

    if(($BuildDetails.FailedFeatures -ne $null) -or ($BuildDetails.FailedFeatures -ne ""))
    {
        $failedFeatures="<table class=`"statusTable`"><tr><td class=`"failedTd`"><span class=`"statusTextStyle`">Failed</span></td></tr><tr><td class=`"infoTd`"><ul class=`"summaryList`"> <br> $($BuildDetails.FailedFeatures) </ul></td></tr></table>"

        #$failedFeatures=[string]::Join(" <table class=`"statusTable`"><tr><td class=`"failedTd`"><span class=`"statusTextStyle`">Failed</span></td></tr><tr><td class=`"infoTd`"><ul class=`"summaryList`"> <br> ",$BuildDetails.FailedFeatures," </ul></td></tr></table>")
    }
    else
    {
        $failedFeatures=""
    }

    $succeededwithIssues=[string]::Join(" <br> ",$BuildDetails.SucceededwithIssues)
    
    $HtmlName = [guid]::NewGuid()
    
    Get-Content .\BuildNotification.html | Add-Content $env:TEMP\$HtmlName.html
    
    
    if(![string]::IsNullOrEmpty($failedFeatures))
    {
         $BuildResult = "<font color=`"red`">Failed</font>"
    }
    else
    {
        $BuildResult = "<font color=`"green`">Passed</font>"
    }

    if(![string]::IsNullOrEmpty($succeededwithIssues))
    {
        $BuildResult = "<font color=`"orange`">Partially Succeeded</font>"
    }
    

    (get-content "$env:TEMP\$HtmlName.html") | foreach-object {$_ -replace "<@bannerheader>", "$BannerHeader" `
                                                          -replace "<@mailToLinkMailId>", "$MailFrom" `
                                                          -replace "<@buildnumber>", "$($BuildDetails.buildNumber)" `
                                                          -replace "<@projectname>", "$($BuildDetails.buildProject)" `
                                                          -replace "<@buildstatus>", "$BuildResult" `
                                                          -replace "<@requestinguser>", "$($BuildDetails.buildRequestingUser)" `
                                                          -replace "<@tpcname>", "$TeamFoundationCollectionUri" `
                                                          -replace "<@teamprojectname>", "$TeamProjectName" `
                                                          -replace "<@buildqueue>", "$($BuildDetails.queuename)" `
                                                          -replace "<@repositorytype>", "$($BuildDetails.repositorytype)" `
                                                          -replace "<@buildexecutiontype>", "$($BuildDetails.buildReason)" `
                                                          -replace "<@teambuildinformation>", "$TeamFoundationCollectionUri/$TeamProjectName/_build?_a=summary&buildId=$($BuildDetails.buildId)" `
                                                          -replace "<@passedbuildfeatures>", "$($passedFeatures)" `
                                                          -replace "<@failedbuildfeatures>", "$($failedFeatures)" `
                                                          -replace "<@builddefinitionname>", "$($BuildDetails.buildefinitionname)" `
                                                          -replace "<@buildweblink>", "$TeamFoundationCollectionUri/$TeamProjectName/_build?_a=summary&buildId=$($BuildDetails.buildId)" } | set-content "$env:TEMP\$HtmlName.html"

    $HtmlBody = Get-Content "$env:TEMP\$HtmlName.html"

    #-replace "<@buildtype>", "$($BuildDetails.buildReason)" `

    $MailBody = @{HtmlBody=$HtmlBody}
    $MailBody += @{BuildStatus=$BuildDetails.buildResult}
    $MailBody += @{BuildDefinitionName=$BuildDetails.buildefinitionname}
    $MailBody += @{FailedFeatures=$BuildDetails.FailedFeatures}
    $MailBody += @{SucceededwithIssues=$BuildDetails.SucceededwithIssues}
    

    return $MailBody
}

function Send-Mail
{
    $MailBody = Prepare-MailBody

    $MailMessage = new-object System.Net.Mail.MailMessage

    $MailMessage.From = $MailFrom

    foreach($toAddress in $MailTo.Split(','))
    {
        $MailMessage.To.Add($toAddress.Trim())
    }

    if(![string]::IsNullOrEmpty($MailCc))
    {
        foreach($ccAddress in $MailCc.Split(','))
        {
            $MailMessage.CC.Add($ccAddress.Trim())
        }
    }

    if(![string]::IsNullOrEmpty($MailBcc))
    {
        foreach($bccAddress in $MailBcc.Split(','))
        {
            $MailMessage.Bcc.Add($bccAddress)
        }
    }

    $MailMessage.IsBodyHtml = $True

    
    if(![string]::IsNullOrEmpty($MailBody.FailedFeatures))
    {
        $Status = "Failed"
        $MailMessage.Priority=[System.Net.Mail.MailPriority]::High
    }
    else
    {
        $Status = "Passed"
    }

    if(![string]::IsNullOrEmpty($MailBody.SucceededwithIssues))
    {
        $Status = "PartiallySucceeded"
    }
    


    $MailMessage.Subject = "VNext Build Notification : $($MailBody.BuildDefinitionName) Build $($Status)"
    
    $MailMessage.body = $MailBody.HtmlBody

    $smtp = new-object Net.Mail.SmtpClient($SmtpServer, $SMTPPort);

    $smtp.EnableSSL = "true"

    $smtp.Credentials = New-Object System.Net.NetworkCredential($MailFrom, $MailPwd);

    $smtp.Send($MailMessage)

}

Try
{
#Team Build Environment Variables

$TeamFoundationCollectionUri = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI"
$TeamProjectName = "$env:SYSTEM_TEAMPROJECT"
$BuildId = "$env:BUILD_BUILDID"

#Getting Variables from Build Defintion Variables


Write-Output "TFS: $TeamFoundationCollectionUri"
Write-Output "Teamproj: $TeamProjectName"
Write-Output "BuildId: $($BuildId)"
Write-Output "BannerHeader: $($BannerHeader)"
Write-Output "MailTo: $($MailTo)"
Write-Output "MailFrom: $($MailFrom)"
Write-Output "MailCc: $($MailCc)"
Write-Output "MailBcc: $($MailBcc)"
Write-Output "SMTP: $($SmtpServer)"
Write-Output "Port: $($SMTPPort)"

Send-Mail

}
Catch
{
        #[System.Exception]

        if($Error[0].Exception -match "Client was not authenticated to send anonymous mail during MAIL FROM")
        {
          Write-Warning "Failed to send mail, Please verify the Mail From User credentials"
          Write-Error "$($Error[0].Exception.Message)"
          
        }
        elseif($Error[0].Exception -match "Failure sending mail.")
        {
          Write-Warning "Failed to send mail. Please verify the MAIL FROM user credentials and check if the user has permisisons to send mail from smtp server."
          Write-Error "$($Error[0].Exception.Message)"
        }
        else
        {
            Write-Error "$($Error[0].Exception.Message)"
        }
}
Finally
{
        Write-Output "Send Mail Task execution Completed."
}

#################################################################################