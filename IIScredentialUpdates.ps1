<# 
Author: Gregory Grskovich
Date: May 19, 2023
Version: 1.0
Description:    This scrpit is designed to update the app pool identity credentials, site (root web application), child web application, and child virtual directory 'connect as' credentials
                that match the username provided by the user via get-credential.  The script approaches the operation in a "xml-rewrite" approach where changes to applicationhost.config
                are set and then the xml file is rewritten.  IISReset is executed at the end, but can be commented out if desired.
#>
# Prompt for user credentials
$credentials = Get-Credential

# Specify the path to the applicationHost.config file
$configFilePath = "C:\Windows\System32\inetsrv\config\applicationHost.config"

# Load the applicationHost.config file as an XML document
$configXml = [xml](Get-Content -Path $configFilePath)

# Update the "Connect As" credentials for parent applications and their application pools
$sites = $configXml.SelectNodes("//configuration/system.applicationHost/sites/site")
foreach ($site in $sites) {
    $siteName = $site.GetAttribute("name")

    $parentApps = $site.SelectNodes("./application[@path='/' or @path='']")

    foreach ($parent in $parentApps) {
        $parentPath = $parent.GetAttribute("path")

        # Filter based on supplied username
        if ($parent.SelectSingleNode("virtualDirectory").GetAttribute("userName") -eq $credentials.UserName) {
            $parent.SelectSingleNode("virtualDirectory").SetAttribute("userName", $credentials.UserName)
            $parent.SelectSingleNode("virtualDirectory").SetAttribute("password", $credentials.GetNetworkCredential().Password)

            $appPoolName = $parent.GetAttribute("applicationPool")
            $appPool = $configXml.SelectSingleNode("//configuration/system.applicationHost/applicationPools/add[@name='$appPoolName']")
            $appPool.processModel.SetAttribute("userName", $credentials.UserName)
            $appPool.processModel.SetAttribute("password", $credentials.GetNetworkCredential().Password)
        }
    }

    # Update the "Connect As" credentials for child applications and virtual directories
    $childApps = $site.SelectNodes("./application[@path!='' and @path!='/']")

    foreach ($child in $childApps) {
        $childPath = $child.GetAttribute("path")

        # Filter based on supplied username
        if ($child.SelectSingleNode("virtualDirectory").GetAttribute("userName") -eq $credentials.UserName) {
            $child.SelectSingleNode("virtualDirectory").SetAttribute("userName", $credentials.UserName)
            $child.SelectSingleNode("virtualDirectory").SetAttribute("password", $credentials.GetNetworkCredential().Password)

            $appPoolName = $child.GetAttribute("applicationPool")
            $appPool = $configXml.SelectSingleNode("//configuration/system.applicationHost/applicationPools/add[@name='$appPoolName']")
            $appPool.processModel.SetAttribute("userName", $credentials.UserName)
            $appPool.processModel.SetAttribute("password", $credentials.GetNetworkCredential().Password)
        }
    }
}

# Save the modified applicationHost.config file
$configXml.Save($configFilePath)

# Restart IIS
iisreset
