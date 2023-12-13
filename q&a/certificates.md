# Certificates

## How do I test my apps with SSL certificates?

### Use Let's Encrypt

Use these instructions to [setup certbot WSL](https://gist.github.com/bluearth/aebde23076e8a15981886a616cac81ba).
You can then generate wildcard certificates using this command:

```bash
sudo certbot certonly --manual --preferred-challenges dns -d *.youraddresshere.com
```

Convert them to pfx format:

```bash
sudo openssl pkcs12 -export -out "certificate.pfx" -inkey "privkey1.pem" -in "cert1.pem"
```

Example:

```bash
domainName="jannemattila.com"

sudo certbot certonly --manual --preferred-challenges dns -d "*.$domainName"
# Or register *unsafely* without email
sudo certbot certonly --manual --preferred-challenges dns -d "*.$domainName" --register-unsafely-without-email

# Deploy DNS TXT Record as instructed by certbot

# After successful cert creation you can convert it to .pfx
sudo openssl pkcs12 -export -out "certificate.pfx" -inkey "/etc/letsencrypt/live/$domainName/privkey.pem" -in "/etc/letsencrypt/live/$domainName/fullchain.pem"

# Enjoy your "certificate.pfx"!
```

### Use self-signed certificates

*Note:* If you have [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
installed you might already have `openssl` installed into your machine.

```bash
# Generate Certificate Authority (CA)
openssl req -x509 -sha256 -days 3650 -nodes -newkey rsa:2048 -subj "/CN=demos" -keyout ca.key -out ca.crt

# Create server Certificate Signing Request (CSR) configuration file
cat > server.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = mycustomdomain.internal

[ extensions ]
# extendedKeyUsage = 1.3.6.1.5.5.7.3.1
extendedKeyUsage = 1.3.6.1.5.5.7.3.1, serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = mycustomdomain.internal
EOF

# Generate server private key
openssl genrsa -out server.key 2048

# Generate Certificate Signing Request (CSR) using server private key and configuration file
openssl req -new -key server.key -out server.csr -config server.conf -extensions extensions
# Alternatives:
# -extensions extensions
# -addext "extendedKeyUsage = serverAuth"

# Generate certificate with self signed ca
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650 -sha256

# Convert to pfx
openssl pkcs12 -export -out server.pfx -inkey server.key -in server.crt -certfile ca.crt

# ----------------------------

# Create client Certificate Signing Request (CSR) configuration file
cat > client.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = 1234567890
EOF

# Generate client private key
openssl genrsa -out client.key 2048

# Generate Certificate Signing Request (CSR) using client private key and configuration file
openssl req -new -key client.key -out client.csr -config client.conf

# Generate certificate with self signed ca
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3650 -sha256

# Convert to pfx
openssl pkcs12 -export -out client.pfx -inkey client.key -in client.crt -certfile ca.crt
```

PowerShell examples:

```powershell
$certificate = New-SelfSignedCertificate -certstorelocation cert:\localmachine\my -dnsname "*.mycustomdomain.internal","*.scm.mycustomdomain.internal"

$certThumbprint = "cert:\localMachine\my\" + $certificate.Thumbprint
$password = ConvertTo-SecureString -String "your password here" -Force -AsPlainText

$fileName = "exportedcert.cer"
Export-Certificate -Cert $certThumbprint -FilePath server.cer -Type CERT
```

```powershell
$certificate = New-SelfSignedCertificate -certstorelocation cert:\localmachine\my -dnsname "mycustomdomain.internal"

$certThumbprint = "cert:\localMachine\my\" + $certificate.Thumbprint
$password = ConvertTo-SecureString -String "your password here" -Force -AsPlainText

Export-PfxCertificate -Cert $certThumbprint -FilePath server.pfx -Password $password
```

Here is example if you want to create certificate chain (based on [this](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/certauth)):

```powershell
# Create Root CA
$rootCA = New-SelfSignedCertificate `
  -Subject "Janne Root CA" `
  -FriendlyName "Janne Root CA" `
  -CertStoreLocation "cert:\LocalMachine\My" `
  -NotAfter (Get-Date).AddYears(20) `
  -KeyUsageProperty All -KeyUsage CertSign, CRLSign, DigitalSignature

$password = ConvertTo-SecureString -String "1234" -Force -AsPlainText

Get-ChildItem -Path cert:\localMachine\my\$($rootCA.Thumbprint) | 
  Export-PfxCertificate -FilePath JanneRootCA.pfx -Password $password

Export-Certificate -Cert cert:\localMachine\my\$($rootCA.Thumbprint) -FilePath JanneRootCA.crt

# Create Intermediate Certificate
$intermediateCertificate = New-SelfSignedCertificate `
  -CertStoreLocation cert:\localmachine\my `
  -Subject "Janne Intermediate certificate" `
  -FriendlyName "Janne Intermediate certificate" `
  -Signer $rootCA `
  -NotAfter (Get-Date).AddYears(20) `
  -KeyUsageProperty All -KeyUsage CertSign, CRLSign, DigitalSignature `
  -TextExtension @("2.5.29.19={text}CA=1&pathlength=1")

$intermediatePassword = ConvertTo-SecureString -String "2345" -Force -AsPlainText

Get-ChildItem -Path cert:\localMachine\my\$($intermediateCertificate.Thumbprint) | 
  Export-PfxCertificate -FilePath IntermediateCertificate.pfx -Password $intermediatePassword

Export-Certificate -Cert cert:\localMachine\my\$($intermediateCertificate.Thumbprint) -FilePath IntermediateCertificate.crt

# Create Server Certificate
$serverCertificate = New-SelfSignedCertificate `
  -CertStoreLocation cert:\localmachine\my `
  -DnsName "server.janne" `
  -FriendlyName "server.janne" `
  -Signer $intermediateCertificate `
  -NotAfter (Get-Date).AddYears(20)

$serverPassword = ConvertTo-SecureString -String "3456" -Force -AsPlainText

Get-ChildItem -Path cert:\localMachine\my\$($serverCertificate.Thumbprint) | 
  Export-PfxCertificate -FilePath Server.pfx -Password $serverPassword

Export-Certificate -Cert cert:\localMachine\my\$($serverCertificate.Thumbprint) -FilePath Server.crt
```

## Links

[Create a self-signed public certificate to authenticate your application](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-self-signed-certificate)

[Private client certificate](https://learn.microsoft.com/en-us/azure/app-service/environment/certificates#private-client-certificate)

[Custom domain suffix for App Service Environments](https://learn.microsoft.com/en-us/azure/app-service/environment/how-to-custom-domain-suffix)