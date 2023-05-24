# Certificates

## How do I test my apps with SSL certificates?

### Option 1: Let's Encrypt

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

### Option 2: SSL For Free

You can use [SSL For Free](https://www.sslforfree.com/) for creating your certificates.
You can create even wildcard certificates (e.g. `*.yourdomainnamehere.com`) with that.
Just follow the website instructions and you're good to go.

After the process you can download those generated certificates to your machine.
That downloaded bundle contains following files:

```bash
ca_bundle.crt
certificate.crt
private.key
```

In order to use them e.g. with Azure API Management for custom domains
you need to convert them to `pfx` file. You can use `openssl`
for the conversion.

*Note:* If you have [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
installed you might already have `openssl` installed into your machine.

```bash
openssl pkcs12 -export -out "certificate.pfx" -inkey "private.key" -in "certificate.crt" -certfile "ca_bundle.crt"
```
