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


## Build
Execute the command `.\!Rebuild MT AE` to generate solution for `Anniversary Edition` with `MultiThreaded` config.  
The result solution file is located in the `Build` folder.

### PostBuild Event
The postbuild event will attempt to copy the product binary file to MO2 directory, which is expected to be in the game root folder with the name `MO2`.
```
SkyrimSEPath | SkyrimAEPath
    Data
    MO2
        downloads
        mods
        override
        profiles
        webcache

    skse64_loader.exe
    SkyrimSE.exe
```
