# Assumption 1: data is spread over several logs, but they all have a text in common in the name.
# Assumption 2: We are not interested in historical changes
# Assumption 3: There are no changes in mnemonic lists
# Assumption 4: IF several logs have data in the last <period> of time, we are interested only in the last one changed.
# Assumption 5: We are only interested in time data (This script can easily be expanded to handle depth as well)
# Assumption 6: We are ok with small delay: Powershell is not the fastest language, and we are writing to disk several time.
# Assumption 7: The logs do not contain array data.


$uidWell = "" #Recommended
$uidWellbore = "" #Recommended
$logName = "_Time" #Required
$period = 30 #Required. The Frequency should be half this number (yes .. we would need to clean duplicates)

$currentTime = Get-Date
$startTime = $currentTime.addMinutes((-1 * $period))
$logPattern = ".*" + $logName + ".*"

$wsdlLocation=  (get-location).path + "\..\WMLS.wsdl"; #If this script is not running for you, check this line!!

$svc = New-WebServiceProxy -Uri $wsdlLocation  #Where you have stored your store.wsdl

#KDI might have an demo server you can use
$svc.URL = "https://MY_STORE_ENDPOINT/store/witsml" #URL for your store

#Apparently you can encrypt credentials. Have not tried it: https://www.pdq.com/blog/secure-password-with-powershell-encrypting-credentials-part-1/
$credentials = Get-Credential #A dialog will open and ask for Store user/password
$svc.Credentials = $credentials

#We should narrow it down to specific mnemonics, it would make the solution more stable as we could guarantee we will not encounter arrays
$logHeaderQuery = [xml] @"
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<logs version="1.4.1.1" xmlns="http://www.witsml.org/schemas/1series">
  <log uidWell="" uidWellbore="" uid="">
    <nameWell />
    <nameWellbore />
    <name /> 
    <indexType>date time</indexType> 
    <startDateTimeIndex></startDateTimeIndex> 
    <endDateTimeIndex></endDateTimeIndex> 
    <commonData>
    <dTimLastChange />
  </commonData>
  </log>
</logs>
"@
 
$logHeaderQuery.logs.log.uidWell = $uidWell
$logHeaderQuery.logs.log.uidWellbore = $uidWellbore
$logHeaderQuery.logs.log.startDateTimeIndex = $startTime.toString("yyyy-MM-ddTHH:MMK")

$outXml = ""
$msgOut = ""
$svc.WMLS_GetFromStore("log", $logHeaderQuery.OuterXml, "", "", [ref] $outXml, [ref] $msgOut);
$outXml = [xml]$outXml
$potensials = $outXml.logs.log | foreach-Object { if ($_.name -match $logPattern) { $_ } }

$lastChangedLog = $potensials | Sort-Object -Property commonData.DTimLastChange | Select-Object -last 1  #Not sure if powershell sorts by date or by String

$logDataQuery = [xml] @"
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<logs version="1.4.1.1" 
    xmlns="http://www.witsml.org/schemas/1series">
    <log uidWell="" uidWellbore="" uid="">
        <nameWell />
        <nameWellbore />
        <name />
        <indexType>date time</indexType>
        <startDateTimeIndex></startDateTimeIndex>
        <endDateTimeIndex></endDateTimeIndex> 
        <logData>
            <mnemonicList />
            <unitList />
            <data />
        </logData>
        <commonData>
            <dTimLastChange />
        </commonData>
    </log>
</logs>
"@

$logDataQuery.logs.log.uid = $lastChangedLog.uid;
$logDataQuery.logs.log.uidWell = $lastChangedLog.uidWell;
$logDataQuery.logs.log.uidWellbore = $lastChangedLog.uidWellbore;
$logDataQuery.logs.log.startDateTimeIndex =  $startTime.toString("yyyy-MM-ddTHH:MMK")

$rawXml = ""
$msgOut = ""
$svc.WMLS_GetFromStore("log", $logDataQuery.OuterXml, "", "", [ref] $rawXml, [ref] $msgOut);

$rawXml= [xml] $rawXml
$fileName = "data_" + $rawXml.logs.log.name; 
 
$fileName = $fileName -replace '[~#%&*{}|:<>?/|"]', '_' ;
$fileName = $fileName + ".csv";

#The location of the csv path
$fileName = (get-location).path+"\" + $fileName; #You might have to adjust this PATH!!!

$isAlredyCreated = Test-Path $fileName -PathType Leaf
	
#$ns=@{dns='http://www.witsml.org/schemas/1series'}
#$pattern ="//dns:logCurveInfo[dns:columnIndex='"+$log.indexCurve.columnIndex+"']"
if($isAlredyCreated -eq $false){
    $rawXml.logs.log.logData.mnemonicList | out-file -FilePath  $fileName -Encoding "UTF8";
    $rawXml.logs.log.logData.unitList | out-file -append -FilePath  $fileName -Encoding "UTF8";
}


$data = $rawXml.logs.log.logData.data
$data | Out-File -append -FilePath  $fileName -Encoding "UTF8";

#cleaning duplicates - this will significantly slow the system if the file is big. Add the date to filename to rotate per day
$csvData = import-csv $fileName 
$csvData = $csvData | Sort-Object time -Unique
$csvData| Export-csv  -Path $fileName  -NoTypeInformation -Encoding "UTF8"
