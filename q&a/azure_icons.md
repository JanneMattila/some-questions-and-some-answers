# Azure Icons

Download Azure [SVGs](https://learn.microsoft.com/en-us/azure/architecture/icons/).

To convert svg images to png use following commands:

```bash
sudo apt install -y librsvg2-bin # Install rsvg-convert

# Go to correct folder
cd Azure_Public_Service_Icons/Icons

# Convert SVGs
tree -fialx --noreport | grep .svg | while read input_file ; do
  output_file=${input_file//.svg/.png}
  rsvg-convert "$input_file" -o "$output_file" --zoom 5
done
```
