###########################################################################"
#
# NAME: Set-OutlookSignature.ps1
#
# AUTHOR: Jan Egil Ring
# Modifications by Darren Kattan
#
# COMMENT: Script to create an Outlook signature based on user information from Active Directory.
#          Adjust the variables in the "Custom variables"-section
#          Create an Outlook-signature from Microsoft Word (logo, fonts etc) and copy this signature to \\domain\NETLOGON\sig_files\$CompanyName\$CompanyName.docx
#		   This script supports the following keywords:
#		   	DisplayName
#			Title
#			Email
#          See the following blog-posts for more information:
#          http://blog.powershell.no/2010/01/09/outlook-signature-based-on-user-information-from-active-directory/
#          http://immense.net/deploying-unified-email-signature-template-outlook/
#          http://www.edugeek.net/blogs/thescarfedone/1016-centrally-managing-signatures-outlook-owa-free-way.html
#
#          Tested on Office 2003,2007 and 2010
#
# You have a royalty-free right to use, modify, reproduce, and
# distribute this script file in any way you find useful, provided that
# you agree that the creator, owner above has no warranty, obligations,
# or liability for such use.
#
# VERSION HISTORY:
# 1.0 09.01.2010 - Initial release
# 1.1 11.09.2010 - Modified by Darren Kattan
#	- Removed bookmarks. Now uses simple find and replace for DisplayName, Title, and Email.
#	- Email address is generated as a link
#	- Signature is generated from a single .docx file
#	- Removed version numbers for script to run. Script runs at boot up when it sees a change in the "Date Modified" property of your signature template.
# 1.11 11.15.2010 - Revised by Darren Kattan
#   - Fixed glitch with text signatures
#
#
###########################################################################"
#Custom variables
$CompanyName = 'NAME HERE'
$DomainName = 'DOMAIN HERE'
$SigSource = "\\$DomainName\netlogon\sig_files\$CompanyName"
$ForceSignatureNew = '1' #When the signature are forced the signature are enforced as default signature for new messages the next time the script runs. 0 = no force, 1 = force
$ForceSignatureReplyForward = '1' #When the signature are forced the signature are enforced as default signature for reply/forward messages the next time the script runs. 0 = no force, 1 = force
#Environment variables
$AppData=(Get-Item env:appdata).value
$SigPath = '\Microsoft\Signatures'
$LocalSignaturePath = $AppData+$SigPath
$RemoteSignaturePathFull = $SigSource+'\'+$CompanyName+'.docx'
#Get Active Directory information for current user
$UserName = $env:username
$Filter = "(&(objectCategory=User)(samAccountName=$UserName))"
$Searcher = New-Object System.DirectoryServices.DirectorySearcher
$Searcher.Filter = $Filter
$ADUserPath = $Searcher.FindOne()
$ADUser = $ADUserPath.GetDirectoryEntry()
$ADDisplayName = $ADUser.DisplayName
$ADEmailAddress = $ADUser.mail
$ADTitle = $ADUser.title
$ADTelePhoneNumber = $ADUser.TelephoneNumber
#Setting registry information for the current user
$CompanyRegPath = "HKCU:\Software\"+$CompanyName
if (Test-Path $CompanyRegPath)
{}
else
{New-Item -path "HKCU:\Software" -name $CompanyName}
if (Test-Path $CompanyRegPath'\Outlook Signature Settings')
{}
else
{New-Item -path $CompanyRegPath -name "Outlook Signature Settings"}
$SigVersion = (gci $RemoteSignaturePathFull).LastWriteTime  #When was the last time the signature was written
$ForcedSignatureNew = (Get-ItemProperty $CompanyRegPath'\Outlook Signature Settings').ForcedSignatureNew
$ForcedSignatureReplyForward = (Get-ItemProperty $CompanyRegPath'\Outlook Signature Settings').ForcedSignatureReplyForward
$SignatureVersion = (Get-ItemProperty $CompanyRegPath'\Outlook Signature Settings').SignatureVersion
Set-ItemProperty $CompanyRegPath'\Outlook Signature Settings' -name SignatureSourceFiles -Value $SigSource
$SignatureSourceFiles = (Get-ItemProperty $CompanyRegPath'\Outlook Signature Settings').SignatureSourceFiles
#Forcing signature for new messages if enabled
if ($ForcedSignatureNew -eq '1')
{
#Set company signature as default for New messages
$MSWord = New-Object -com word.application
$EmailOptions = $MSWord.EmailOptions
$EmailSignature = $EmailOptions.EmailSignature
$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
$EmailSignature.NewMessageSignature=$CompanyName
$MSWord.Quit()
}
#Forcing signature for reply/forward messages if enabled
if ($ForcedSignatureReplyForward -eq '1')
{
#Set company signature as default for Reply/Forward messages
$MSWord = New-Object -com word.application
$EmailOptions = $MSWord.EmailOptions
$EmailSignature = $EmailOptions.EmailSignature
$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
$EmailSignature.ReplyMessageSignature=$CompanyName
$MSWord.Quit()
}
#Copying signature sourcefiles and creating signature if signature-version are different from local version
if ($SignatureVersion -eq $SigVersion){}
else
{
	#Copy signature templates from domain to local Signature-folder
	Copy-Item "$SignatureSourceFiles\*" $LocalSignaturePath -Recurse -Force
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
	$fullPath = $LocalSignaturePath+'\'+$CompanyName+'.docx'
	$MSWord.Documents.Open($fullPath)
	$FindText = "DisplayName"
	$ReplaceText = $ADDisplayName.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord,	$MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap,	$Format, $ReplaceText, $ReplaceAll	)
	$FindText = "Title"
	$ReplaceText = $ADTitle.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord,	$MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap,	$Format, $ReplaceText, $ReplaceAll	)
	$FindText = "Telephone"
	$ReplaceText = $ADTitle.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord,	$MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap,	$Format, $ReplaceText, $ReplaceAll	)
	$FindText = "Fax"
	$ReplaceText = $ADTitle.ToString()
	$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord,	$MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap,	$Format, $ReplaceText, $ReplaceAll	)
	$MSWord.Selection.Find.Execute("Email")
	$MSWord.ActiveDocument.Hyperlinks.Add($MSWord.Selection.Range, "mailto:"+$ADEmailAddress.ToString(), $missing, $missing, $ADEmailAddress.ToString())
        # Select all in the document
        $objSelection = $objDoc.Range()
        # Save the signature to Outlook
	$EmailSignatureEntries.Add($CompanyName, $objSelection)
	$MSWord.Quit()
}
#Stamp registry-values for Outlook Signature Settings if they doesn`t match the initial script variables. Note that these will apply after the second script run when changes are made in the "Custom variables"-section.
if ($ForcedSignatureNew -eq $ForceSignatureNew){}
else
{Set-ItemProperty $CompanyRegPath'\Outlook Signature Settings' -name ForcedSignatureNew -Value $ForceSignatureNew}
if ($ForcedSignatureReplyForward -eq $ForceSignatureReplyForward){}
else
{Set-ItemProperty $CompanyRegPath'\Outlook Signature Settings' -name ForcedSignatureReplyForward -Value $ForceSignatureReplyForward}
if ($SignatureVersion -eq $SigVersion){}
else
{Set-ItemProperty $CompanyRegPath'\Outlook Signature Settings' -name SignatureVersion -Value $SigVersion}
