#######################################################################################################################
# File:             Add-on.ScriptEditorEssentials.psm1                                                                #
# Author:           Kirk Munro                                                                                        #
# Publisher:        Quest Software, Inc.                                                                              #
# Copyright:        © 2011 Quest Software, Inc. All rights reserved.                                                  #
# Usage:            To load this module in your Script Editor:                                                        #
#                   1. Open the Script Editor.                                                                        #
#                   2. Select "PowerShell Libraries" from the File menu.                                              #
#                   3. Check the Add-on.ScriptEditorEssentials module.                                                #
#                   4. Click on OK to close the "PowerShell Libraries" dialog.                                        #
#                   Alternatively you can load the module from the embedded console by invoking this:                 #
#                       Import-Module -Name Add-on.ScriptEditorEssentials                                             #
#                   Please provide feedback on the PowerGUI Forums.                                                   #
#######################################################################################################################

Set-StrictMode -Version 2

#region Define the Win32WindowClass

if (-not ('PowerShellTypeExtensions.Win32Window' -as [System.Type])) {
	$cSharpCode = @'
using System;

namespace PowerShellTypeExtensions {
	public class Win32Window : System.Windows.Forms.IWin32Window
	{
		public static Win32Window CurrentWindow {
			get {
				return new Win32Window(System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle);
			}
		}
	
		public Win32Window(IntPtr handle) {
			_hwnd = handle;
		}

		public IntPtr Handle {
			get {
				return _hwnd;
			}
		}

		private IntPtr _hwnd;
	}
}
'@

	Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition $cSharpCode
}

#endregion

#region Define the Win32SystemParametersInfo class

if (-not ('PowerShellTypeExtensions.Win32SystemParametersInfo' -as [System.Type])) {
	$cSharpCode = @'
using System;
using System.Runtime.InteropServices;

namespace PowerShellTypeExtensions {
	public class Win32SystemParametersInfo
	{
		private const uint SPI_GETWHEELSCROLLLINES = 104;

		public const uint WheelDelta = 120;

		[DllImport("User32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		private static extern bool SystemParametersInfo(
			uint uiAction,
			uint uiParam,
			ref uint pvParam,
			uint fWinIni
		);

		public static uint GetWheelScrollLines()
		{
			uint uiScrollLines = 3;
			SystemParametersInfo(SPI_GETWHEELSCROLLLINES, 0, ref uiScrollLines, 0);
			return uiScrollLines;
		}
	}
}
'@

	Add-Type -TypeDefinition $cSharpCode
}

#endregion

#region Initialize the Script Editor Add-on.

$minimumSdkVersion = [System.Version]'1.0'

if ($Host.Name –ne 'PowerGUIScriptEditorHost') {
	return
}

if (-not (Get-Variable -Name PGVersionTable -ErrorAction SilentlyContinue)) {
	[System.Windows.Forms.MessageBox]::Show([PowerShellTypeExtensions.Win32Window]::CurrentWindow,"The ""$(Split-Path -Path $PSScriptRoot -Leaf)"" Add-on module requires PowerGUI 3.0 or later. The current PowerGUI version is $($Host.Version).$([System.Environment]::NewLine * 2)Please upgrade to the latest version of PowerGUI and try again.",'PowerGUI 3.0 or later is required',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
	return
} elseif ($PGVersionTable.SDKVersion -lt $minimumSdkVersion) {
	[System.Windows.Forms.MessageBox]::Show([PowerShellTypeExtensions.Win32Window]::CurrentWindow,"The ""$(Split-Path -Path $PSScriptRoot -Leaf)"" Add-on module requires version $minimumSdkVersion or later of the PowerGUI Script Editor SDK. The current SDK version is $($PGVersionTable.SDKVersion).$([System.Environment]::NewLine * 2)Please upgrade to the latest version of PowerGUI and try again.","Version $minimumSdkVersion or later of the SDK is required",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
	return
}

#endregion

#region If a file was opened with the Script Editor and the Start Page is being displayed, activate that file.

if ((($PGSE.Configuration.Names -notcontains '/ScriptEditor/ShowStartPage') -or ($PGSE.Configuration.Item('/ScriptEditor/ShowStartPage')) -and
    (-not (Get-Variable -Name PGStarted -Scope Global -ErrorAction SilentlyContinue)))) {
	$global:PGStarted = $true
	if (($commandLineArguments = [System.Environment]::GetCommandLineArgs() | Select-Object -Skip 1) -and
	    ($activeFile = $commandLineArguments | Where-Object {$_ -ne '-MTA'} | Select-Object -Last 1)) {
		foreach ($documentWindow in $PGSE.DocumentWindows) {
			if (($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
			    ($documentWindow.Document.Path -eq $activeFile)) {
				$documentWindow.Activate()
				break
			}
		}
	}
}

#endregion

#region Load resources from disk.

$iconLibrary = @{
	      WordWrapIcon16 = New-Object -TypeName System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\WordWrap.ico",16,16
	ViewWhitespaceIcon16 = New-Object -TypeName System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\ViewWhiteSpace.ico",16,16
	  ClearConsoleIcon16 = New-Object -TypeName System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\ClearPowerShellConsole.ico",16,16
	  ClearConsoleIcon32 = New-Object -TypeName System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\ClearPowerShellConsole.ico",32,32
	IncreaseIndentIcon16 = New-Object -TypeName System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\IncreaseIndent.ico",16,16
	DecreaseIndentIcon16 = New-Object -TypeName System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\DecreaseIndent.ico",16,16
}

$imageLibrary = @{
	      WordWrapImage16 = $iconLibrary['WordWrapIcon16'].ToBitmap()
	ViewWhitespaceImage16 = $iconLibrary['ViewWhitespaceIcon16'].ToBitmap()
	  ClearConsoleImage16 = $iconLibrary['ClearConsoleIcon16'].ToBitmap()
	  ClearConsoleImage32 = $iconLibrary['ClearConsoleIcon32'].ToBitmap()
	IncreaseIndentImage16 = $iconLibrary['IncreaseIndentIcon16'].ToBitmap()
	DecreaseIndentImage16 = $iconLibrary['DecreaseIndentIcon16'].ToBitmap()
}

#endregion

#region Initialize the Add-on configuration.

$configuration = @{
	Default = @{
		                      Encoding = [System.Text.Encoding]::Unicode
		                  WordWrapType = 'Character'
		       RememberSearchMatchCase = $false
		  RememberSearchMatchWholeWord = $false
		              RememberSearchUp = $false
		RememberSearchExpandedTextOnly = $false
		    EnableSmartSelectionSearch = $true
	}
	Current = @{
		                      WordWrap = $false
		                ViewWhitespace = $false
		             VirtualWhitespace = $false
		                 FavoritePaths = [String[]]@()
	                 TabStripScrolling = $true
	}
}
$configPath = "${PSScriptRoot}\Add-on.ScriptEditorEssentials.config.xml"
if (Test-Path -LiteralPath $configPath) {
	$configuration = Import-Clixml -Path $configPath
	if (-not $configuration.Default.ContainsKey('Encoding')) {
		$configuration.Default.Encoding = [System.Text.Encoding]::Unicode
	} else {
		$configuration.Default.Encoding = [System.Text.Encoding]::GetEncoding($configuration.Default.Encoding.WebName)
	}
	if (-not $configuration.Default.ContainsKey('RememberSearchMatchCase')) {
		$configuration.Default.RememberSearchMatchCase = $false
	}
	if (-not $configuration.Default.ContainsKey('RememberSearchMatchWholeWord')) {
		$configuration.Default.RememberSearchMatchWholeWord = $false
	}
	if (-not $configuration.Default.ContainsKey('RememberSearchUp')) {
		$configuration.Default.RememberSearchUp = $false
	}
	if (-not $configuration.Default.ContainsKey('RememberSearchExpandedTextOnly')) {
		$configuration.Default.RememberSearchExpandedTextOnly = $false
	}
	if (-not $configuration.Default.ContainsKey('EnableSmartSelectionSearch')) {
		$configuration.Default.EnableSmartSelectionSearch = $true
	}
	if (-not $configuration.Current.ContainsKey('FavoritePaths')) {
		$configuration.Current.FavoritePaths = [String[]]@()
	}
	if (-not $configuration.Current.ContainsKey('TabStripScrolling')) {
		$configuration.Current.TabStripScrolling = $true
	}
}

#endregion

#region Define helper variables.

$encodingMenuItemMap = @{
	                  [System.Text.Encoding]::ASCII.EncodingName = '&ASCII'
	                   [System.Text.Encoding]::UTF8.EncodingName = 'U&TF-8'
	                [System.Text.Encoding]::Unicode.EncodingName = '&Unicode'
	       [System.Text.Encoding]::BigEndianUnicode.EncodingName = 'Unicode (&Big Endian)'
	                  [System.Text.Encoding]::UTF32.EncodingName = 'Unicode (UT&F-32)'
	[System.Text.Encoding]::GetEncoding('UTF-32BE').EncodingName = 'Unicode (UTF-32 Big &Endian)'
}

$setEncodingScriptBlock = {
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=$true)]
		[ValidateNotNull()]
		[System.Text.Encoding]
		$Encoding,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Clean
	)
	if (($currentDocumentWindow = $PGSE.CurrentDocumentWindow) -and
	    ($currentDocumentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
	    ($originalWindowProperty = $currentDocumentWindow.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
	    ($originalWindow = $originalWindowProperty.GetValue($currentDocumentWindow,$null)) -and
	    ($scriptEditorControl = $originalWindow.PSControl) -and
	    ($originalWindow.Encoding -ne $Encoding)) {
		$originalWindow.Encoding = $Encoding
		if (((-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Clean')) -or (-not $Clean)) -and
		    $currentDocumentWindow.Document.Path) {
			$scriptEditorControl.Document.Modified = $true
		}
		Update-FileEncodingInternal -DocumentWindow $currentDocumentWindow
	}
}

#endregion

#region Define functions.

Export-ModuleMember

#region View Whitespace functions.

function Test-ScriptEditorViewWhitespace {
	[CmdletBinding()]
	param()
	$configuration.Current.ViewWhitespace
}
Export-ModuleMember -Function Test-ScriptEditorViewWhitespace

function Enable-ScriptEditorViewWhitespaceInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	foreach ($item in $DocumentWindow) {
		if ($item -and
		    ($item | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$scriptEditorControl.WhitespaceTabsVisible = $true
			$scriptEditorControl.WhitespaceSpacesVisible = $true
		}
	}
	if (($viewWhitespaceCommand = $PGSE.Commands['EditCommand.ViewWhitespace']) -and ($viewWhitespaceCommand.Checkable)) {
		$viewWhitespaceCommand.Checked = $true
	}
	$configuration.Current.ViewWhitespace = $true
}

function Enable-ScriptEditorViewWhitespace {
	[CmdletBinding()]
	param()
	Enable-ScriptEditorViewWhitespaceInternal
	$configuration.Current.ViewWhitespace = $true
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Enable-ScriptEditorViewWhitespace

function Disable-ScriptEditorViewWhitespaceInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	foreach ($item in $DocumentWindow) {
		if ($item -and
		    ($item | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$scriptEditorControl.WhitespaceTabsVisible = $false
			$scriptEditorControl.WhitespaceSpacesVisible = $false
		}
	}
	if (($viewWhitespaceCommand = $PGSE.Commands['EditCommand.ViewWhitespace']) -and ($viewWhitespaceCommand.Checkable)) {
		$viewWhitespaceCommand.Checked = $false
	}
	$configuration.Current.ViewWhitespace = $false
}

function Disable-ScriptEditorViewWhitespace {
	[CmdletBinding()]
	param()
	Disable-ScriptEditorViewWhitespaceInternal
	$configuration.Current.ViewWhitespace = $false
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Disable-ScriptEditorViewWhitespace

function Update-ScriptEditorViewWhitespaceInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	if ($configuration.Current.ViewWhitespace) {
		Enable-ScriptEditorViewWhitespaceInternal -DocumentWindow $DocumentWindow
	} else {
		Disable-ScriptEditorViewWhitespaceInternal -DocumentWindow $DocumentWindow
	}
}

#endregion

#region Word Wrap functions.

function Get-ScriptEditorWordWrapType {
	[CmdletBinding()]
	param()
	$configuration.Default.WordWrapType
}
Export-ModuleMember -Function Get-ScriptEditorWordWrapType

function Set-ScriptEditorWordWrapType {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[Alias('Type')]
		[ValidateSet('Character','Token','Word')]
		[System.String]
		$WordWrapType
	)
	$configuration.Default.WordWrapType = $WordWrapType
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Set-ScriptEditorWordWrapType

function Get-ScriptEditorWordWrap {
	[CmdletBinding()]
	param()
	$configuration.Current.WordWrap
}
Export-ModuleMember -Function Get-ScriptEditorWordWrap

function Enable-ScriptEditorWordWrapInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	Disable-ScriptEditorVirtualWhitespaceInternal -DocumentWindow $DocumentWindow
	foreach ($item in $DocumentWindow) {
		if ($item -and
		    ($item | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$scriptEditorControl.WordWrapping = $true
			$scriptEditorControl.WordWrap = $configuration.Default.WordWrapType
			$scriptEditorControl.WordWrapGlyphVisible = $true
		}
	}
	if (($wordWrapCommand = $PGSE.Commands['EditCommand.WordWrap']) -and ($wordWrapCommand.Checkable)) {
		$wordWrapCommand.Checked = $true
	}
	$configuration.Current.WordWrap = $true
}

function Enable-ScriptEditorWordWrap {
	[CmdletBinding()]
	param()
	Enable-ScriptEditorWordWrapInternal
	$configuration.Current.WordWrap = $true
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Enable-ScriptEditorWordWrap

function Disable-ScriptEditorWordWrapInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	foreach ($item in $DocumentWindow) {
		if ($item -and
		    ($item | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$scriptEditorControl.WordWrapping = $false
			$scriptEditorControl.WordWrap = 'None'
			$scriptEditorControl.WordWrapGlyphVisible = $false
		}
	}
	if (($wordWrapCommand = $PGSE.Commands['EditCommand.WordWrap']) -and ($wordWrapCommand.Checkable)) {
		$wordWrapCommand.Checked = $false
	}
	$configuration.Current.WordWrap = $false
}

function Disable-ScriptEditorWordWrap {
	[CmdletBinding()]
	param()
	Disable-ScriptEditorWordWrapInternal
	$configuration.Current.WordWrap = $false
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Disable-ScriptEditorWordWrap

function Update-ScriptEditorWordWrapInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	if ($configuration.Current.WordWrap) {
		Enable-ScriptEditorWordWrapInternal -DocumentWindow $DocumentWindow
	} else {
		Disable-ScriptEditorWordWrapInternal -DocumentWindow $DocumentWindow
	}
}

#endregion

#region Virtual Whitespace functions.

function Test-ScriptEditorVirtualWhitespace {
	[CmdletBinding()]
	param()
	$configuration.Current.VirtualWhitespace
}
Export-ModuleMember -Function Test-ScriptEditorVirtualWhitespace

function Enable-ScriptEditorVirtualWhitespaceInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	Disable-ScriptEditorWordWrapInternal -DocumentWindow $DocumentWindow
	foreach ($item in $DocumentWindow) {
		if ($item -and
		    ($item | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$scriptEditorControl.VirtualSpaceAtLineEndEnabled = $true
		}
	}
	if (($virtualWhitespaceCommand = $PGSE.Commands['EditCommand.VirtualWhitespace']) -and ($virtualWhitespaceCommand.Checkable)) {
		$virtualWhitespaceCommand.Checked = $true
	}
	$configuration.Current.VirtualWhitespace = $true
}

function Enable-ScriptEditorVirtualWhitespace {
	[CmdletBinding()]
	param()
	Enable-ScriptEditorVirtualWhitespaceInternal
	$configuration.Current.VirtualWhitespace = $true
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Enable-ScriptEditorVirtualWhitespace

function Disable-ScriptEditorVirtualWhitespaceInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	foreach ($item in $DocumentWindow) {
		if ($item -and
		    ($item | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$scriptEditorControl.VirtualSpaceAtLineEndEnabled = $false
		}
	}
	if (($virtualWhitespaceCommand = $PGSE.Commands['EditCommand.VirtualWhitespace']) -and ($virtualWhitespaceCommand.Checkable)) {
		$virtualWhitespaceCommand.Checked = $false
	}
	$configuration.Current.VirtualWhitespace = $false
}

function Disable-ScriptEditorVirtualWhitespace {
	[CmdletBinding()]
	param()
	Disable-ScriptEditorVirtualWhitespaceInternal
	$configuration.Current.VirtualWhitespace = $false
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Disable-ScriptEditorVirtualWhitespace

function Update-ScriptEditorVirtualWhitespaceInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[Quest.PowerGUI.SDK.DocumentWindow[]]$DocumentWindow = $PGSE.DocumentWindows
	)
	if ($configuration.Current.VirtualWhitespace) {
		Enable-ScriptEditorVirtualWhitespaceInternal -DocumentWindow $DocumentWindow
	} else {
		Disable-ScriptEditorVirtualWhitespaceInternal -DocumentWindow $DocumentWindow
	}
}

#endregion

#region FavoritePath functions.

function Get-ScriptEditorFavoritePath {
	[CmdletBinding()]
	param()
	$configuration.Current.FavoritePaths
}
Export-ModuleMember -Function Get-ScriptEditorFavoritePath

function Add-ScriptEditorFavoritePath {
	[CmdletBinding(DefaultParameterSetName='Path')]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='Path')]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Path,

		[Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='LiteralPath')]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$LiteralPath
	)
	process {
		switch ($PSCmdlet.ParameterSetName) {
			'Path' {
				$configuration.Current.FavoritePaths += @(Get-Item -Path $Path -ErrorAction SilentlyContinue | Where-Object {$_.PSIsContainer -and ($configuration.Current.FavoritePaths -notcontains $_)} | Select-Object -ExpandProperty FullName)
				break
			}
			'LiteralPath' {
				$configuration.Current.FavoritePaths += @(Get-Item -LiteralPath $LiteralPath -ErrorAction SilentlyContinue | Where-Object {$_.PSIsContainer -and ($configuration.Current.FavoritePaths -notcontains $_)} | Select-Object -ExpandProperty FullName)
				break
			}
		}
		$configuration.Current.FavoritePaths = [String[]]@($configuration.Current.FavoritePaths | Sort-Object)
		$configuration | Export-Clixml -Path $configPath
	}
}
Export-ModuleMember -Function Add-ScriptEditorFavoritePath

function Remove-ScriptEditorFavoritePath {
	[CmdletBinding(DefaultParameterSetName='Path')]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='Path')]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Path,

		[Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='LiteralPath')]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$LiteralPath
	)
	process {
		switch ($PSCmdlet.ParameterSetName) {
			'Path' {
				foreach ($item in $Path -replace '^Microsoft\.PowerShell\.Core\\FileSystem::') {
					$configuration.Current.FavoritePaths = [String[]]@($configuration.Current.FavoritePaths -notlike $item)
				}
				break
			}
			'LiteralPath' {
				foreach ($item in $LiteralPath -replace '^Microsoft\.PowerShell\.Core\\FileSystem::') {
					$configuration.Current.FavoritePaths = [String[]]@($configuration.Current.FavoritePaths -ne $item)
				}
				break
			}
		}
		$configuration | Export-Clixml -Path $configPath
	}
}
Export-ModuleMember -Function Remove-ScriptEditorFavoritePath

function Clear-ScriptEditorFavoritePath {
	[CmdletBinding()]
	param()
	Get-ScriptEditorFavoritePath | Remove-ScriptEditorFavoritePath
}
Export-ModuleMember -Function Clear-ScriptEditorFavoritePath

#endregion

#region Search functions.
<#
function Get-ScriptEditorSearchConfiguration {
	[CmdletBinding()]
	param()
	$searchConfiguration = New-Object -TypeName System.Management.Automation.PSObject
	Add-Member -InputObject $searchConfiguration -MemberType NoteProperty -Name MatchCase -Value $configuration.Current.SearchMatchCase
	Add-Member -InputObject $searchConfiguration -MemberType NoteProperty -Name MatchWholeWord -Value $configuration.Current.SearchMatchWholeWord
	Add-Member -InputObject $searchConfiguration -MemberType NoteProperty -Name SearchUp -Value $configuration.Current.SearchUp
	Add-Member -InputObject $searchConfiguration -MemberType NoteProperty -Name SearchInSelection -Value $configuration.Current.SearchInSelection
	Add-Member -InputObject $searchConfiguration -MemberType NoteProperty -Name SearchHiddenText -Value $configuration.Current.SearchHiddenText
	$searchConfiguration
}
Export-ModuleMember -Function Get-ScriptEditorSearchConfiguration

function Set-ScriptEditorSearchConfiguration {
	[CmdletBinding()]
	param(
		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$RememberMatchCase,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$RememberMatchWholeWord,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$RememberSearchUp,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$RememberSearchExpandedTextOnly,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$EnableSmartSelectionSearch,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$PassThru
	)
	$changed = $false
	if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('RememberMatchCase')) {
		$configuration.Default.RememberSearchMatchCase = $RememberMatchCase
		$changed = $true
	}
	if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('RememberMatchWholeWord')) {
		$configuration.Default.RememberSearchMatchWholeWord = $RememberMatchWholeWord
		$changed = $true
	}
	if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('RememberSearchUp')) {
		$configuration.Default.RememberSearchUp = $RememberSearchUp
		$changed = $true
	}
	if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('RememberSearchExpandedTextOnly')) {
		$configuration.Default.RememberSearchExpandedTextOnly = $RememberSearchExpandedTextOnly
		$changed = $true
	}
	if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('EnableSmartSelectionSearch')) {
		$configuration.Default.EnableSmartSelectionSearch = $EnableSmartSelectionSearch
		$changed = $true
	}
	if ($changed) {
		$configuration | Export-Clixml -Path $configPath
	}
	if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru) {
		$configuration
	}
}
Export-ModuleMember -Function Set-ScriptEditorSearchConfiguration
#>
#endregion

#region FileEncoding functions.

# Thanks to my friend and fellow PowerShell MVP Arnaud Petitjean from http://www.powershell-scripting.com for the core logic used in the Get-FileEncoding function.
function Get-FileEncoding {
	[CmdletBinding(DefaultParameterSetName='Items')]
    param (
		[Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='Items')]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Path,

		[Parameter(Position=0,Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='LiteralItems')]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$LiteralPath
	)
	begin {
		#region Define the constant byte order marks.
		Set-Variable -Name UTF8    -Value 'EFBBBF'   -Option Constant
		Set-Variable -Name UTF16LE -Value 'FFFE'     -Option Constant
		Set-Variable -Name UTF16BE -Value 'FEFF'     -Option Constant
		Set-Variable -Name UTF32LE -Value 'FFFE0000' -Option Constant
		Set-Variable -Name UTF32BE -Value '0000FEFF' -Option Constant
		#endregion
	}
	process {
		switch ($PSCmdlet.ParameterSetName) {
			'Items' {
				foreach ($item in Get-Item -Path $Path) {
					Get-FileEncoding -LiteralPath $item.FullName
				}
				break
			}
			'LiteralItems' {
				$fourBytes = Get-Content -LiteralPath $LiteralPath -Encoding Byte -TotalCount 4
				$bom = ''
				foreach ($byte in $fourBytes) {
					$bom += '{0:x2}' -f $byte
				}
				switch -regex ($bom) {
					"^$UTF32LE" {[System.Text.Encoding]::UTF32;                   break}
					"^$UTF32BE" {[System.Text.Encoding]::GetEncoding('UTF-32BE'); break}
					"^$UTF8"    {[System.Text.Encoding]::UTF8;                    break}
					"^$UTF16LE" {[System.Text.Encoding]::Unicode;                 break}
					"^$UTF16BE" {[System.Text.Encoding]::BigEndianUnicode;        break}
					default     {[System.Text.Encoding]::ASCII;                   break}
				}
				break
			}
		}
	}
}
Export-ModuleMember -Function Get-FileEncoding

function Set-FileEncoding {
	[CmdletBinding(DefaultParameterSetName='Items')]
    param (
		[Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='Items')]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Path,

		[Parameter(Position=0,Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='LiteralItems')]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$LiteralPath,

		[Parameter(Position=1,Mandatory=$true)]
		[ValidateNotNull()]
		[System.Text.Encoding]
		$Encoding,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$PassThru
	)
	process {
		switch ($PSCmdlet.ParameterSetName) {
			'Items' {
				foreach ($item in Get-Item -Path $Path) {
					Set-FileEncoding -LiteralPath $item.FullName -Encoding $Encoding -PassThru:$($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru)
				}
				break
			}
			'LiteralItems' {
				foreach ($item in $LiteralPath) {
					$modifiedInEditor = $false
					$fileEncoding = $null
					if ($host.Name -eq 'PowerGUIScriptEditorHost') {
						foreach ($documentWindow in $PGSE.DocumentWindows) {
							if ($documentWindow -and
							    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
							    ($documentWindow.Document.Path -eq $item) -and
							    ($originalWindowProperty = $documentWindow.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
							    ($originalWindow = $originalWindowProperty.GetValue($documentWindow,$null)) -and
							    ($scriptEditorControl = $originalWindow.PSControl) -and
							    ($originalWindow.Encoding -ne $Encoding)) {
								$originalWindow.Encoding = $Encoding
								$scriptEditorControl.Document.Modified = $true
								$modifiedInEditor = $true
								if ($documentWindow -ne $PGSE.CurrentDocumentWindow) {
									$documentWindow.Activate()
								}
								Update-FileEncodingInternal -DocumentWindow $documentWindow
								break
							}
						}
					}
					if ((-not $modifiedInEditor) -and
					    ($fileEncoding = Get-FileEncoding -LiteralPath $item)) {
						$fileContents = [System.IO.File]::ReadAllText($item, $fileEncoding)
						[System.Byte[]]$bytes = New-Object -TypeName System.Byte[] -ArgumentList ($Encoding.GetByteCount($fileContents))
						$Encoding.GetBytes($fileContents, 0, $fileContents.Length, $bytes, 0) | Out-Null
						$bytes = $Encoding.GetPreamble() + $bytes
						[System.IO.File]::WriteAllBytes($item, $bytes)
					}
					if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru) {
						$item
					}
				}
				break
			}
		}
	}
}
Export-ModuleMember -Function Set-FileEncoding

function Get-ScriptEditorFileEncoding {
	[CmdletBinding()]
	param()
	$configuration.Default.Encoding
}
Export-ModuleMember -Function Get-ScriptEditorFileEncoding

function Set-ScriptEditorFileEncoding {
	[CmdletBinding()]
    param (
		[Parameter(Position=0,Mandatory=$true)]
		[ValidateNotNull()]
		[System.Text.Encoding]
		$Encoding
	)
	if ($configuration.Default.Encoding -ne $Encoding) {
		$configuration.Default.Encoding = $Encoding
		$configuration | Export-Clixml -Path $configPath
	}
}
Export-ModuleMember -Function Set-ScriptEditorFileEncoding

function Update-FileEncodingInternal {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$false)]
		[Quest.PowerGUI.SDK.DocumentWindow]$DocumentWindow = $PGSE.CurrentDocumentWindow
	)
	$fileEncoding = $null
	if ($DocumentWindow -and
	    ($DocumentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
	    ($originalWindowProperty = $DocumentWindow.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
	    ($originalWindow = $originalWindowProperty.GetValue($DocumentWindow,$null)) -and
		($scriptEditorControl = $originalWindow.PSControl)) {
		if ($scriptEditorControl.Document.Modified) {
			$fileEncoding = $originalWindow.Encoding
		} elseif (-not $DocumentWindow.Document.Path) {
			$originalWindow.Encoding = $configuration.Default.Encoding
			$fileEncoding = $originalWindow.Encoding
		} elseif ($originalWindow.Encoding -ne $configuration.Default.Encoding) {
			$originalWindow.Encoding = Get-FileEncoding -LiteralPath $DocumentWindow.Document.Path
			$fileEncoding = $originalWindow.Encoding
		}
	}
	foreach ($commandName in @('FileCommand.ASCII','FileCommand.UTF8','FileCommand.Unicode','FileCommand.UnicodeBigEndian','FileCommand.UTF32','FileCommand.UTF32BigEndian')) {
		if ($encodingCommand = $PGSE.Commands[$commandName]) {
			$encodingCommand.Enabled = ($fileEncoding -ne $null)
			$encodingCommand.Checked = (($fileEncoding -ne $null) -and ($encodingMenuItemMap[$fileEncoding.EncodingName] -eq $encodingCommand.Text))
		}
	}
	if (($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) -and
	    ($encodingStatusLabel = $statusBar.Items['Encoding'])) {
		if ($fileEncoding) {
			$encodingStatusLabel.Text = $fileEncoding.EncodingName
			$encodingStatusLabel.Visible = $true
		} else {
			$encodingStatusLabel.Text = ''
			$encodingStatusLabel.Visible = $false
		}
	}
}

#endregion

#region TabStrip functions.

function Enable-ScriptEditorTabStripScrollingInternal {
	[CmdletBinding()]
	param()
	if (($documentWindow = $PGSE.DocumentWindows | Select-Object -First 1) -and
	    ($originalWindowProperty = $documentWindow.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
	    ($originalWindow = $originalWindowProperty.GetValue($documentWindow,$null)) -and
	    ($tabStripControl = $originalWindow.Parent.TabStrip)) {
		$tabStripControl.TabOverflowStyle = 'ScrollButtons'
	}
}

function Enable-ScriptEditorTabStripScrolling {
	[CmdletBinding()]
	param()
	Enable-ScriptEditorTabStripScrollingInternal
	$configuration.Current.TabStripScrolling = $true
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Enable-ScriptEditorTabStripScrolling

function Disable-ScriptEditorTabStripScrollingInternal {
	[CmdletBinding()]
	param()
	if (($documentWindow = $PGSE.DocumentWindows | Select-Object -First 1) -and
	    ($originalWindowProperty = $documentWindow.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
	    ($originalWindow = $originalWindowProperty.GetValue($documentWindow,$null)) -and
	    ($tabStripControl = $originalWindow.Parent.TabStrip)) {
		$tabStripControl.TabOverflowStyle = 'None'
	}
}

function Disable-ScriptEditorTabStripScrolling {
	[CmdletBinding()]
	param()
	Disable-ScriptEditorTabStripScrollingInternal
	$configuration.Current.TabStripScrolling = $false
	$configuration | Export-Clixml -Path $configPath
}
Export-ModuleMember -Function Disable-ScriptEditorTabStripScrolling

function Update-ScriptEditorTabStripScrollingInternal {
	[CmdletBinding()]
	param()
	if ($configuration.Current.TabStripScrolling) {
		Enable-ScriptEditorTabStripScrollingInternal
	} else {
		Disable-ScriptEditorTabStripScrollingInternal
	}
}

#endregion

#region File functions.

function Open-File {
	[CmdletBinding(DefaultParameterSetName='Path')]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='Path')]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Path,

		[Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='LiteralPath')]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$LiteralPath,

		[Parameter(Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Filter,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Recurse,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Force
	)
	begin {
		$currentDocuments = @()
		foreach ($documentWindow in $PGSE.DocumentWindows) {
			if ($documentWindow -and
			    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
			    ($documentWindow.Document.Path) -and
			    ($currentDocuments -notcontains $documentWindow.Document.Path)) {
				$currentDocuments += $documentWindow.Document.Path
			}
		}
	}
	process {
		$getChildItemParameters = @{}
		foreach ($parameterName in @('Path','LiteralPath','Recurse','Force')) {
			if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
				$getChildItemParameters[$parameterName] = Invoke-Expression "`$$parameterName"
			}
		}
		foreach ($item in Get-ChildItem @getChildItemParameters) {
			if ($item -isnot [System.IO.FileInfo]) {
				continue
			}
			if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
				$passedFilter = $false
				foreach ($wildcardPattern in $Filter) {
					if ($item.Name -like $wildcardPattern) {
						$passedFilter = $true
						break
					}
				}
				if (-not $passedFilter) {
					continue
				}
			}
			if ($currentDocuments -contains $item.FullName) {
				foreach ($documentWindow in $PGSE.DocumentWindows) {
					if ($documentWindow -and
					    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
					    ($documentWindow.Document.Path -eq $item.FullName)) {
						$documentWindow.Activate()
						break
					}
				}
			} else {
		   		$PGSE.DocumentWindows.Add($item.FullName) | Out-Null
				& $setEncodingScriptBlock -Encoding (Get-FileEncoding -LiteralPath $item.FullName) -Clean
				$currentDocuments += $item.FullName
			}
		}
	}
}
Export-ModuleMember -Function Open-File

New-Alias -Name opfi -Value Open-File -ErrorAction SilentlyContinue
if ($?) {
	Export-ModuleMember -Alias opfi
}

function Close-File {
	[CmdletBinding(DefaultParameterSetName='Path')]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='Path')]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Path,

		[Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='LiteralPath')]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$LiteralPath,

		[Parameter(Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Filter,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Recurse,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Force
	)
	begin {
		$currentDocuments = @()
		foreach ($documentWindow in $PGSE.DocumentWindows) {
			if ($documentWindow -and
			    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
			    ($documentWindow.Document.Path) -and
			    ($currentDocuments -notcontains $documentWindow.Document.Path)) {
				$currentDocuments += $documentWindow.Document.Path
			}
		}
	}
	process {
		$getChildItemParameters = @{}
		foreach ($parameterName in @('Path','LiteralPath','Recurse','Force')) {
			if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
				$getChildItemParameters[$parameterName] = Invoke-Expression "`$$parameterName"
			}
		}
		foreach ($item in Get-ChildItem @getChildItemParameters) {
			if ($item -isnot [System.IO.FileInfo]) {
				continue
			}
			if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
				$passedFilter = $false
				foreach ($wildcardPattern in $Filter) {
					if ($item.Name -like $wildcardPattern) {
						$passedFilter = $true
						break
					}
				}
				if (-not $passedFilter) {
					continue
				}
			}
			if ($currentDocuments -contains $item.FullName) {
				foreach ($documentWindow in $PGSE.DocumentWindows) {
					if ($documentWindow -and
					    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
					    ($documentWindow.Document.Path -eq $item.FullName)) {
						$documentWindow.Close()
						break
					}
				}
			}
		}
	}
}
Export-ModuleMember -Function Close-File

New-Alias -Name csfi -Value Close-File -ErrorAction SilentlyContinue
if ($?) {
	Export-ModuleMember -Alias csfi
}

#endregion

#region Script functions.

function Open-Script {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$Path
	)
	begin {
		$currentDocuments = @()
		foreach ($documentWindow in $PGSE.DocumentWindows) {
			if ($documentWindow -and
			    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
			    ($documentWindow.Document.Path) -and
			    ($currentDocuments -notcontains $documentWindow.Document.Path)) {
				$currentDocuments += $documentWindow.Document.Path
			}
		}
	}
	process {
		foreach ($item in $Path) {
			foreach ($command in Get-Command -CommandType ExternalScript -Name $item) {
				if ($currentDocuments -contains $command.Path) {
					foreach ($documentWindow in $PGSE.DocumentWindows) {
						if ($documentWindow -and
						    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
						    ($documentWindow.Document.Path -eq $command.Path)) {
							$documentWindow.Activate()
							break
						}
					}
				} else {
			   		$PGSE.DocumentWindows.Add($command.Path) | Out-Null
					& $setEncodingScriptBlock -Encoding (Get-FileEncoding -LiteralPath $command.Path) -Clean
					$currentDocuments += $command.Path
				}
			}
		}
	}
}
Export-ModuleMember -Function Open-Script

New-Alias -Name opps -Value Open-Script -ErrorAction SilentlyContinue
if ($?) {
	Export-ModuleMember -Alias opps
}

function Close-Script {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[ValidateNotNullOrEmpty()]
		[Alias('PSPath')]
		[System.String[]]
		$Path
	)
	begin {
		$currentDocuments = @()
		foreach ($documentWindow in $PGSE.DocumentWindows) {
			if ($documentWindow -and
			    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
			    ($documentWindow.Document.Path) -and
			    ($currentDocuments -notcontains $documentWindow.Document.Path)) {
				$currentDocuments += $documentWindow.Document.Path
			}
		}
	}
	process {
		foreach ($item in $Path) {
			foreach ($command in Get-Command -CommandType ExternalScript -Name $item) {
				if ($currentDocuments -contains $command.Path) {
					foreach ($documentWindow in $PGSE.DocumentWindows) {
						if ($documentWindow -and
						    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
						    ($documentWindow.Document.Path -eq $command.Path)) {
							$documentWindow.Close()
							break
						}
					}
				}
			}
		}
	}
}
Export-ModuleMember -Function Close-Script

New-Alias -Name csps -Value Close-Script -ErrorAction SilentlyContinue
if ($?) {
	Export-ModuleMember -Alias csps
}

#endregion

#region Module functions.

function Open-Module {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Name,

		[Parameter(Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Filter,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Recurse,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Force,

		[Parameter()]
		[Alias('Nested')]
		[System.Management.Automation.SwitchParameter]
		$IncludeNested
	)
	begin {
		$currentDocuments = @()
		foreach ($documentWindow in $PGSE.DocumentWindows) {
			if ($documentWindow -and
			    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
			    ($documentWindow.Document.Path) -and
			    ($currentDocuments -notcontains $documentWindow.Document.Path)) {
				$currentDocuments += $documentWindow.Document.Path
			}
		}
		$allModules = Get-Module -ListAvailable
		if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
			$filterSet = $Filter
		} else {
			$filterSet = @('*.psm1','*.psd1')
		}
	}
	process {
		foreach ($module in Get-Module -ListAvailable -Name $Name) {
			$nestedModulePaths = @()
			foreach ($otherModule in $allModules) {
				if (($otherModule.ModuleBase -ne $module.ModuleBase) -and
				    ($otherModule.ModuleBase.StartsWith($module.ModuleBase))) {
					if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Recurse') -and $Recurse) {
						$nestedModulePaths += $otherModule.ModuleBase
					} elseif ($module.ModuleBase -eq ($otherModule.ModuleBase | Split-Path -Parent)) {
						$nestedModulePaths += $otherModule.ModuleBase
					}
				}
			}
			$getChildItemParameters = @{
				LiteralPath = $module.ModuleBase
			}
			foreach ($parameterName in @('Recurse','Force')) {
				if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
					$getChildItemParameters[$parameterName] = Invoke-Expression "`$$parameterName"
				}
			}
			foreach ($item in Get-ChildItem @getChildItemParameters) {
				if ($item.PSIsContainer) {
					continue
				}
				$passedFilter = $false
				foreach ($wildcardPattern in $filterSet) {
					if ($item.Name -like $wildcardPattern) {
						$passedFilter = $true
						break
					}
				}
				if (-not $passedFilter) {
					continue
				}
				$nestedItem = $false
				if ($nestedModulePaths) {
					foreach ($nestedModulePath in $nestedModulePaths) {
						if ($item.FullName.StartsWith($nestedModulePath)) {
							$nestedItem = $true
							break
						}
					}
					if ($nestedItem -and
					    ((-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('IncludeNested')) -or (-not $IncludeNested))) {
						continue
					}
				}
				if ($currentDocuments -contains $item.FullName) {
					foreach ($documentWindow in $PGSE.DocumentWindows) {
						if ($documentWindow -and
						    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
						    ($documentWindow.Document.Path -eq $item.FullName)) {
							$documentWindow.Activate()
							break
						}
					}
				} else {
			   		$PGSE.DocumentWindows.Add($item.FullName) | Out-Null
					& $setEncodingScriptBlock -Encoding (Get-FileEncoding -LiteralPath $item.FullName) -Clean
					$currentDocuments += $item.FullName
				}
			}
		}
	}
}
Export-ModuleMember -Function Open-Module

New-Alias -Name opmo -Value Open-Module -ErrorAction SilentlyContinue
if ($?) {
	Export-ModuleMember -Alias opmo
}

function Close-Module {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Name,

		[Parameter(Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Filter,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Recurse,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Force,

		[Parameter()]
		[Alias('Nested')]
		[System.Management.Automation.SwitchParameter]
		$IncludeNested
	)
	begin {
		$currentDocuments = @()
		foreach ($documentWindow in $PGSE.DocumentWindows) {
			if ($documentWindow -and
			    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
			    ($documentWindow.Document.Path) -and
			    ($currentDocuments -notcontains $documentWindow.Document.Path)) {
				$currentDocuments += $documentWindow.Document.Path
			}
		}
		$allModules = Get-Module -ListAvailable
		if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Filter')) {
			$filterSet = $Filter
		} else {
			$filterSet = @('*.psm1','*.psd1')
		}
	}
	process {
		foreach ($module in Get-Module -ListAvailable -Name $Name) {
			$nestedModulePaths = @()
			foreach ($otherModule in $allModules) {
				if (($otherModule.ModuleBase -ne $module.ModuleBase) -and
				    ($otherModule.ModuleBase.StartsWith($module.ModuleBase))) {
					if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Recurse') -and $Recurse) {
						$nestedModulePaths += $otherModule.ModuleBase
					} elseif ($module.ModuleBase -eq ($otherModule.ModuleBase | Split-Path -Parent)) {
						$nestedModulePaths += $otherModule.ModuleBase
					}
				}
			}
			$getChildItemParameters = @{
				LiteralPath = $module.ModuleBase
			}
			foreach ($parameterName in @('Recurse','Force')) {
				if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
					$getChildItemParameters[$parameterName] = Invoke-Expression "`$$parameterName"
				}
			}
			foreach ($item in Get-ChildItem @getChildItemParameters) {
				if ($item.PSIsContainer) {
					continue
				}
				$passedFilter = $false
				foreach ($wildcardPattern in $filterSet) {
					if ($item.Name -like $wildcardPattern) {
						$passedFilter = $true
						break
					}
				}
				if (-not $passedFilter) {
					continue
				}
				$nestedItem = $false
				if ($nestedModulePaths) {
					foreach ($nestedModulePath in $nestedModulePaths) {
						if ($item.FullName.StartsWith($nestedModulePath)) {
							$nestedItem = $true
							break
						}
					}
					if ($nestedItem -and
					    ((-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('IncludeNested')) -or (-not $IncludeNested))) {
						continue
					}
				}
				if ($currentDocuments -contains $item.FullName) {
					foreach ($documentWindow in $PGSE.DocumentWindows) {
						if ($documentWindow -and
						    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
						    ($documentWindow.Document.Path -eq $item.FullName)) {
							$documentWindow.Close()
							break
						}
					}
				}
			}
		}
	}
}
Export-ModuleMember -Function Close-Module

New-Alias -Name csmo -Value Close-Module -ErrorAction SilentlyContinue
if ($?) {
	Export-ModuleMember -Alias csmo
}

#endregion

#region PSOpen/PSClose functions.

function PSOpen {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.PSObject]
		$InputObject,

		[Parameter(Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Filter,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Recurse,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Force,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[Alias('Nested')]
		[System.Management.Automation.SwitchParameter]
		$IncludeNested
	)
	process {
		$passThruParameters = $PSCmdlet.MyInvocation.BoundParameters
		if ($passThruParameters.ContainsKey('InputObject')) {
			$passThruParameters.Remove('InputObject') | Out-Null
		}
		foreach ($item in $InputObject) {
			if ($item -is [System.Management.Automation.PSModuleInfo]) {
				$item | Open-Module @passThruParameters
			} elseif ($item -is [System.IO.FileInfo]) {
				if ($passThruParameters.ContainsKey('IncludeNested')) {
					$passThruParameters.Remove('IncludeNested') | Out-Null
				}
				$item | Open-File @passThruParameters
			} elseif ($item -is [System.Management.Automation.ExternalScriptInfo]) {
				Open-Script -Name $item.Path
			} elseif ($item -is [System.String]) {
				if (Get-Module -Name $item -ListAvailable -ErrorAction SilentlyContinue) {
					$item | Open-Module @passThruParameters
				} elseif (Test-Path $item) {
					if ($passThruParameters.ContainsKey('IncludeNested')) {
						$passThruParameters.Remove('IncludeNested') | Out-Null
					}
					$item | Open-File @passThruParameters
				} else {
					Open-Script -Name $item
				}
			} else {
				Write-Warning "Unsupported type received: '$($item.GetType().FullName)'"
			}
		}
	}
}
Export-ModuleMember -Function PSOpen

New-Alias -Name PSEdit -Value PSOpen -ErrorAction SilentlyContinue
if ($?) {
	Export-ModuleMember -Alias PSEdit
}

function PSClose {
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.PSObject]
		$InputObject,

		[Parameter(Position=1)]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$Filter,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Recurse,

		[Parameter()]
		[System.Management.Automation.SwitchParameter]
		$Force,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[Alias('Nested')]
		[System.Management.Automation.SwitchParameter]
		$IncludeNested
	)
	process {
		$passThruParameters = $PSCmdlet.MyInvocation.BoundParameters
		if ($passThruParameters.ContainsKey('InputObject')) {
			$passThruParameters.Remove('InputObject') | Out-Null
		}
		foreach ($item in $InputObject) {
			if ($item -is [System.Management.Automation.PSModuleInfo]) {
				$item | Close-Module @passThruParameters
			} elseif ($item -is [System.IO.FileInfo]) {
				if ($passThruParameters.ContainsKey('IncludeNested')) {
					$passThruParameters.Remove('IncludeNested') | Out-Null
				}
				$item | Close-File @passThruParameters
			} elseif ($item -is [System.Management.Automation.ExternalScriptInfo]) {
				Close-Script -Name $item.Path
			} elseif ($item -is [System.String]) {
				if (Get-Module -Name $item -ListAvailable -ErrorAction SilentlyContinue) {
					$item | Close-Module @passThruParameters
				} elseif (Test-Path $item) {
					if ($passThruParameters.ContainsKey('IncludeNested')) {
						$passThruParameters.Remove('IncludeNested') | Out-Null
					}
					$item | Close-File @passThruParameters
				} else {
					Close-Script -Name $item
				}
			} else {
				Write-Warning "Unsupported type received: '$($item.GetType().FullName)'"
			}
		}
	}
}
Export-ModuleMember -Function PSClose

#endregion

#endregion

#region Define event handlers.

[System.EventHandler]$onTabChanged = {
	& {
		$currentDocumentWindow = $PGSE.CurrentDocumentWindow
		if ($commandsEnabled = ($currentDocumentWindow -ne $null)) {
			Update-ScriptEditorWordWrapInternal -DocumentWindow $currentDocumentWindow
			Update-ScriptEditorViewWhitespaceInternal -DocumentWindow $currentDocumentWindow
			Update-ScriptEditorVirtualWhitespaceInternal -DocumentWindow $currentDocumentWindow
		}
		foreach ($commandName in @('EditCommand.ViewWhitespace','EditCommand.WordWrap','EditCommand.VirtualWhitespace')) {
			if ($command = $PGSE.Commands[$commandName]) {
				$command.Enabled = $commandsEnabled
			}
		}
		Update-FileEncodingInternal -DocumentWindow $currentDocumentWindow
		Update-ScriptEditorTabStripScrollingInternal
	}
}

[System.EventHandler[Quest.PowerGUI.SDK.CommandEventArgs]]$onOpening = {
	param(
		$sender,
		$eventArgs
	)
	& {
		$eventArgs.Canceled = $true
		$openFileDialog = New-Object -TypeName System.Windows.Forms.OpenFileDialog
		$openFileDialog.AddExtension = $true
		$openFileDialog.CheckFileExists = $true
		$openFileDialog.CheckPathExists = $true
		$openFileDialog.Multiselect = $true
		$openFileDialog.Filter = 'PowerShell Files (*.ps1;*.psm1;*.psd1;*.ps1xml;*.psc1;*.snippet)|*.ps1;*.psm1;*.psd1;*.ps1xml;*.psc1;*.snippet|PowerShell Scripts (*.ps1)|*.ps1|PowerShell Script Modules (*.psm1)|*.psm1|PowerShell Data Files (*.psd1)|*.psd1|PowerShell Configuration Files (*.ps1xml)|*.ps1xml|PowerShell Console Files (*.psc1)|*.psc1|Snippet Files (*.snippet)|*.snippet|Text Files (*.txt;*.csv)|*.txt;*.csv|XML Files (*.xml)|*.xml|All Files (*.*)|*.*'
		$openFileDialog.RestoreDirectory = $true
		if ($openFileDialog | Get-Member -Name CustomPlaces -MemberType Property -ErrorAction SilentlyContinue) {
			$foldersToAdd = New-Object -TypeName System.Collections.Stack
			if (($windowsPowerShellFolder = Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell') | Test-Path) {
				$foldersToAdd.Push($windowsPowerShellFolder)
				if (($modulesFolder = Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Modules') | Test-Path) {
					$foldersToAdd.Push($modulesFolder)
				}
				if (($snippetsFolder = Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath 'WindowsPowerShell\Snippets') | Test-Path) {
					$foldersToAdd.Push($snippetsFolder)
				}
			}
			foreach ($item in $configuration.Current.FavoritePaths) {
				if ($item | Test-Path) {
					$foldersToAdd.Push($item)
				}
			}
			while ($foldersToAdd.Count -gt 0) {
				$openFileDialog.CustomPlaces.Add([string]$foldersToAdd.Pop())
			}
		}
		if ($openFileDialog.ShowDialog([PowerShellTypeExtensions.Win32Window]::CurrentWindow) -eq [System.Windows.Forms.DialogResult]::OK) {
			foreach ($item in $openFileDialog.FileNames) {
				$openFile = $true
				foreach ($documentWindow in $PGSE.DocumentWindows) {
					if ($documentWindow -and
					    ($documentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
					    ($documentWindow.Document.Path -eq $item)) {
						$documentWindow.Activate()
						$openFile = $false
						break
					}
				}
				if ($openFile) {
					try {
						$PGSE.DocumentWindows.Add($item) | Out-Null
						& $setEncodingScriptBlock -Encoding (Get-FileEncoding -LiteralPath $item) -Clean
					} catch {
					}
				}
			}
		}
	}
}

[System.EventHandler]$onOpened = {
	& {
		Update-FileEncodingInternal
	}
}

[System.EventHandler[Quest.PowerGUI.SDK.CommandEventArgs]]$onSearching = {
	param(
		$sender,
		$eventArgs
	)
	& {
		$eventArgs.Canceled = $false
		if (($currentDocumentWindow = $PGSE.CurrentDocumentWindow) -and
		    ($currentDocumentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $currentDocumentWindow.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($currentDocumentWindow,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$currentDocumentWindow.Activate()
			if (($findReplaceOptionsField = $scriptEditorControl.GetType().GetField('s_fro',[System.Reflection.BindingFlags]'NonPublic,Static')) -and
			    ($findReplaceOptions = $findReplaceOptionsField.GetValue($null))) {
				if (-not $configuration.Default.RememberSearchMatchCase) {
					$findReplaceOptions.MatchCase = $false
				}
				if (-not $configuration.Default.RememberSearchMatchWholeWord) {
					$findReplaceOptions.MatchWholeWord = $false
				}
				if (-not $configuration.Default.RememberSearchUp) {
					$findReplaceOptions.SearchUp = $false
				}
				if (-not $configuration.Default.RememberSearchExpandedTextOnly) {
					$findReplaceOptions.SearchHiddenText = $true
				}
				if ($configuration.Default.EnableSmartSelectionSearch) {
					if (-not $currentDocumentWindow.Document.SelectedText) {
						$findReplaceOptions.SearchInSelection = $false
					} else {
						if ($currentDocumentWindow.Document.SelectedText -replace '^\s+|\s+$' -match "`n") {
							$findReplaceOptions.FindText = ''
							$findReplaceOptions.SearchInSelection = $true
						} else {
							$findReplaceOptions.FindText = $currentDocumentWindow.Document.SelectedText -replace "^\s*[`r`n]+|[`r`n]+\s*$"
							$findReplaceOptions.SearchInSelection = $false
						}
					}
					if (-not (Get-Variable -Name findReplaceForm -Scope Script)) {
						$script:findReplaceForm = New-Object -TypeName ActiproSoftware.SyntaxEditor.FindReplaceForm -ArgumentList $scriptEditorControl,$findReplaceOptions
						$script:findReplaceForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
					}
					$script:findReplaceForm.Owner = $scriptEditorControl.TopLevelControl
					if ($script:findReplaceForm.Visible) {
						$script:findReplaceForm.Activate()
					} else {
						$script:findReplaceForm.Show() | Out-Null
					}
					$eventArgs.Canceled = $true
				}
			}
		}
	}
}

[System.EventHandler[Quest.PowerGUI.SDK.CommandEventArgs]]$onGoingTo = {
	param(
		$sender,
		$eventArgs
	)
	& {
		$eventArgs.Canceled = $false
		if (($currentDocumentWindow = $PGSE.CurrentDocumentWindow) -and
		    ($currentDocumentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($originalWindowProperty = $currentDocumentWindow.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
		    ($originalWindow = $originalWindowProperty.GetValue($currentDocumentWindow,$null)) -and
		    ($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
		    ($scriptEditorControl = $originalWindow.PSControl)) {
			$currentDocumentWindow.Activate()
		}
	}
}

[System.EventHandler]$onNew = {
	& $setEncodingScriptBlock -Encoding $configuration.Default.Encoding -Clean
}

[System.EventHandler[Quest.PowerGUI.SDK.CommandEventArgs]]$onExecutingSelection = {
	param(
		$sender,
		$eventArgs
	)
	& {
		$eventArgs.Canceled = $true
		if (($currentDocumentWindow = $PGSE.CurrentDocumentWindow) -and
		    ($currentDocumentWindow | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
		    ($selectedText = $currentDocumentWindow.Document.SelectedText -replace '^\s+|\s+$')) {
			$PGSE.Execute($selectedText)
		}
	}
}

#endregion

#region Create the Encoding submenu.

if (($fileMenu = $PGSE.Menus['MenuBar.File']) -and
    (-not ($encodingSubmenu = $fileMenu.Items['FileCommand.Encoding']))) {
	$encodingSubmenuCommand = New-Object -TypeName Quest.PowerGUI.SDK.MenuCommand -ArgumentList 'FileCommand','Encoding'
	$encodingSubmenuCommand.Text = 'Encodin&g'
	$PGSE.Commands.Add($encodingSubmenuCommand)
	$index = -1
	if ($saveAllMenuItem = $fileMenu.Items['FileCommand.SaveAll']) {
		$index = $fileMenu.Items.IndexOf($saveAllMenuItem)
	}
	if (($index -ge 0) -and ($index -lt ($fileMenu.Items.Count - 1))) {
		$fileMenu.Items.Insert($index + 1,$encodingSubmenuCommand)
	} else {
		$fileMenu.Items.Add($encodingSubmenuCommand)
	}
	$encodingSubmenu = $fileMenu.Items['FileCommand.Encoding']
	$encodingSubmenu.FirstInGroup = $true
}

#endregion

#region Create the ASCII menu item in the File menu.

if (-not ($asciiMenuItem = $encodingSubmenu.Items['FileCommand.ASCII'])) {
	if (-not ($asciiCommand = $PGSE.Commands['FileCommand.ASCII'])) {
		$asciiCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'FileCommand','ASCII'
		$asciiCommand.Text = $script:encodingMenuItemMap[[System.Text.Encoding]::ASCII.EncodingName]
		$asciiCommand.Enabled = $false
		$asciiCommand.Checkable = $true
		$asciiCommand.Checked = $false
		$asciiCommand.ScriptBlock = {
			& $setEncodingScriptBlock -Encoding ([System.Text.Encoding]::ASCII)
		}
		$PGSE.Commands.Add($asciiCommand)
	}
	$encodingSubmenu.Items.Add($asciiCommand)
	$asciiMenuItem = $encodingSubmenu.Items['FileCommand.ASCII']
	$asciiMenuItem.FirstInGroup = $false
}

#endregion

#region Create the UTF8 menu item in the File menu.

if (-not ($utf8MenuItem = $encodingSubmenu.Items['FileCommand.UTF8'])) {
	if (-not ($utf8Command = $PGSE.Commands['FileCommand.UTF8'])) {
		$utf8Command = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'FileCommand','UTF8'
		$utf8Command.Text = $script:encodingMenuItemMap[[System.Text.Encoding]::UTF8.EncodingName]
		$utf8Command.Enabled = $false
		$utf8Command.Checkable = $true
		$utf8Command.Checked = $false
		$utf8Command.ScriptBlock = {
			& $setEncodingScriptBlock -Encoding ([System.Text.Encoding]::UTF8)
		}
		$PGSE.Commands.Add($utf8Command)
	}
	$encodingSubmenu.Items.Add($utf8Command)
	$utf8MenuItem = $encodingSubmenu.Items['FileCommand.UTF8']
	$utf8MenuItem.FirstInGroup = $false
}

#endregion

#region Create the Unicode menu item in the File menu.

if (-not ($unicodeMenuItem = $encodingSubmenu.Items['FileCommand.Unicode'])) {
	if (-not ($unicodeCommand = $PGSE.Commands['FileCommand.Unicode'])) {
		$unicodeCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'FileCommand','Unicode'
		$unicodeCommand.Text = $script:encodingMenuItemMap[[System.Text.Encoding]::Unicode.EncodingName]
		$unicodeCommand.Enabled = $false
		$unicodeCommand.Checkable = $true
		$unicodeCommand.Checked = $true
		$unicodeCommand.ScriptBlock = {
			& $setEncodingScriptBlock -Encoding ([System.Text.Encoding]::Unicode)
		}
		$PGSE.Commands.Add($unicodeCommand)
	}
	$encodingSubmenu.Items.Add($unicodeCommand)
	$unicodeMenuItem = $encodingSubmenu.Items['FileCommand.Unicode']
	$unicodeMenuItem.FirstInGroup = $false
}

#endregion

#region Create the UnicodeBigEndian menu item in the File menu.

if (-not ($unicodeBigEndianMenuItem = $encodingSubmenu.Items['FileCommand.UnicodeBigEndian'])) {
	if (-not ($unicodeBigEndianCommand = $PGSE.Commands['FileCommand.UnicodeBigEndian'])) {
		$unicodeBigEndianCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'FileCommand','UnicodeBigEndian'
		$unicodeBigEndianCommand.Text = $script:encodingMenuItemMap[[System.Text.Encoding]::BigEndianUnicode.EncodingName]
		$unicodeBigEndianCommand.Enabled = $false
		$unicodeBigEndianCommand.Checkable = $true
		$unicodeBigEndianCommand.Checked = $false
		$unicodeBigEndianCommand.ScriptBlock = {
			& $setEncodingScriptBlock -Encoding ([System.Text.Encoding]::BigEndianUnicode)
		}
		$PGSE.Commands.Add($unicodeBigEndianCommand)
	}
	$encodingSubmenu.Items.Add($unicodeBigEndianCommand)
	$unicodeBigEndianMenuItem = $encodingSubmenu.Items['FileCommand.UnicodeBigEndian']
	$unicodeBigEndianMenuItem.FirstInGroup = $false
}

#endregion

#region Create the UTF32 menu item in the File menu.

if (-not ($utf32MenuItem = $encodingSubmenu.Items['FileCommand.UTF32'])) {
	if (-not ($utf32Command = $PGSE.Commands['FileCommand.UTF32'])) {
		$utf32Command = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'FileCommand','UTF32'
		$utf32Command.Text = $script:encodingMenuItemMap[[System.Text.Encoding]::UTF32.EncodingName]
		$utf32Command.Enabled = $false
		$utf32Command.Checkable = $true
		$utf32Command.Checked = $false
		$utf32Command.ScriptBlock = {
			& $setEncodingScriptBlock -Encoding ([System.Text.Encoding]::UTF32)
		}
		$PGSE.Commands.Add($utf32Command)
	}
	$encodingSubmenu.Items.Add($utf32Command)
	$utf32MenuItem = $encodingSubmenu.Items['FileCommand.UTF32']
	$utf32MenuItem.FirstInGroup = $false
}

#endregion

#region Create the UTF32BigEndian menu item in the File menu.

if (-not ($utf32BigEndianMenuItem = $encodingSubmenu.Items['FileCommand.UTF32BigEndian'])) {
	if (-not ($utf32BigEndianCommand = $PGSE.Commands['FileCommand.UTF32BigEndian'])) {
		$utf32BigEndianCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'FileCommand','UTF32BigEndian'
		$utf32BigEndianCommand.Text = $script:encodingMenuItemMap[[System.Text.Encoding]::GetEncoding('UTF-32BE').EncodingName]
		$utf32BigEndianCommand.Enabled = $false
		$utf32BigEndianCommand.Checkable = $true
		$utf32BigEndianCommand.Checked = $false
		$utf32BigEndianCommand.ScriptBlock = {
			& $setEncodingScriptBlock -Encoding ([System.Text.Encoding]::GetEncoding('UTF-32BE'))
		}
		$PGSE.Commands.Add($utf32BigEndianCommand)
	}
	$encodingSubmenu.Items.Add($utf32BigEndianCommand)
	$utf32BigEndianMenuItem = $encodingSubmenu.Items['FileCommand.UTF32BigEndian']
	$utf32BigEndianMenuItem.FirstInGroup = $false
}

#endregion

#region Create the ViewWhiteSpace menu item in the Edit|Advanced menu.

if (($editMenu = $PGSE.Menus['MenuBar.Edit']) -and
    ($advancedEditMenu = $editMenu.Items['EditCommand.Advanced']) -and
    (-not ($viewWhitespaceMenuItem = $advancedEditMenu.Items['EditCommand.ViewWhitespace']))) {
	if (-not ($viewWhitespaceCommand = $PGSE.Commands['EditCommand.ViewWhitespace'])) {
		$viewWhitespaceCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'EditCommand','ViewWhitespace'
		$viewWhitespaceCommand.Text = 'View &White Space'
		$viewWhitespaceCommand.Image = $imageLibrary['ViewWhitespaceImage16']
		$viewWhitespaceCommand.AddShortcut('Control+Shift+W')
		$viewWhitespaceCommand.Checkable = $true
		$viewWhitespaceCommand.Checked = $configuration.Current.ViewWhitespace
		$viewWhitespaceCommand.Enabled = [bool]($PGSE.CurrentDocumentWindow -ne $null)
		$viewWhitespaceCommand.ScriptBlock = {
			if (-not $configuration.Current.ViewWhitespace) {
				Enable-ScriptEditorViewWhitespace
			} else {
				Disable-ScriptEditorViewWhitespace
			}
		}
		$PGSE.Commands.Add($viewWhitespaceCommand)
	}
	$advancedEditMenu.Items.Add($viewWhitespaceCommand)
	if ($viewWhitespaceMenuItem = $advancedEditMenu.Items['EditCommand.ViewWhitespace']) {
		$viewWhitespaceMenuItem.FirstInGroup = $true
	}
}

#endregion

#region Create the WordWrap menu item in the Edit|Advanced menu.

if (($editMenu = $PGSE.Menus['MenuBar.Edit']) -and
    ($advancedEditMenu = $editMenu.Items['EditCommand.Advanced']) -and
    (-not ($wordWrapMenuItem = $advancedEditMenu.Items['EditCommand.WordWrap']))) {
	if (-not ($wordWrapCommand = $PGSE.Commands['EditCommand.WordWrap'])) {
		$wordWrapCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'EditCommand','WordWrap'
		$wordWrapCommand.Text = 'Word W&rap'
		$wordWrapCommand.Image = $imageLibrary['WordWrapImage16']
		$wordWrapCommand.AddShortcut('Control+Alt+W')
		$wordWrapCommand.Checkable = $true
		$wordWrapCommand.Checked = $configuration.Current.WordWrap
		$wordWrapCommand.Enabled = [bool]($PGSE.CurrentDocumentWindow -ne $null)
		$wordWrapCommand.ScriptBlock = {
			if (-not $configuration.Current.WordWrap) {
				Enable-ScriptEditorWordWrap
			} else {
				Disable-ScriptEditorWordWrap
			}
		}
		$PGSE.Commands.Add($wordWrapCommand)
	}
	$advancedEditMenu.Items.Add($wordWrapCommand)
	if ($wordWrapMenuItem = $advancedEditMenu.Items['EditCommand.WordWrap']) {
		$wordWrapMenuItem.FirstInGroup = $true
	}
}

#endregion

#region Create the VirtualWhiteSpace menu item in the Edit|Advanced menu.

if (($editMenu = $PGSE.Menus['MenuBar.Edit']) -and
    ($advancedEditMenu = $editMenu.Items['EditCommand.Advanced']) -and
    (-not ($virtualWhitespaceMenuItem = $advancedEditMenu.Items['EditCommand.VirtualWhitespace']))) {
	if (-not ($virtualWhitespaceCommand = $PGSE.Commands['EditCommand.VirtualWhitespace'])) {
		$virtualWhitespaceCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'EditCommand','VirtualWhitespace'
		$virtualWhitespaceCommand.Text = '&Virtual White Space'
		$virtualWhitespaceCommand.Checkable = $true
		$virtualWhitespaceCommand.Checked = $configuration.Current.VirtualWhitespace
		$virtualWhitespaceCommand.Enabled = [bool]($PGSE.CurrentDocumentWindow -ne $null)
		$virtualWhitespaceCommand.ScriptBlock = {
			if (-not $configuration.Current.VirtualWhitespace) {
				Enable-ScriptEditorVirtualWhitespace
			} else {
				Disable-ScriptEditorVirtualWhitespace
			}
		}
		$PGSE.Commands.Add($virtualWhitespaceCommand)
	}
	$advancedEditMenu.Items.Add($virtualWhitespaceCommand)
}

#endregion

#region Create the TabScrollButtons menu item in the View menu.

if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
    (-not ($tabScrollButtonsMenuItem = $viewMenu.Items['ViewCommand.TabScrollButtons']))) {
	if (-not ($tabScrollButtonsCommand = $PGSE.Commands['ViewCommand.TabScrollButtons'])) {
		$tabScrollButtonsCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'ViewCommand','TabScrollButtons'
		$tabScrollButtonsCommand.Text = 'Tab Scroll Buttons'
		$tabScrollButtonsCommand.Checkable = $true
		$tabScrollButtonsCommand.Checked = $configuration.Current.TabStripScrolling
		$tabScrollButtonsCommand.ScriptBlock = {
			if ($configuration.Current.TabStripScrolling) {
				Disable-ScriptEditorTabStripScrolling
			} else {
				Enable-ScriptEditorTabStripScrolling
			}
		}
		$PGSE.Commands.Add($TabScrollButtonsCommand)
	}
	$index = -1
	if ($lineNumbersMenuItem = $viewMenu.Items['ViewCommand.LineNumbers']) {
		$index = $viewMenu.Items.IndexOf($lineNumbersMenuItem)
	}
	if (($index -ge 0) -and ($index -lt ($viewMenu.Items.Count - 1))) {
		$viewMenu.Items.Insert($index + 1,$tabScrollButtonsCommand)
	} else {
		$viewMenu.Items.Add($tabScrollButtonsCommand)
	}
	$tabScrollButtonsMenuItem = $viewMenu.Items['ViewCommand.TabScrollButtons']
	$tabScrollButtonsMenuItem.FirstInGroup = $false
}

#endregion

#region Create the ZoomIn menu item in the View menu.

if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
    (-not ($zoomInMenuItem = $viewMenu.Items['ViewCommand.ZoomIn']))) {
	if (-not ($zoomInCommand = $PGSE.Commands['ViewCommand.ZoomIn'])) {
		$zoomInCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'ViewCommand','ZoomIn'
		$zoomInCommand.Text = '&Zoom In'
		$zoomInCommand.AddShortcut('Control+Add')
		$zoomInCommand.AddShortcut('Control+Oemplus')
		$zoomInCommand.ScriptBlock = {
			if ($embeddedConsoleWindow = $PGSE.ToolWindows['PowerShellConsole']) {
				$currentEmbeddedConsoleFont = $embeddedConsoleWindow.Control.Font
			}
			foreach ($item in $PGSE.DocumentWindows) {
				if (($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
					($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
					($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
					($scriptEditorControl = $originalWindow.PSControl) -and
					($currentFont = $scriptEditorControl.Font) -and
					($currentFont.Size -lt 32)) {
					$currentFont = $scriptEditorControl.Font
					$scriptEditorControl.Font = New-Object -TypeName System.Drawing.Font -ArgumentList $currentFont.Name,($currentFont.SizeInPoints + 1),$currentFont.Style
				}
			}
			if (($currentEmbeddedConsoleFont) -and
			    ($currentEmbeddedConsoleFont.Size -lt 32) -and
			    ($richTextBox = $embeddedConsoleWindow.Control.Controls.Find('RichTextBox1',$true) | Select-Object -First 1)) {
				$richTextBox.Font = New-Object -TypeName System.Drawing.Font -ArgumentList $currentEmbeddedConsoleFont.Name,($currentEmbeddedConsoleFont.SizeInPoints + 1),$currentEmbeddedConsoleFont.Style
				$embeddedConsoleWindow.Control.Font = New-Object -TypeName System.Drawing.Font -ArgumentList $currentEmbeddedConsoleFont.Name,($currentEmbeddedConsoleFont.SizeInPoints + 1),$currentEmbeddedConsoleFont.Style
				$richTextBox.MoveCursorToEnd()
			}
		}
		$PGSE.Commands.Add($zoomInCommand)
	}
	$index = -1
	if ($fontMenuItem = $viewMenu.Items['ViewCommand.Font']) {
		$index = $viewMenu.Items.IndexOf($fontMenuItem)
	}
	if ($index -ge 0) {
		$viewMenu.Items.Insert($index + 1,$zoomInCommand)
	} else {
		$viewMenu.Items.Add($zoomInCommand)
	}
	if ($zoomInMenuItem = $viewMenu.Items['ViewCommand.ZoomIn']) {
		$zoomInMenuItem.FirstInGroup = $true
	}
}

#endregion

#region Create the ZoomOut menu item in the View menu.

if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
    (-not ($zoomOutMenuItem = $viewMenu.Items['ViewCommand.ZoomOut']))) {
	if (-not ($zoomOutCommand = $PGSE.Commands['ViewCommand.ZoomOut'])) {
		$zoomOutCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'ViewCommand','ZoomOut'
		$zoomOutCommand.Text = 'Zoom O&ut'
		$zoomOutCommand.AddShortcut('Control+Subtract')
		$zoomOutCommand.AddShortcut('Control+OemMinus')
		$zoomOutCommand.ScriptBlock = {
			if ($embeddedConsoleWindow = $PGSE.ToolWindows['PowerShellConsole']) {
				$currentEmbeddedConsoleFont = $embeddedConsoleWindow.Control.Font
			}
			foreach ($item in $PGSE.DocumentWindows) {
				if ($item -and
				    ($item | Get-Member -Name Document -ErrorAction SilentlyContinue) -and
				    ($originalWindowProperty = $item.GetType().GetProperty('OriginalWindow',[System.Reflection.BindingFlags]'NonPublic,Instance')) -and
					($originalWindow = $originalWindowProperty.GetValue($item,$null)) -and
					($originalWindow | Get-Member -MemberType Property -Name PSControl -ErrorAction SilentlyContinue) -and
					($scriptEditorControl = $originalWindow.PSControl) -and
					($currentFont = $scriptEditorControl.Font) -and
					($currentFont.Size -gt 5)) {
					$currentFont = $scriptEditorControl.Font
					$scriptEditorControl.Font = New-Object -TypeName System.Drawing.Font -ArgumentList $currentFont.Name,($currentFont.SizeInPoints - 1),$currentFont.Style
				}
			}
			if (($currentEmbeddedConsoleFont) -and
			    ($currentEmbeddedConsoleFont.Size -lt 32) -and
			    ($richTextBox = $embeddedConsoleWindow.Control.Controls.Find('RichTextBox1',$true) | Select-Object -First 1)) {
				$richTextBox.Font = New-Object -TypeName System.Drawing.Font -ArgumentList $currentEmbeddedConsoleFont.Name,($currentEmbeddedConsoleFont.SizeInPoints - 1),$currentEmbeddedConsoleFont.Style
				$embeddedConsoleWindow.Control.Font = New-Object -TypeName System.Drawing.Font -ArgumentList $currentEmbeddedConsoleFont.Name,($currentEmbeddedConsoleFont.SizeInPoints - 1),$currentEmbeddedConsoleFont.Style
				$richTextBox.MoveCursorToEnd()
			}
		}
		$PGSE.Commands.Add($zoomOutCommand)
	}
	if ($zoomInMenuItem = $viewMenu.Items['ViewCommand.ZoomIn']) {
		$index = $viewMenu.Items.IndexOf($zoomInMenuItem)
	}
	if ($index -ge 0) {
		$viewMenu.Items.Insert($index + 1,$zoomOutCommand)
	} else {
		$viewMenu.Items.Add($zoomOutCommand)
	}
}

#endregion

#region Create the ClearPowerShellConsole menu item in the View menu.

if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
    (-not ($clearConsoleMenuItem = $viewMenu.Items['ViewCommand.ClearPowerShellConsole']))) {
	if (-not ($clearConsoleCommand = $PGSE.Commands['ViewCommand.ClearPowerShellConsole'])) {
		$clearConsoleCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'ViewCommand','ClearPowerShellConsole'
		$clearConsoleCommand.Text = 'Cl&ear PowerShell Console'
		$clearConsoleCommand.Image = $imageLibrary['ClearConsoleImage16']
		$clearConsoleCommand.AddShortcut('Control+R')
		$clearConsoleCommand.ScriptBlock = {
			Clear-Host
		}
		$PGSE.Commands.Add($clearConsoleCommand)
	}
	$viewMenu.Items.Add($clearConsoleCommand)
	if ($clearConsoleMenuItem = $viewMenu.Items['ViewCommand.ClearPowerShellConsole']) {
		$clearConsoleMenuItem.FirstInGroup = $true
	}
}

#endregion

#region Determine if the script is running in STA mode.

$staMode = ([System.Threading.Thread]::CurrentThread.ApartmentState -eq [System.Threading.ApartmentState]::STA)

#endregion

#region Add a shortcut to the New command.

if ($newCommand = $PGSE.Commands['FileCommand.New']) {
	$newCommand.AddShortcut('Control+T')
}

#endregion

#region Add a shortcut to the Open command.

if ($openCommand = $PGSE.Commands['FileCommand.Open']) {
	$openCommand.AddShortcut('Control+F12')
}

#endregion

#region Add a shortcut to the CloseTab command.

if ($closeTabCommand = $PGSE.Commands['FileCommand.CloseTab']) {
	$closeTabCommand.AddShortcut('Control+F4')
}

#endregion

#region Add a shortcut to the Search command.

if ($searchCommand = $PGSE.Commands['EditCommand.Search']) {
	$searchCommand.AddShortcut('Control+H')
}

#endregion

#region Add a shortcut to the Output command.

if ($outputCommand = $PGSE.Commands['GoCommand.Output']) {
	$outputCommand.AddShortcut('Control+OemPeriod')
}

#endregion

#region Add a shortcut to the Code command.

if ($codeCommand = $PGSE.Commands['GoCommand.Code']) {
	$codeCommand.AddShortcut('Control+Oemcomma')
}

#endregion

#region Set the IncreaseIndent command icon.

$increaseIndentImageSet = $false
if (($increaseIndentCommand = $PGSE.Commands['EditCommand.IncreaseIndent']) -and ($increaseIndentCommand.Image -eq $null)) {
	$increaseIndentCommand.Image = $imageLibrary['IncreaseIndentImage16']
	$increaseIndentImageSet = $true
}

#endregion

#region Set the DecreaseIndent command icon.

$decreaseIndentImageSet = $false
if (($decreaseIndentCommand = $PGSE.Commands['EditCommand.DecreaseIndent']) -and ($decreaseIndentCommand.Image -eq $null)) {
	$decreaseIndentCommand.Image = $imageLibrary['DecreaseIndentImage16']
	$decreaseIndentImageSet = $true
}
#endregion

#region Update the border style for the status bar items that are currently on the bottom right.

if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
	for ($index = 2; $index -lt $statusBar.Items.Count; $index++) {
		$statusBar.Items[$index].BorderStyle = [System.Windows.Forms.Border3DStyle]::Etched
		$statusBar.Items[$index].BorderSides = [System.Windows.Forms.ToolStripStatusLabelBorderSides]::Left
	}
}

#endregion

#region Add the current encoding property to the Status Bar.

if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
	$encodingStatusLabel = New-Object -TypeName System.Windows.Forms.ToolStripStatusLabel
	$encodingStatusLabel.Name = 'Encoding'
	$encodingStatusLabel.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
	$encodingStatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
	$encodingStatusLabel.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
	$encodingStatusLabel.BorderStyle = [System.Windows.Forms.Border3DStyle]::Etched
	$encodingStatusLabel.BorderSides = [System.Windows.Forms.ToolStripStatusLabelBorderSides]::Left
	$encodingStatusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
	$encodingStatusLabel.Text = ''
	$encodingStatusLabel.Visible = $false
	$statusBar.Items.Insert($statusBar.Items.Count - 1, $encodingStatusLabel)
	Update-FileEncodingInternal
}

#endregion

#region Add the process architecture to the Status Bar for 64-bit machines.

if (($env:PROCESSOR_ARCHITECTURE -match '64') -and
    ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1'])) {
	$processArchitectureLabel = New-Object -TypeName System.Windows.Forms.ToolStripStatusLabel
	$processArchitectureLabel.Name = 'ProcessArchitecture'
	$processArchitectureLabel.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
	$processArchitectureLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
	$processArchitectureLabel.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
	$processArchitectureLabel.BorderStyle = [System.Windows.Forms.Border3DStyle]::Etched
	$processArchitectureLabel.BorderSides = [System.Windows.Forms.ToolStripStatusLabelBorderSides]::Left
	$processArchitectureLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
	$processArchitectureLabel.Text = '64-bit'
	if (([System.Windows.Forms.Application]::ExecutablePath | Split-Path -Leaf) -eq 'ScriptEditor_x86.exe') {
		$processArchitectureLabel.Text = '32-bit'
	}
	$statusBar.Items.Insert($statusBar.Items.Count - 1, $processArchitectureLabel)
	$processArchitectureLabel.Visible = $true
}

#endregion

#region Add the apartment state to the Status Bar.

if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
	$apartmentStateLabel = New-Object -TypeName System.Windows.Forms.ToolStripStatusLabel
	$apartmentStateLabel.Name = 'ApartmentState'
	$apartmentStateLabel.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
	$apartmentStateLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
	$apartmentStateLabel.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
	$apartmentStateLabel.BorderStyle = [System.Windows.Forms.Border3DStyle]::Etched
	$apartmentStateLabel.BorderSides = [System.Windows.Forms.ToolStripStatusLabelBorderSides]::Left
	$apartmentStateLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
	$apartmentStateLabel.Text = [System.Threading.Thread]::CurrentThread.ApartmentState.ToString()
	$statusBar.Items.Insert($statusBar.Items.Count - 1, $apartmentStateLabel)
	$apartmentStateLabel.Visible = $true
}

#endregion

#region Add the elevated status to the Status Bar if the session is elevated.

$elevatedMode = $false
if ([System.Environment]::OSVersion.Version.Major -gt 5) {
	$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	$windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
	$elevatedMode = $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
if ($elevatedMode -and 
    ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1'])) {
	$elevationStatusLabel = New-Object -TypeName System.Windows.Forms.ToolStripStatusLabel
	$elevationStatusLabel.Name = 'ElevationStatus'
	$elevationStatusLabel.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
	$elevationStatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
	$elevationStatusLabel.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
	$elevationStatusLabel.BorderStyle = [System.Windows.Forms.Border3DStyle]::Etched
	$elevationStatusLabel.BorderSides = [System.Windows.Forms.ToolStripStatusLabelBorderSides]::Left
	$elevationStatusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
	$elevationStatusLabel.Text = 'Elevated'
	$elevationStatusLabel.ForeColor = [System.Drawing.Color]::Red
	$statusBar.Items.Insert($statusBar.Items.Count - 1, $elevationStatusLabel)
	$elevationStatusLabel.Visible = $true
}

#endregion

#region Activate the OnTabChanged event handler.

$PGSE.add_CurrentDocumentWindowChanged($onTabChanged)

#endregion

#region Override the OnOpening event handler.

if ($openCommand = $PGSE.Commands['FileCommand.Open']) {
	$openCommand.add_Invoking($onOpening)
}

#endregion

#region Activate the OnOpened event handler.

if ($openCommand = $PGSE.Commands['FileCommand.Open']) {
	$openCommand.add_Invoked($onOpened)
}

#endregion

#region Override the OnSearching event handler.
<#
if ($searchCommand = $PGSE.Commands['EditCommand.Search']) {
	$searchCommand.add_Invoking($onSearching)
}
#>
#endregion

#region Override the OnGoingTo event handler.

if ($goToCommand = $PGSE.Commands['EditCommand.GoTo']) {
	$goToCommand.add_Invoking($onGoingTo)
}

#endregion

#region Activate the OnNew event handler.

if ($newCommand = $PGSE.Commands['FileCommand.New']) {
	$newCommand.add_Invoked($onNew)
}

#endregion

#region Override the OnExecutingSelection event handler.

if ($executeSelectionCommand = $PGSE.Commands['DebugCommand.ExecuteSelection']) {
	$executeSelectionCommand.add_Invoking($onExecutingSelection)
}

#endregion

#region Process the current state of the editor.

foreach ($item in $PGSE.DocumentWindows) {
	Update-ScriptEditorWordWrapInternal -DocumentWindow $item
	Update-ScriptEditorViewWhitespaceInternal -DocumentWindow $item
	Update-ScriptEditorVirtualWhitespaceInternal -DocumentWindow $item
}

Update-ScriptEditorTabStripScrollingInternal
Update-FileEncodingInternal

#endregion

#region Clean-up the Add-on when it is removed.

$ExecutionContext.SessionState.Module.OnRemove = {
	#region Remove changes enabled by this Add-on.

	foreach ($item in $PGSE.DocumentWindows) {
		Disable-ScriptEditorWordWrapInternal -DocumentWindow $item
		Disable-ScriptEditorViewWhitespaceInternal -DocumentWindow $item
		Disable-ScriptEditorVirtualWhitespaceInternal -DocumentWindow $item
	}

	Disable-ScriptEditorTabStripScrollingInternal

	#endregion

	#region Deactivate the OnExecutingSelection event handler override.

	if ($executeSelectionCommand = $PGSE.Commands['DebugCommand.ExecuteSelection']) {
		$executeSelectionCommand.remove_Invoking($onExecutingSelection)
	}

	#endregion

	#region Remove the OnNew event handler.

	if ($newCommand = $PGSE.Commands['FileCommand.New']) {
		$newCommand.remove_Invoked($onNew)
	}

	#endregion

	#region Deactivate the OnGoingTo event handler override.

	if ($goToCommand = $PGSE.Commands['EditCommand.GoTo']) {
		$goToCommand.remove_Invoking($onGoingTo)
	}

	#endregion

	#region Deactivate the OnSearching event handler override.
<#
	if ($searchCommand = $PGSE.Commands['EditCommand.Search']) {
		$searchCommand.remove_Invoking($onSearching)
	}
#>
	#endregion

	#region Remove the OnOpened event handler.

	if ($openCommand = $PGSE.Commands['FileCommand.Open']) {
		$openCommand.remove_Invoked($onOpened)
	}

	#endregion

	#region Deactivate the OnOpening event handler override.

	if ($openCommand = $PGSE.Commands['FileCommand.Open']) {
		$openCommand.remove_Invoking($onOpening)
	}

	#endregion

	#region Remove the OnTabChanged event handler.

	$PGSE.remove_CurrentDocumentWindowChanged($onTabChanged)

	#endregion

	#region Remove the elevation status property from the Status Bar.

	if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
		$statusBar.Items.RemoveByKey('ElevationStatus')
	}

	#endregion

	#region Remove the apartment state property from the Status Bar.

	if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
		$statusBar.Items.RemoveByKey('ApartmentState')
	}

	#endregion

	#region Remove the process architecture property from the Status Bar.

	if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
		$statusBar.Items.RemoveByKey('ProcessArchitecture')
	}

	#endregion

	#region Remove the current encoding property from the Status Bar.

	if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
		$statusBar.Items.RemoveByKey('Encoding')
	}

	#endregion

	#region Reset the Status Bar item borders.

	if ($statusBar = $PGSE.ToolWindows['PowerShellConsole'].Control.TopLevelControl.Controls['statusStrip1']) {
		for ($index = 1; $index -lt $statusBar.Items.Count; $index++) {
			$statusBar.Items[$index].BorderStyle = [System.Windows.Forms.Border3DStyle]::Flat
			$statusBar.Items[$index].BorderSides = [System.Windows.Forms.ToolStripStatusLabelBorderSides]::None
		}
	}

	#endregion

	#region Reset the DecreaseIndent command icon.

	if (($decreaseIndentImageSet) -and
	    ($decreaseIndentCommand = $PGSE.Commands['EditCommand.DecreaseIndent'])) {
		$decreaseIndentCommand.Image = $null
		$decreaseIndentImageSet = $false
	}

	#endregion

	#region Reset the IncreaseIndent command icon.

	if (($increaseIndentImageSet) -and
	    ($inncreaseIndentCommand = $PGSE.Commands['EditCommand.IncreaseIndent'])) {
		$increaseIndentCommand.Image = $null
		$increaseIndentImageSet = $false
	}

	#endregion

	#region Remove a shortcut from the Code command.

	if ($codeCommand = $PGSE.Commands['GoCommand.Code']) {
		foreach ($shortcut in $codeCommand.Shortcuts) {
			if ($shortcut.Key -eq 'Control+Oemcomma') {
				$codeCommand.Shortcuts.Remove($shortcut)
				break
			}
		}
	}

	#endregion

	#region Remove a shortcut from the Output command.

	if ($outputCommand = $PGSE.Commands['GoCommand.Output']) {
		foreach ($shortcut in $outputCommand.Shortcuts) {
			if ($shortcut.Key -eq 'Control+OemPeriod') {
				$outputCommand.Shortcuts.Remove($shortcut)
				break
			}
		}
	}

	#endregion

	#region Remove a shortcut from the Search command.

	if ($searchCommand = $PGSE.Commands['EditCommand.Search']) {
		foreach ($shortcut in $searchCommand.Shortcuts) {
			if ($shortcut.Key -eq 'Control+H') {
				$searchCommand.Shortcuts.Remove($shortcut)
				break
			}
		}
	}

	#endregion

	#region Remove a shortcut from the CloseTab command.

	if ($closeTabCommand = $PGSE.Commands['FileCommand.CloseTab']) {
		foreach ($shortcut in $closeTabCommand.Shortcuts) {
			if ($shortcut.Key -eq 'Control+F4') {
				$closeTabCommand.Shortcuts.Remove($shortcut)
				break
			}
		}
	}

	#endregion

	#region Remove a shortcut from the Open command.

	if ($openCommand = $PGSE.Commands['FileCommand.Open']) {
		foreach ($shortcut in $openCommand.Shortcuts) {
			if ($shortcut.Key -eq 'Control+F12') {
				$openCommand.Shortcuts.Remove($shortcut)
				break
			}
		}
	}

	#endregion

	#region Remove a shortcut from the New command.

	if ($newCommand = $PGSE.Commands['FileCommand.New']) {
		foreach ($shortcut in $newCommand.Shortcuts) {
			if ($shortcut.Key -eq 'Control+T') {
				$newCommand.Shortcuts.Remove($shortcut)
				break
			}
		}
	}

	#endregion

	#region Remove the ClearPowerShellConsole menu item from the View menu.

	if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
	    ($clearPowerShellConsoleMenuItem = $viewMenu.Items['ViewCommand.ClearPowerShellConsole'])) {
		$viewMenu.Items.Remove($clearPowerShellConsoleMenuItem) | Out-Null
	}

	if ($clearPowerShellConsoleCommand = $PGSE.Commands['ViewCommand.ClearPowerShellConsole']) {
		$PGSE.Commands.Remove($clearPowerShellConsoleCommand) | Out-Null
	}

	#endregion

	#region Remove the ZoomOut menu item from the View menu.

	if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
	    ($zoomOutMenuItem = $viewMenu.Items['ViewCommand.ZoomOut'])) {
		$viewMenu.Items.Remove($zoomOutMenuItem) | Out-Null
	}

	if ($zoomOutCommand = $PGSE.Commands['ViewCommand.ZoomOut']) {
		$PGSE.Commands.Remove($zoomOutCommand) | Out-Null
	}

	#endregion

	#region Remove the ZoomIn menu item from the View menu.

	if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
	    ($zoomInMenuItem = $viewMenu.Items['ViewCommand.ZoomIn'])) {
		$viewMenu.Items.Remove($zoomInMenuItem) | Out-Null
	}

	if ($zoomInCommand = $PGSE.Commands['ViewCommand.ZoomIn']) {
		$PGSE.Commands.Remove($zoomInCommand) | Out-Null
	}

	#endregion

	#region Remove the TabScrollButtons menu item from the View menu.

	if (($viewMenu = $PGSE.Menus['MenuBar.View']) -and
	    ($tabScrollButtonsMenuItem = $viewMenu.Items['ViewCommand.TabScrollButtons'])) {
		$viewMenu.Items.Remove($tabScrollButtonsMenuItem) | Out-Null
	}

	if ($tabScrollButtonsCommand = $PGSE.Commands['ViewCommand.TabScrollButtons']) {
		$PGSE.Commands.Remove($tabScrollButtonsCommand) | Out-Null
	}

	#endregion

	#region Remove the VirtualWhiteSpace menu item from the Edit|Advanced menu.
	
	if (($editMenu = $PGSE.Menus['MenuBar.Edit']) -and
	    ($editAdvancedMenu = $editMenu.Items['EditCommand.Advanced']) -and
	    ($virtualWhiteSpaceMenuItem = $editAdvancedMenu.Items['EditCommand.VirtualWhiteSpace'])) {
		$editAdvancedMenu.Items.Remove($virtualWhiteSpaceMenuItem) | Out-Null
	}

	if ($virtualWhiteSpaceCommand = $PGSE.Commands['EditCommand.VirtualWhiteSpace']) {
		$PGSE.Commands.Remove($virtualWhiteSpaceCommand) | Out-Null
	}
	
	#endregion
	
	#region Remove the WordWrap menu item from the Edit|Advanced menu.

	if (($editMenu = $PGSE.Menus['MenuBar.Edit']) -and
	    ($editAdvancedMenu = $editMenu.Items['EditCommand.Advanced']) -and
	    ($wordWrapMenuItem = $editAdvancedMenu.Items['EditCommand.WordWrap'])) {
		$editAdvancedMenu.Items.Remove($wordWrapMenuItem) | Out-Null
	}

	if ($wordWrapCommand = $PGSE.Commands['EditCommand.WordWrap']) {
		$PGSE.Commands.Remove($wordWrapCommand) | Out-Null
	}

	#endregion

	#region Remove the ViewWhitespace menu item from the Edit|Advanced menu.

	if (($editMenu = $PGSE.Menus['MenuBar.Edit']) -and
	    ($editAdvancedMenu = $editMenu.Items['EditCommand.Advanced']) -and
	    ($viewWhitespaceMenuItem = $editAdvancedMenu.Items['EditCommand.ViewWhitespace'])) {
		$editAdvancedMenu.Items.Remove($viewWhitespaceMenuItem) | Out-Null
	}

	if ($viewWhitespaceCommand = $PGSE.Commands['EditCommand.ViewWhitespace']) {
		$PGSE.Commands.Remove($viewWhitespaceCommand) | Out-Null
	}

	#endregion

	#region Remove the Encoding submenu from the File menu.

	if (($fileMenu = $PGSE.Menus['MenuBar.File']) -and 
	    ($encodingSubmenu = $fileMenu.Items['FileCommand.Encoding'])) {
		$removeMenuItemScriptBlock = {
			param(
				[Quest.PowerGUI.SDK.BarItem]$MenuItem,
				[Quest.PowerGUI.SDK.BarMenu]$Parent
			)
			if ($MenuItem -is [Quest.PowerGUI.SDK.BarMenu]) {
				foreach ($item in @($MenuItem.Items)) {
					& $removeMenuItemScriptBlock -Parent $MenuItem -MenuItem $item
				}
			}
			$commandName = $MenuItem.Command.FullName
			if ($Parent -ne $null) {
				$Parent.Items.Remove($MenuItem) | Out-Null
			} else {
				$PGSE.Menus.Remove($MenuItem) | Out-Null
			}
			if ($command = $PGSE.Commands[$commandName]) {
				$PGSE.Commands.Remove($command) | Out-Null
			}
		}
		& $removeMenuItemScriptBlock -MenuItem $encodingSubmenu -Parent $fileMenu
	}

	#endregion
}
#endregion

# SIG # Begin signature block
# MIIdfwYJKoZIhvcNAQcCoIIdcDCCHWwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUuqzTX45j7fH68gQfJ0BnfUIa
# kNKgghi8MIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5
# MDExMjAwMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJH
# bG9iYWxTaWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDaDuaZjc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6a
# rymAZavpxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCO
# XkNz8kHp1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6T
# RGHRjcdGsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux
# 2x8gkasJU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlD
# SgeF59N89iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
# HRMBAf8EBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkq
# hkiG9w0BAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoR
# SLblCKOzyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQL
# cFGUl5gE38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrg
# lfCm7ymPAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr
# +WymXUadDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XS
# QRjbgbMEHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4DCCBAcwggLvoAMCAQICCwEA
# AAAAAR5GQJ02MA0GCSqGSIb3DQEBBQUAMGMxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMRYwFAYDVQQLEw1PYmplY3RTaWduIENBMSEwHwYD
# VQQDExhHbG9iYWxTaWduIE9iamVjdFNpZ24gQ0EwHhcNMDgxMjE3MTc0ODAyWhcN
# MTExMjE3MTc0ODAyWjBhMQswCQYDVQQGEwJVUzEXMBUGA1UEChMOUXVlc3QgU29m
# dHdhcmUxFzAVBgNVBAMTDlF1ZXN0IFNvZnR3YXJlMSAwHgYJKoZIhvcNAQkBFhFz
# dXBwb3J0QHF1ZXN0LmNvbTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1mza
# 2hKiiqZnaF1sHhuFRS7MEGq9tYhF7AFbJRvTvhCZk9sxK92thKBFyDSOzJauB7Zt
# j+1HwQzpqbbU94EsR09JOf8vB+xQKLCxaBP5YjwhjJzVy+1d6frVWYN1oVxPXRBM
# G7BnFgfRkOdtsg/Qn1Uqn1ENSozyjTuh5iduUy0CAwEAAaOCAUAwggE8MB8GA1Ud
# IwQYMBaAFNJb80smS6Ww5139Vn/28S44TlOgME4GCCsGAQUFBwEBBEIwQDA+Bggr
# BgEFBQcwAoYyaHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLm5ldC9jYWNlcnQvT2Jq
# ZWN0U2lnbi5jcnQwOQYDVR0fBDIwMDAuoCygKoYoaHR0cDovL2NybC5nbG9iYWxz
# aWduLm5ldC9PYmplY3RTaWduLmNybDAJBgNVHRMEAjAAMA4GA1UdDwEB/wQEAwIH
# gDATBgNVHSUEDDAKBggrBgEFBQcDAzBLBgNVHSAERDBCMEAGCSsGAQQBoDIBMjAz
# MDEGCCsGAQUFBwIBFiVodHRwOi8vd3d3Lmdsb2JhbHNpZ24ubmV0L3JlcG9zaXRv
# cnkvMBEGCWCGSAGG+EIBAQQEAwIEEDANBgkqhkiG9w0BAQUFAAOCAQEAG9hUuQek
# ddDJ/pzfqo9p4hzKBkeKcVsunEeTUMNg90XzgdOYRFJPCD7T+gXXrTs6Y2xFmLJN
# G/2lQsjQ/32cBBN9zZdbX+ExhFfEV9/w0gbw3H/PfYkCRvp9VZlTafIt4MJCt/Zp
# guPQgggpWadScg7jQNyeHEg6H6c3WHO8PMiKcKJp9LuM1PKX9Bjy6F2k8rbdEAyJ
# u0mIiAcnEAc/KwoKBZVT1gnT3rkwgTgNlXw2hqT/Zcf8Jy4IDzbKzL+gYmDCNaju
# wAzhzaA05oZTLwhFV1sdc5MSJVJnMJVLpNO1jrhi5g6Oo6EmezM/kE8nzoXbmTlP
# JjOApuATvUdFlzCCBA0wggL1oAMCAQICCwQAAAAAASOeD6yzMA0GCSqGSIb3DQEB
# BQUAMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRAw
# DgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxTaWduIFJvb3QgQ0EwHhcN
# OTkwMTI4MTMwMDAwWhcNMTcwMTI3MTIwMDAwWjCBgTELMAkGA1UEBhMCQkUxGTAX
# BgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExJTAjBgNVBAsTHFByaW1hcnkgT2JqZWN0
# IFB1Ymxpc2hpbmcgQ0ExMDAuBgNVBAMTJ0dsb2JhbFNpZ24gUHJpbWFyeSBPYmpl
# Y3QgUHVibGlzaGluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AKKbdSqnE7oJcSQY36EGYikSntyedXPo31ZXaZYTVk/yyLwBWO0mhnILYPUZxVUD
# V5u5EMmh1HRA/2wA6OZTN/632nk+uFI46YEsnw4zUqbNcM5KXWL00WdevJdKB8q8
# 3Y1Hsc3xZVuFAbBLa97Nji71UOijnJ0mmGs2Y0EDcETwX+IldXlQfV+hBqJGDFWV
# RxTTkUaGaJnnJ/SU7JpBUfeW1HqM4USXaHED2FhvvbQQQu4NZnVGi0SW0jAAEgdj
# 90SbAXDKVm+cWJcqJxeLLnFSbUarpysPfxZIZMhS+gYXAAd010WzDPV4lXPoCu7E
# 4HKMHhGqHrtezvm0AO5zvc0CAwEAAaOBrjCBqzAOBgNVHQ8BAf8EBAMCAQYwDwYD
# VR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUFVF5GnwMWfnazdjEOhOayXgtf00wMwYD
# VR0fBCwwKjAooCagJIYiaHR0cDovL2NybC5nbG9iYWxzaWduLm5ldC9Sb290LmNy
# bDATBgNVHSUEDDAKBggrBgEFBQcDAzAfBgNVHSMEGDAWgBRge2YaRQ2XyolQL30E
# zTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEAtXimonwEt3/Jf31qvHH6KTBgwvRi
# Hv5/Qx6bbuKyH3MLhXZbffVOSQYv1Pq3kUDv7W+NjhODVMUqAj0KpNyZC3q9dy/M
# QMGP88SMTnK6EHzm/2Qrx85sp/zXmnyORo0Bg01CO9ucP58yYVfXF7CzNmbws/1E
# b4E3sZROp1YlifWK1m0RYmJ5XEKQAhjTnCP8COhkRbktfoBbTq/DiimSg3gfkUE0
# r4XF/QeZTixc/sf9F7slJTFNcrW1KUtImjdvE8cRTkpFHn4vMZyr6FKv1meXNIhf
# DidqZlLRWsesMCwgON0r/zrrzhBFgqJ7G6Egc1abKpPmBFEGbBvcL4mUkzCCBBow
# ggMCoAMCAQICCwQAAAAAASAZwZBmMA0GCSqGSIb3DQEBBQUAMFcxCzAJBgNVBAYT
# AkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENB
# MRswGQYDVQQDExJHbG9iYWxTaWduIFJvb3QgQ0EwHhcNMDkwMzE4MTEwMDAwWhcN
# MjgwMTI4MTIwMDAwWjBUMRgwFgYDVQQLEw9UaW1lc3RhbXBpbmcgQ0ExEzARBgNV
# BAoTCkdsb2JhbFNpZ24xIzAhBgNVBAMTGkdsb2JhbFNpZ24gVGltZXN0YW1waW5n
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwwy3Eg1NaIoz3jYF
# 8Dy69drNDlN7Rp+C8mIT18F3rbuBN35PHpOBwQYi2h1QhMaXlZKpk7Y9q4Z5GVR9
# DhYETMSIlyzGoahfFTrSZCvMPgx66KRWsR67z4TOjTU6NJxsLcB3tTCpH2fmOglE
# OkNyQaKRw0aaH7a5pw+vHHUbZCXnCGwUR/VHGt6O6qJjlX31qK1VomSbcm+5AnM/
# OYo5XMT+j/sRnL0QGUlj0EMii9arkpl0FM8wB75Pvf2Kj55a3208zFqZUJC5rcKX
# Q8Jf7c0zPYfMwaBbqWI7eH1ko6xNHyvXAxFscVSKsKuxHNZ9I9tABzcm21CvOD2m
# B3VvlwIDAQABo4HpMIHmMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/
# AgEAMB0GA1UdDgQWBBTowvHEMtwzNTe8ZXb1nBcuF0Us/jBLBgNVHSAERDBCMEAG
# CSsGAQQBoDIBHjAzMDEGCCsGAQUFBwIBFiVodHRwOi8vd3d3Lmdsb2JhbHNpZ24u
# bmV0L3JlcG9zaXRvcnkvMDMGA1UdHwQsMCowKKAmoCSGImh0dHA6Ly9jcmwuZ2xv
# YmFsc2lnbi5uZXQvcm9vdC5jcmwwHwYDVR0jBBgwFoAUYHtmGkUNl8qJUC99BM00
# qP/8/UswDQYJKoZIhvcNAQEFBQADggEBAF32yysNAUCEn4V6Q3Bq4MXnqgYA12cT
# yQiRMWVPFKipBdw4nmqgMAq9jceAKO5CRcqU895YRamAMgT1WVxqcAA5J5RN9bRG
# NOgcUzGys1QW6cxCq9XZWTAc+0YnJbiHI7HodYgkgx7Idjd7AUlFSKTt4l3SfJyi
# 3C26EFoSYmWrrgDHEDQ7y3K9FCQM3MN2J7Sn/uFYKfIOFp+ROR2JpuYPHIeM4lis
# kn4kPqrsFOc6MzSLxjusg6sPFGJ6uhotTUsbxTDwC5J5fTx44Pjm0hWWWZk5KzBh
# 6Lj4wKHpIhQReH3E3Im+wLuU4XKu67VAQE/vFx5YXtCoiZaskijpur8wggQuMIID
# FqADAgECAgsBAAAAAAElsLTMATANBgkqhkiG9w0BAQUFADBUMRgwFgYDVQQLEw9U
# aW1lc3RhbXBpbmcgQ0ExEzARBgNVBAoTCkdsb2JhbFNpZ24xIzAhBgNVBAMTGkds
# b2JhbFNpZ24gVGltZXN0YW1waW5nIENBMB4XDTA5MTIyMTA5MzI1NloXDTIwMTIy
# MjA5MzI1NlowUjELMAkGA1UEBhMCQkUxFjAUBgNVBAoTDUdsb2JhbFNpZ24gTlYx
# KzApBgNVBAMTIkdsb2JhbFNpZ24gVGltZSBTdGFtcGluZyBBdXRob3JpdHkwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDNwj1ddyLQwn04MsMVgx9CajtT
# Zt1qNkQNac9ojYlFn34v7kI6M3w+ANOXatha1cNNkgpfBlD9v2zEA6KCYNjtUi4T
# dN6XxkUhe1X26rFkA/x0a7Jfx2xsQxSKJBA3SZWB0kgSpaJ2SVAhf8qFcwo8XbUu
# rZCqXk0yyxeT2X+WwMCJZVbZxbE/mBsn+knuHRvLBowwHDvFp3BbqKsYWv7I9o6/
# AV2PYZg0D1hR/98y6lRlHBQrbPwMkBln7ZvZ2mOb1loko3SOCCMAoZK1HgvRCKBm
# f5Ibo+2AZAJJj7aE79FVjl6pl1rFCAKIlFa/kusqLQY1krU3NjHsw/56O8KFAgMB
# AAGjggEBMIH+MB8GA1UdIwQYMBaAFOjC8cQy3DM1N7xldvWcFy4XRSz+MDwGA1Ud
# HwQ1MDMwMaAvoC2GK2h0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5uZXQvVGltZXN0YW1w
# aW5nMS5jcmwwHQYDVR0OBBYEFKqqporvpGRz1pXieciP6s+lYCnKMAkGA1UdEwQC
# MAAwDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEsGA1Ud
# IAREMEIwQAYJKwYBBAGgMgEeMDMwMQYIKwYBBQUHAgEWJWh0dHA6Ly93d3cuZ2xv
# YmFsc2lnbi5uZXQvcmVwb3NpdG9yeS8wDQYJKoZIhvcNAQEFBQADggEBALyJ7P7m
# NlWTXHnUEXqGgI8XtpOybZuRoVYYEcZV6vYI7a2bnvUrgci73WB7G0eZHm1APh2A
# whPVjgQFL9vnrlKeaIRyoeVKYDz4m9UvRtjDsreTU6ybbEMkJNHx/OlWLjQRWBhD
# 6u//NHRsoMBsf60DGWmIHpVgyru9DLt278cksIHGODHPNq0MOLiQIISbLo8ouZ/2
# ypQnzaw5YVfg45VanHaSMPXeppc9chwqYDKoM02GNTOKXPOk/fcGLOFrSzD1y9ND
# YvhBud59IMsFjI4s9l81/TONQollCDYso4n0WoWLsLl722zLofjSDhu7l3zRJ3m+
# nXw75qdWNNjJkakwggTTMIIDu6ADAgECAgsEAAAAAAEjng+vJDANBgkqhkiG9w0B
# AQUFADCBgTELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# JTAjBgNVBAsTHFByaW1hcnkgT2JqZWN0IFB1Ymxpc2hpbmcgQ0ExMDAuBgNVBAMT
# J0dsb2JhbFNpZ24gUHJpbWFyeSBPYmplY3QgUHVibGlzaGluZyBDQTAeFw0wNDAx
# MjIxMDAwMDBaFw0xNzAxMjcxMDAwMDBaMGMxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMRYwFAYDVQQLEw1PYmplY3RTaWduIENBMSEwHwYD
# VQQDExhHbG9iYWxTaWduIE9iamVjdFNpZ24gQ0EwggEiMA0GCSqGSIb3DQEBAQUA
# A4IBDwAwggEKAoIBAQCwsfKAAHDO7MOMtJftxgmMJm+J32dZgc/eFBNMwrFF4lN1
# QfoHNm+6EXAolHxtcr0HFSVlOgn/hdz6e143hzjkx0sIgJieis1YCQLAwwFJlliI
# iSZZ9W3GucH7GCXt2GJOygpsXXDvztObKQsJxvbuthbUPFSOzF3gr9vdIwkyezKB
# FmIKBst6zzQhtm82trHOy5opNUA+nVh8/62CmPq41YnKNd3LzVcGy5vkv5SogJhf
# d5bwtuerdHlAIaZj6dAHkb2FOLSulqyh/xRz2qVFuE2Gzio879TfKA51qaiIE8Lk
# fGCT8iXMA4SX5k62ny3WtYs0PKvVODrIPcSx+ZTNAgMBAAGjggFnMIIBYzAOBgNV
# HQ8BAf8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU0lvzSyZL
# pbDnXf1Wf/bxLjhOU6AwSgYDVR0gBEMwQTA/BgkrBgEEAaAyATIwMjAwBggrBgEF
# BQcCARYkaHR0cDovL3d3dy5nbG9iYWxzaWduLm5ldC9yZXBvc2l0b3J5MDkGA1Ud
# HwQyMDAwLqAsoCqGKGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5uZXQvcHJpbW9iamVj
# dC5jcmwwTgYIKwYBBQUHAQEEQjBAMD4GCCsGAQUFBzAChjJodHRwOi8vc2VjdXJl
# Lmdsb2JhbHNpZ24ubmV0L2NhY2VydC9QcmltT2JqZWN0LmNydDARBglghkgBhvhC
# AQEEBAMCAAEwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHwYDVR0jBBgwFoAUFVF5GnwM
# WfnazdjEOhOayXgtf00wDQYJKoZIhvcNAQEFBQADggEBAB5q8230jqki/nAIZS6h
# XaszMN1sePpL6q3FjewQemrFWJc5a5LzkeIMpygc0V12josHfBNvrcQ2Q7PBvDFZ
# zxg42KM7zv/KZ1i/4PGsYT6iOx68AltBrERr9Sbz7V6oZfbKZaY/yvV366WGKlgp
# Vvi+FhBA6dL8VyxjYTdmJTkgLgcDoDYDJZS9fOt+06PCxXYWdTCSuf92QTUhaNEO
# XlyOwwNg5oBA/MBdolRubpJnp4ESh6KjK9u3Tf/k1cflBebV8a78zWYYIfM+R8nl
# lUJhLJ0mgLIPqD0Oyad43250jCxG9nLpPGRrKFXES2Qzy3hUEzjw1XEG1D4NCjUO
# 4LMxggQtMIIEKQIBATByMGMxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxT
# aWduIG52LXNhMRYwFAYDVQQLEw1PYmplY3RTaWduIENBMSEwHwYDVQQDExhHbG9i
# YWxTaWduIE9iamVjdFNpZ24gQ0ECCwEAAAAAAR5GQJ02MAkGBSsOAwIaBQCgeDAY
# BgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3
# AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEW
# BBQjswsvu4g0Iyos9HqGfYPyTva9IDANBgkqhkiG9w0BAQEFAASBgMB11f/WJP09
# spUMfQ+pvyb3o80vjjS/v753dElrdD+HAHWliGlWlel6m1JCsdffCmPy8Dh3B7S/
# lH3Z+jQKlPEVHvbmZ5TTaI+sW1l/pkHHWkDbeZMU+vLCdstIccHt40SiWqyG0n1j
# fH/GelkseCAEnzNDoMgBgPA8uQU4VHXXoYIClzCCApMGCSqGSIb3DQEJBjGCAoQw
# ggKAAgEBMGMwVDEYMBYGA1UECxMPVGltZXN0YW1waW5nIENBMRMwEQYDVQQKEwpH
# bG9iYWxTaWduMSMwIQYDVQQDExpHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQQIL
# AQAAAAABJbC0zAEwCQYFKw4DAhoFAKCB9zAYBgkqhkiG9w0BCQMxCwYJKoZIhvcN
# AQcBMBwGCSqGSIb3DQEJBTEPFw0xMTA3MTkyMDI4MjlaMCMGCSqGSIb3DQEJBDEW
# BBS4qXB8lWbeaYzSGz27N+HzYn0uOjCBlwYLKoZIhvcNAQkQAgwxgYcwgYQwgYEw
# fwQUrt9992u6JBDWfbrxj1uhW0F+SWwwZzBYpFYwVDEYMBYGA1UECxMPVGltZXN0
# YW1waW5nIENBMRMwEQYDVQQKEwpHbG9iYWxTaWduMSMwIQYDVQQDExpHbG9iYWxT
# aWduIFRpbWVzdGFtcGluZyBDQQILAQAAAAABJbC0zAEwDQYJKoZIhvcNAQEBBQAE
# ggEAzKBLzK7MVJejqch5W6S+FGZkxP7J0Dwif1PMgaH4msi1MuWd4t2auWc042j+
# wBgSKqwfkJD4n/dy4c27/wcXZYmsTD8/J9UQJI+m2KIM7HXANUCcTFHGhl7ImA1b
# 04vdWkVZA4xLz49vfg+wxQYvoOWYzmiup4l4dGRQ+6XNRZsN+FM+OaRtXfoCxu3f
# iazk4Jy7YZ92FAi3h7DaubAErXtTPlqT4s8SX8VUhowHQXf7ZOfakJ4SAbXHy0nZ
# ereoTPd2Qo6FSKrufpOoi/adbPdkXQ+x6bC+sgLE4UBQa/HWXburQOJqZKdFURZu
# FlcihAisDsrBIgqz38C3fU9e1g==
# SIG # End signature block
