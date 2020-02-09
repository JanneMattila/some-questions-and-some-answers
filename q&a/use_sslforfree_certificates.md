# SSL for Free

## How do I test my apps with SSL certificates?

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
