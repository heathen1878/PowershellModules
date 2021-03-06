
###################################################################
#    Copyright (c) Microsoft. All rights reserved.
#    This code is licensed under the Microsoft Public License.
#    THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
#    ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
#    IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
#    PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
###################################################################

##################################################
# Test-StartRunbook
##################################################

begin {
    # import modules
    Import-Module .\OrchestratorServiceModule.psm1
}

process {
    # get credentials (set to $null to UseDefaultCredentials)
    $creds = $null
    #$creds = Get-Credential "DOMAIN\USERNAME"

    # create the base url to the service
    $url = Get-OrchestratorServiceUrl -server "SERVERNAME"

    # Use Runbook Id and any params
    #$rbid = [guid]"RunbookGUID"
    #$param1guid = "ParamGUID"
    #$param2guid = "ParamGUID"
    #$runbook = Get-OrchestratorRunbook -serviceurl $url -runbookid $rbid -credentials $creds

    # Use Runbook Path and parameter names
    $rbpath = "\Folder1\Folder2\Runbook Name"
    $param1name = "Parameter1"
    $param2name = "Parameter2"
    $param1guid = ""
    $param2guid = ""
    $runbook = Get-OrchestratorRunbook -serviceurl $url -runbookpath $rbpath -credentials $creds
    foreach ($param in $runbook.Parameters)
    {
        if ($param.Name -eq $param1name)
        {
            $param1guid = $param.Id   
        }
        elseif ($param.Name -eq $param2name)
        {
            $param2guid = $param.Id   
        }
    }
        
    if ($runbook -ne $null) {
        # Start runbook (no params)
        #$job = Start-OrchestratorRunbook -runbook $runbook -credentials $creds
        
        # Start runbook with params
        [hashtable] $params = @{
            $param1guid = "Hello";
            $param2guid = "World"
        }
        $job = Start-OrchestratorRunbook -runbook $runbook -parameters $params -credentials $creds
        
        if ($job -ne $null)
        {
            Write-Host "JobId = " $job.id
        }
        else
        {
            Write-Host "No job started"
        }
    }

}

end {
    # remove modules
    Remove-Module OrchestratorServiceModule
}
