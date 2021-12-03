# SKSEPlugins
General template for setting up SKSE64 development environment.  

---
## Installation
Clone this repo onto your local environment, execute the command in `PowerShell` **with admin privilege**:  
```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\!Rebuild BOOTSTRAP
```  

## Build
```
.\!Rebuild [MT|MD] [AE|SE] [CustomCLib:0]
```

## CLib
`!Rebuild` builds against [default CommonLib](https://github.com/Ryan-rsm-McKenzie/CommonLibSSE). To use a custom CommonLib, prepare it in the `BOOTSTRAP` process and make sure it has proper `CMakeLists` setup. When using custom CommonLib, append numeric parameter `0` to the `!Rebuild` command.  
> When using custom CommonLib, `!Rebuild` presumes it's for current build target (`AE|SE`)

---
---

# SKSEPlugins
用于设立SKSE64插件项目开发环境的模板项目.   

---
## 安装
下载或`git clone`到本地工作环境, 以**管理员权限**打开`PowerShell`运行以下命令:  
```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\!Rebuild BOOTSTRAP
```  

## 生成
```
.\!Rebuild [MT|MD] [AE|SE] [自定义CLib库:0]
```

## CLib
`!Rebuild`命令生成时使用[默认CommonLib](https://github.com/Ryan-rsm-McKenzie/CommonLibSSE). 若要使用自定义CommonLib, 在`BOOTSTRAP`步骤中设置合适的自定义CommonLib环境并在`!Rebuild`命令后附加数字参数`0`以启用自定义CommonLib. 
> 使用自定义CommonLib时, `!Rebuild`命令默认该自定义CommonLib符合当前编译目标(`AE`或`SE`)


---
<p style="text-align: center;">Author: Dropkicker & Maxsu @ 2021</p>