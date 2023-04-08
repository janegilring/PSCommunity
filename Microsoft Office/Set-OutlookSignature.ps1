#Custom variables
$CompanyName = 'Michael Graves'
$TemplateName = 'CraigFrazier'
$SigSource = '\\mga.com\SYSVOL\MGA.com\WR Scripts\SetOutlookSignature\'
$ForceSignatureNew = '1' #When the signature is forced it sets the default signature for new messages each time the script runs. 0 = no force, 1 = force
$ForceSignatureReplyForward = '1' #When the signature is forced it sets the default signature for reply/forward messages each time the script runs. 0 = no force, 1 = force
$SetSignatureNew = '0' #Determines wheter to set the signature as the default for new messages on first run. This is overridden if $ForceSignatureNew = 1. 0 = don't set, 1 = set
$SetSignatureReplyForward = '0' #Determines wheter to set the signature as the default for reply/forward messages on first run. This is overridden if $ForceSignatureReplyForward = 1. 0 = don't set, 1 = set

#Environment variables
$AppData = (Get-Item env:appdata).value
$SigPath = "\Microsoft\Signatures\"
$LocalSignaturePath = $AppData + $SigPath
$RemoteSignaturePathFull = $SigSource + "$TemplateName.docx"

#Get Active Directory information for current user
$UserName = $env:username
$Filter = "(&(objectCategory=User)(samAccountName=$UserName))"
$Searcher = New-Object System.DirectoryServices.DirectorySearcher
$Searcher.Filter = $Filter
$ADUserPath = $Searcher.FindOne()
$ADUser = $ADUserPath.GetDirectoryEntry()
$ADDisplayName = $ADUser.DisplayName #Fullname
$ADTitle = $ADUser.title #Title
$ADEmailAddress = $ADUser.mail #E-Mail

if ($ADUser.mobile)
{
	$ADMobile = 'c: ' + $ADUser.mobile #MobileNumber
}
else
{
	$ADMobile = ''
}

if ($ADUser.info)
{
	$suffix = ", " + $ADUser.info
}
else
{
	$suffix = ""
}

$ADModify = $ADUser.whenChanged

# Setting registry information for the current user
$CompanyRegPath = "HKCU:\Software\" + $CompanyName # Create parent registry folder
$SignatureRegPath = $CompanyRegPath + '\' + $TemplateName #  Create signature folder

if (Test-Path $CompanyRegPath) { }
else { New-Item -path "HKCU:\Software\" -name $CompanyName }
if (Test-Path $SignatureRegPath) { }
else { New-Item -path $CompanyRegPath -name $TemplateName }

Set-ItemProperty $CompanyRegPath"\$TemplateName" -name SignatureSourceFiles -Value $SigSource # Signature template file path

$SigVersion = (Get-ChildItem $RemoteSignaturePathFull).LastWriteTime # Last time the signature template file was modified
$SignatureVersion = (Get-ItemProperty $CompanyRegPath"\$TemplateName").SignatureVersion # Last time the signature was created / updated

$UserModify = (Get-ItemProperty $SignatureRegPath).UserAccountModifyDate # Last time the AD account was modified

$ForcedSignatureNew = (Get-ItemProperty $CompanyRegPath"\$TemplateName").ForcedSignatureNew # Value of force signature on new emails
$ForcedSignatureReplyForward = (Get-ItemProperty $CompanyRegPath"\$TemplateName").ForcedSignatureReplyForward # Value of force signature on replies and forwards

# Copying signature sourcefiles and creating signature if signature version is different from local version
if (($SignatureVersion -eq $SigVersion) -and ($UserModify -eq $ADModify)) { }
else
{
	#Copy signature templates from domain to local Signature-folder
	$NewLocalFilename = $LocalSignaturePath + "$TemplateName (" + $ADEmailAddress + ').docx'
	Copy-Item $RemoteSignaturePathFull $NewLocalFilename -Recurse -Force
	
	$ReplaceAll = 2
	$FindContinue = 1
	$MatchCase = $False
	$MatchWholeWord = $True
	$MatchWildcards = $False
	$MatchSoundsLike = $False
	$MatchAllWordForms = $False
	$Forward = $True
	$Wrap = $FindContinue
	$Format = $False
	
	#Insert variables from Active Directory to rtf signature-file
	$MSWord = New-Object -com word.application
	$fullPath = $LocalSignaturePath + "$TemplateName (" + $ADEmailAddress + ').docx'
	$MSWord.Documents.Open($fullPath)
	
	$FindText = "Name"
	$ReplaceText = $ADDisplayName.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll)
	
	$FindText = "Suffix"
	$ReplaceText = $suffix.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll)
	
	$FindText = "Title"
	$ReplaceText = $ADTitle.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll)
	
	$FindText = "Mobile"
	$ReplaceText = $ADMobile.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll)
	
	$FindText = "Email"
	$ReplaceText = $ADEmailAddress.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll)
	if ($MSWord.Selection.Find.Execute($ReplaceText.ToString()))
	{
		$MSWord.ActiveDocument.Hyperlinks.Add($MSWord.Selection.Range, "mailto:" + $ReplaceText.ToString(), $missing, $missing, $ReplaceText.ToString())
		$hyperlinks = $MSWord.ActiveDocument.Hyperlinks.item(1)
		$hyperlinks.Range.Font.Underline = "1"
	}
	
	$MSWord.ActiveDocument.Save()
	$saveFormat = [Enum]::Parse([Microsoft.Office.Interop.Word.WdSaveFormat], "wdFormatHTML");
	[ref]$BrowserLevel = "microsoft.office.interop.word.WdBrowserLevel" -as [type]
	
	$MSWord.ActiveDocument.WebOptions.OrganizeInFolder = $true
	$MSWord.ActiveDocument.WebOptions.UseLongFileNames = $true
	$MSWord.ActiveDocument.WebOptions.BrowserLevel = $BrowserLevel::wdBrowserLevelMicrosoftInternetExplorer6
	$HTMpath = $LocalSignaturePath + "$TemplateName (" + $ADEmailAddress + ").htm"
	$MSWord.ActiveDocument.saveas([ref]$HTMpath, [ref]$saveFormat)
	
	$saveFormat = [Enum]::Parse([Microsoft.Office.Interop.Word.WdSaveFormat], "wdFormatRTF");
	$RTFpath = $LocalSignaturePath + "$TemplateName (" + $ADEmailAddress + ").rtf"
	$MSWord.ActiveDocument.SaveAs([ref]$RTFpath, [ref]$saveFormat)
	
	$saveFormat = [Enum]::Parse([Microsoft.Office.Interop.Word.WdSaveFormat], "wdFormatText");
	$TXTpath = $LocalSignaturePath + "$TemplateName (" + $ADEmailAddress + ").txt"
	$MSWord.ActiveDocument.SaveAs([ref]$TXTpath, [ref]$saveFormat)
	$MSWord.ActiveDocument.Close()
	
	$MSWord.Quit()
	
	#Set signature for new mesages if enabled
	if ($SetSignatureNew -eq '1')
	{
		#Set company signature as default for New messages
		$MSWord = New-Object -com word.application
		$EmailOptions = $MSWord.EmailOptions
		$EmailSignature = $EmailOptions.EmailSignature
		$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
		$EmailSignature.NewMessageSignature = $TemplateName
		$MSWord.Quit()
	}
	
	#Set signature for reply/forward messages if enabled
	if ($SetSignatureReplyForward -eq '1')
	{
		#Set company signature as default for Reply/Forward messages
		$MSWord = New-Object -com word.application
		$EmailOptions = $MSWord.EmailOptions
		$EmailSignature = $EmailOptions.EmailSignature
		$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
		$EmailSignature.ReplyMessageSignature = $TemplateName
		$MSWord.Quit()
	}
	
}

Set-ItemProperty $SignatureRegPath -name UserAccountModifyDate -Value $ADModify.ToString()

#Stamp registry-values for Outlook Signature Settings if they doesn`t match the initial script variables. Note that these will apply after the second script run when changes are made in the "Custom variables"-section.
if ($ForcedSignatureNew -eq $ForceSignatureNew) { }
else
{
	Set-ItemProperty $CompanyRegPath"\$TemplateName" -name ForcedSignatureNew -Value $ForceSignatureNew
}

if ($ForcedSignatureReplyForward -eq $ForceSignatureReplyForward) { }
else
{
	Set-ItemProperty $CompanyRegPath"\$TemplateName" -name ForcedSignatureReplyForward -Value $ForceSignatureReplyForward
}

if ($SignatureVersion -eq $SigVersion) { }
else
{
	Set-ItemProperty $CompanyRegPath"\$TemplateName" -name SignatureVersion -Value $SigVersion
}

#Forcing signature for new messages if enabled
if ($ForceSignatureNew -eq '1')
{
	#Set company signature as default for New messages
	$MSWord = New-Object -com word.application
	$EmailOptions = $MSWord.EmailOptions
	$EmailSignature = $EmailOptions.EmailSignature
	$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
	$EmailSignature.NewMessageSignature = $TemplateName
	$MSWord.Quit()
}

#Forcing signature for reply/forward messages if enabled
if ($ForceSignatureReplyForward -eq '1')
{
	#Set company signature as default for Reply/Forward messages
	$MSWord = New-Object -com word.application
	$EmailOptions = $MSWord.EmailOptions
	$EmailSignature = $EmailOptions.EmailSignature
	$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
	$EmailSignature.ReplyMessageSignature = $TemplateName
	$MSWord.Quit()
}

Remove-Item $NewLocalFilename -Force # Delete the local template file copy
