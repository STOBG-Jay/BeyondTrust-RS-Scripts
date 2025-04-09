# BeyondTrust-RS-Scripts
PowerShell Scripts for working with BeyondTrust Remote Support.

## Remote Support API Authentication
Create a sub-directory in your script directory called "auth". This directory is in .gitignore by default.

API information should be stored in JSON format in a file named "rs_api.json".

The scripts assume the following format:
```json
{
    "baseURI":"https://remotesupporturl.domain.com",
    "ClientID":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Secret":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}
```
