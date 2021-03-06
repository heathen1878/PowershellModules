function Read-Article {
    <#
    .Synopsis
    Marks articles as read.

    .Description
    The Read-Article function marks articles as having been read.
    You can submit articles or feeds to Read-Article.
    If you submit a feed, Read-Article marks all articles in the feed as read.

    .Parameter Article
    Marks only the specified articles or feeds as read.
    The default is all articles in all RSS feeds in the system. 

    Enter article objects, such as those returned by Get-Article or feed objects, 
    such as those returned by Get-Feed.
    You can also pipe article or feed objects to Get-Article.

    .Notes
    The Get-Article function is exported by the PSRSS module.
    For more information, see about_PSRSS_Module.

    The Get-Article function uses the Items property of Microsoft.FeedsManager objects.

    .Link
    about_PSRSS_Module

    .Link
    Get-Article

    .Link
    Get-Feed

    .Link
    "Windows RSS Platform" in MSDN
    http://msdn.microsoft.com/en-us/library/ms684701(VS.85).aspx

    .Link
    "Microsoft.FeedsManager Object" in MSDN
    http://msdn.microsoft.com/en-us/library/ms684749(VS.85).aspx

    .Example
    #Marks all articles as read.
    Read-Article

    .Example
    # Marks all articles in the feed as read.
    $feed = Get-Feed "Windows PowerShell Blog"
    Read-Article –Article $feed

    .Example
    Read-Article –Article "*PowerShell*"



    .Example
    # Mark as ready any article that is more than a week old.
    Get-Article | where {$_.modified –lt (get-date).adddays(-7)} | read-article

    #>

    [CmdletBinding(DefaultParameterSetName="Article")]
    param(
        [Parameter(ParameterSetName="Article", ValueFromPipeline=$true)]
        [ValidateScript({
            $_.PSObject.TypeNames[0] -eq "System.__ComObject#{79ac9ef4-f9c1-4d2b-a50b-a7ffba4dcf37}" -or
            $_.PSObject.TypeNames[0] -eq "System.__ComObject#{33f2ea09-1398-4ab9-b6a4-f94b49d0a42e}"
        })]
        [__ComObject]
        $Article
    ) 
    
    
    Process {
        $typeName = $_.PSObject.TypeNames[0]
        switch ($TypeName) {
            "System.__ComObject#{33f2ea09-1398-4ab9-b6a4-f94b49d0a42e}" { 
                # Feed
                $article.Items | ForEach-Object { $_.IsRead = $true } 
            }
            "System.__ComObject#{79ac9ef4-f9c1-4d2b-a50b-a7ffba4dcf37}" {
                # Article
                $article.IsRead = $true
            }
        }        
    }

}