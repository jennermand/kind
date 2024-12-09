# Check if the script is running with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  # Restart the script with elevated privileges
  $arguments = "& '" + $myInvocation.MyCommand.Definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  exit
}

# Define the certificate parameters
$certName = "CN=kind-ca"
$certPath = ".\data\certs\ca.crt"
$keyPath = ".\data\certs\ca.key"
$certPassword = ConvertTo-SecureString -String "YourPassword" -Force -AsPlainText
$certPathPfx = ".\data\certs\ca.pfx"

# Create a self-signed certificate
$cert = New-SelfSignedCertificate -DnsName "kind-ca" -CertStoreLocation "Cert:\LocalMachine\My"

# Export the certificate to a .crt file
Export-Certificate -Cert $cert -FilePath $certPath

# Export the private key to a .pfx file
Export-PfxCertificate -Cert $cert -FilePath $certPathPfx -Password $certPassword

# Convert the PFX file to PEM format (requires OpenSSL)
# openssl pkcs12 -in $certPathPfx -nocerts -out $keyPath -nodes

# Check if the PFX file was created successfully
if (Test-Path $certPathPfx) {
  Write-Host "PFX file created successfully at $certPathPfx"
}
else {
  Write-Host "Failed to create PFX file at $certPathPfx" -ForegroundColor Red
}

Pause