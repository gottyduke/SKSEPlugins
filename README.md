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
After cloning onto the working directory, execute bootstrap to initialize all toolchain and dependency setup.
```
.\Rebuild BOOTSTRAP FORCE
```

To generate solution for `Anniversary Edition` with `MultiThreaded` config:    
```
.\!Rebuild MT AE
``` 
The result solution file is located in the `Build` folder.
