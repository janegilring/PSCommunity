 ###########################################################################"
 #
 # NAME: Set-OutlookSignature.ps1
 #
 # AUTHOR: Jan Egil Ring
 # Modifications by Darren Kattan
 # Modifications by Aksel Fjetland
 #
 # COMMENT: Script to create an Outlook signature based on user information from Active Directory.
 # Adjust the variables in the "Custom variables"-section
 #
 # Create an Outlook-signature from Microsoft Word (logo, fonts etc) and copy this signature to \\YOURDOMAIN\NETLOGON\YOURSIGNATUREDIR\
 #
 # This script supports the following keywords:
 # Name
 # Firstname
 # Middlename
 # Lastname
 # Intial
 # Title
 # Department
 # E-Mail
 # MobileNumber
 # TelephoneNumber
 # Description
 # TelephoneNumber
 # FaxNumber
 # Streetaddress
 # City
 # Postofficebox
 # ExtensionAttribute1
 # 
 # See the following blog-posts for more information: 
 # http://blog.crayon.no/blogs/janegil/archive/2010/01/09/outlook-signature-based-on-user-information-from-active-directory.aspx
 # http://blog.crayon.no/blogs/janegil/archive/2010/01/09/outlook-signature-based-on-user-information-from-active-directory.aspx
 # http://gallery.technet.microsoft.com/office/6f7eee4b-1f42-499e-ae59-1aceb26100de
 # http://www.experts-exchange.com/Software/Server_Software/Email_Servers/Exchange/Q_28035335.html
 # http://jamiemckillop.wordpress.com/category/powershell/
 # http://www.immense.net/deploying-unified-email-signature-template-outlook/
 #
 #
 # Tested on Office 2003, 2007, 2010, 2013 and 2016
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
 #	- Fixed glitch with text signatures
 # 1.2 07.06.2012 - Revised by Jamie McKillop
 #	- Modified script so that Force Signature settings are set on first run of script
 #	- Added variables to allow setting of default signature on creation of signature but not force the signature on each script run
 #	- Used variables defined in script for $ForceSignatureNew and $ForceSignatureReplyForward instead of pulling values from the registry
 # 1.3 01.13.2014 - Revised by Dominic Whyle
 #	- Modified script so Include logging
 #	- Added variables to allow setting of default signature address, telephone, fax and city
 #	- Modifed script to replace unused fields (Mobile or Description)
 #	- Added force script to run in x86mode for x86 versions of office
 # 1.4 01.16.2014 - Revised by Dominic Whyle
 #   - Added variable for AD account whenChanged to allow automatic updating of signauture when AD account changes 
 # 1.5 22.08.2016 - Revised by Aksel Fjetland
 #   - Added template functionality
 #   - Corrected the whenChanged functionality
 #   - Added more AD fields
 #   - Removed the log functionality, since I did'nt get it to work.
 #   - Made it possible to have several templates in same folder
 #	
 ###########################################################################"

#Run Script in x86 Mode
if ($env:Processor_Architecture -ne "x86")
{ write-warning 'Launching x86 PowerShell'
&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $myinvocation.Mycommand.path -executionpolicy bypass
exit
}
"Always running in 32bit PowerShell at this point."
$env:Processor_Architecture
[IntPtr]::Size
 
#Custom variables
 $CompanyName = 'NAME HERE'
 $TemplateName = 'TEMPLATE NAME HERE'
 $DomainName = 'DOMAIN HERE' 
 $ModulePath = '\\'+$DomainName+'\NETLOGON\YOURSIGNATUREDIR\' #insert log module path
 $SigSource = '\\'+$DomainName+'\NETLOGON\YOURSIGNATUREDIR\'
 $ForceSignatureNew = '1' #When the signature is forced it sets the default signature for new messages each time the script runs. 0 = no force, 1 = force
 $ForceSignatureReplyForward = '1' #When the signature is forced it sets the default signature for reply/forward messages each time the script runs. 0 = no force, 1 = force
 $SetSignatureNew = '0' #Determines wheter to set the signature as the default for new messages on first run. This is overridden if $ForceSignatureNew = 1. 0 = don't set, 1 = set
 $SetSignatureReplyForward = '0' #Determines wheter to set the signature as the default for reply/forward messages on first run. This is overridden if $ForceSignatureReplyForward = 1. 0 = don't set, 1 = set
 $DefaultAddress = 'My Company Address' #insert default address
 $DefaultPOBox = 'PO Box 666' #insert default PO Box
 $DefaultCity = 'Somewhere' #insert default city
 $DefaultTelephone = '123456' #insert default phone number
 $DefaultFax = '123456' #insert default fax number

# #Modules
#	New-PSDrive -Name O -PSProvider FileSystem -Root $ModulePath #Map the modules folder for PS to the O: drive
#. O:\LogData.ps1 #Add logging module

#Log data to the $LogInfo variable
#$LogInfo = '' #clear the log variable
#$NL = [Environment]::NewLine #new line variable for ease of use
#$Date = Get-Date
#$LogInfo = 'Signature Script - '+$Date
#$LogInfo += $NL+'Signature Source: '+$SigSource
 
 
#Environment variables
 $AppData=(Get-Item env:appdata).value
 $SigPath = "\Microsoft\Signaturer\"
 $LocalSignaturePath = $AppData+$SigPath
 $RemoteSignaturePathFull = $SigSource+"$TemplateName.docx"

#Get Active Directory information for current user
 $UserName = $env:username
 $Filter = "(&(objectCategory=User)(samAccountName=$UserName))"
 $Searcher = New-Object System.DirectoryServices.DirectorySearcher
 $Searcher.Filter = $Filter
 $ADUserPath = $Searcher.FindOne()
 $ADUser = $ADUserPath.GetDirectoryEntry()
 $ADDisplayName = $ADUser.DisplayName #Fullname
 $ADGivenName = $ADUser.givenName #Firstname
 $ADOtherName = $ADUser.middleName #Middle Name
 $ADSurname = $ADUser.sn #Lastname
 $ADInitials = $ADUser.initials #First letter of first name
 $ADTitle = $ADUser.title #Title
 $ADDepartment = $ADUser.Department #Department
 $ADTelePhoneNumber = $ADUser.TelephoneNumber #Telephone 
 $ADEmailAddress = $ADUser.mail #E-Mail
 $ADMobile = $ADUser.mobile #MobileNumber
 $ADFax = $ADUser.facsimileTelephoneNumber #FaxNumber
 $ADStreetAddress = $ADUser.streetaddress #Adress
 $ADCity = $ADUser.l #City
 $ADPOBox = $ADUser.postofficebox #Postbox
 $ADCustomAttribute1 = $ADUser.extensionAttribute1  #designations in Exchange custom attribute 1
 $ADModify = $ADUser.whenChanged
 
#Setting registry information for the current user
 $CompanyRegPath = "HKCU:\Software\"+$CompanyName
 $SignatureRegPath = $CompanyRegPath+'\'+$TemplateName
 
if (Test-Path $CompanyRegPath)
 {}
 else
 {New-Item -path "HKCU:\Software\" -name $CompanyName}

if (Test-Path $SignatureRegPath)
 {}
else
 {New-Item -path $CompanyRegPath -name $TemplateName}

$SigVersion = (gci $RemoteSignaturePathFull).LastWriteTime #When was the last time the signature was written
$SignatureVersion = (Get-ItemProperty $CompanyRegPath"\$TemplateName").SignatureVersion

$UserModify = (Get-ItemProperty $SignatureRegPath).UserAccountModifyDate
 
$ForcedSignatureNew = (Get-ItemProperty $CompanyRegPath"\$TemplateName").ForcedSignatureNew
$ForcedSignatureReplyForward = (Get-ItemProperty $CompanyRegPath"\$TemplateName").ForcedSignatureReplyForward
 
Set-ItemProperty $CompanyRegPath"\$TemplateName" -name SignatureSourceFiles -Value $SigSource
$SignatureSourceFiles = (Get-ItemProperty $CompanyRegPath"\$TemplateName").SignatureSourceFiles



#Copying signature sourcefiles and creating signature if signature-version are different from local version
if (($SignatureVersion -eq $SigVersion) -and ($UserModify -eq $ADModify)){}
 else
 {
 #Copy signature templates from domain to local Signature-folder
 Copy-Item "$RemoteSignaturePathFull" $LocalSignaturePath -Recurse -Force

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
 $fullPath = $LocalSignaturePath+"$TemplateName"+’.docx’
$MSWord.Documents.Open($fullPath)

$FindText = "Name"
$ReplaceText = $ADDisplayName.ToString()
 $MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll )

$FindText = "Firstname"
$ReplaceText =  $ADGivenName.ToString()
 $MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll )

  $FindText = "Middlename"
$ReplaceText = $ADUser.middleName.ToString()
 $MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll )
 
   $FindText = "Lastname"
$ReplaceText = $ADSurname.ToString()
 $MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll )

 $FindText = "Intial"
$ReplaceText = $ADInitials.ToString()
 $MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll )
 
 $FindText = "Title"
$ReplaceText = $ADTitle.ToString()
 $MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll )


If ($ADMobile -ne "") { 
    $FindText = "Mobile"
	$ReplaceText = $ADMobile.ToString()
   }
Else {
$FindText = "M  +47 Mobile^l"
$ReplaceText = "" 
	}
$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord,    $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap,    $Format, $ReplaceText, $ReplaceAll    ) 

$FindText = "Department"
$ReplaceText = $ADDepartment.ToString()
$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord, $MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap, $Format, $ReplaceText, $ReplaceAll )

$FindText = "Email"
$ReplaceText = $ADEmailAddress.ToString()
$MSWord.Selection.Find.Execute($FindText, $MatchCase, $MatchWholeWord,	$MatchWildcards, $MatchSoundsLike, $MatchAllWordForms, $Forward, $Wrap,	$Format, $ReplaceText, $ReplaceAll	)
if ($MSWord.Selection.Find.Execute($ReplaceText.ToString())) {
    $MSWord.ActiveDocument.Hyperlinks.Add($MSWord.Selection.Range, "mailto:"+$ReplaceText.ToString(), $missing, $missing, $ReplaceText.ToString())
	$hyperlinks = $MSWord.ActiveDocument.Hyperlinks.item(1)
#	$hyperlinks.Range.Font.Color = "wdColorBlack"
	$hyperlinks.Range.Font.Underline = "0"
  }


$MSWord.ActiveDocument.Save()
 $saveFormat = [Enum]::Parse([Microsoft.Office.Interop.Word.WdSaveFormat], "wdFormatHTML");
 [ref]$BrowserLevel = "microsoft.office.interop.word.WdBrowserLevel" -as [type]

$MSWord.ActiveDocument.WebOptions.OrganizeInFolder = $true
 $MSWord.ActiveDocument.WebOptions.UseLongFileNames = $true
 $MSWord.ActiveDocument.WebOptions.BrowserLevel = $BrowserLevel::wdBrowserLevelMicrosoftInternetExplorer6
 $path = $LocalSignaturePath+"$TemplateName.htm"
$MSWord.ActiveDocument.saveas([ref]$path, [ref]$saveFormat)

$saveFormat = [Enum]::Parse([Microsoft.Office.Interop.Word.WdSaveFormat], "wdFormatRTF");
 $path = $LocalSignaturePath+"$TemplateName.rtf"
$MSWord.ActiveDocument.SaveAs([ref] $path, [ref]$saveFormat)


$saveFormat = [Enum]::Parse([Microsoft.Office.Interop.Word.WdSaveFormat], "wdFormatText");
 $path = $LocalSignaturePath+"$TemplateName.txt"
$MSWord.ActiveDocument.SaveAs([ref] $path, [ref]$saveFormat)
 $MSWord.ActiveDocument.Close()

$MSWord.Quit()

	#Set signature for new mesages if enabled
	if ($SetSignatureNew -eq '1') {
		#Set company signature as default for New messages
		$MSWord = New-Object -com word.application
		$EmailOptions = $MSWord.EmailOptions
		$EmailSignature = $EmailOptions.EmailSignature
		$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
		$EmailSignature.NewMessageSignature=$TemplateName
		$MSWord.Quit()
	}
	
	#Set signature for reply/forward messages if enabled
	if ($SetSignatureReplyForward -eq '1') {
		#Set company signature as default for Reply/Forward messages
		$MSWord = New-Object -com word.application
		$EmailOptions = $MSWord.EmailOptions
		$EmailSignature = $EmailOptions.EmailSignature
		$EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
		$EmailSignature.ReplyMessageSignature=$TemplateName
		$MSWord.Quit()
	}

}

Set-ItemProperty $SignatureRegPath -name UserAccountModifyDate -Value $ADModify.ToString()

#Stamp registry-values for Outlook Signature Settings if they doesn`t match the initial script variables. Note that these will apply after the second script run when changes are made in the "Custom variables"-section.
 if ($ForcedSignatureNew -eq $ForceSignatureNew){}
 else
 {Set-ItemProperty $CompanyRegPath"\$TemplateName" -name ForcedSignatureNew -Value $ForceSignatureNew}

if ($ForcedSignatureReplyForward -eq $ForceSignatureReplyForward){}
 else
 {Set-ItemProperty $CompanyRegPath"\$TemplateName" -name ForcedSignatureReplyForward -Value $ForceSignatureReplyForward}

if ($SignatureVersion -eq $SigVersion){}
 else
 {Set-ItemProperty $CompanyRegPath"\$TemplateName" -name SignatureVersion -Value $SigVersion}

 #Forcing signature for new messages if enabled
 if ($ForcedSignatureNew -eq ‘1’)
 {
 #Set company signature as default for New messages
 $MSWord = New-Object -com word.application
 $EmailOptions = $MSWord.EmailOptions
 $EmailSignature = $EmailOptions.EmailSignature
 $EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
 $EmailSignature.NewMessageSignature=$TemplateName
 $MSWord.Quit()
 }

#Forcing signature for reply/forward messages if enabled
 if ($ForcedSignatureReplyForward -eq ‘1’)
 {
 #Set company signature as default for Reply/Forward messages
 $MSWord = New-Object -com word.application
 $EmailOptions = $MSWord.EmailOptions
 $EmailSignature = $EmailOptions.EmailSignature
 $EmailSignatureEntries = $EmailSignature.EmailSignatureEntries
 $EmailSignature.ReplyMessageSignature=$TemplateName
 $MSWord.Quit()
 }
 
#All you do is create a single template.docx file in your \\YOURDOMAIN\NETLOGON\YOURSIGNATUREDIR\ directory