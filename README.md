# BeyondTrust-RS-Scripts
PowerShell Scripts for working with BeyondTrust Remote Support.

## Remote Support authentication
Create a sub-directory in your script directory called "auth".
API information should be stored in JSON format in a file named "rs_api.json".
The scripts assume the following format:
```
{
    "baseURI":"https://remotesuporturl.domain.com",
    "ClientID":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Secret":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}
```