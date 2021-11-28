# SKSEPlugins
An all-in-one directory for all my personal plugin projects

---
## Installation
Clone this repo onto your local environment, execute the command to update all the submodules.
```
git submodule update --init --force --recursive
```  
Set the following environment variables to correct value:
Env Variable | Value
--- | ---
`SkyrimSEPath` | Skyrim Special Edition full installation path on the local environment.
`SkyrimAEPath` | Skyrim Anniversary Edition full installation path on the local environment if there's any.
`CommonLibSSEPath` | [CommonLibSSE](https://github.com/Ryan-rsm-McKenzie/CommonLibSSE) full path to the local repo of the latest CommonLibSSE. Presumably `ThisRepoPath/Library/CommonLibSSE`.
`DKUtilPath` | [DKUtil](https://github.com/gottyduke/DKUtil) full path to the local repo of the latest DKUtil. Presumably `ThisRepoPath/Library/DKUtil`.
`VCPKG_ROOT` | [vcpkg](https://github.com/microsoft/vcpkg) full path on the local environment after it's built.

## Build
Execute the script `.\!Rebuild.ps1` to generate `CMakeLists.txt` for the entire solution.  
![MTD](https://github.com/gottyduke/PluginTutorialCN/blob/1579c5fa222e57bedce355835016fcd3405b4a91/images/MTD.png)  
By default this script generates `MultiThreadedDLL` configuration, use `MT` parameter to build `MultiThreaded` configuration.  
![MT](https://github.com/gottyduke/PluginTutorialCN/blob/1579c5fa222e57bedce355835016fcd3405b4a91/images/MT.png)   
The result solution file is located in the `/Build` folder.
