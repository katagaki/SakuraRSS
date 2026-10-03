# Fediverse icon

Source: [Fediverse logo by Eukombos](https://commons.wikimedia.org/wiki/File:Fediverse_logo_proposal.svg), CC0 1.0.

`Fediverse.icon` retains the original symbol geometry and colors in separate Liquid Glass layers. Open it in Icon Composer to edit it.

Export the bundled 512-pixel images with Apple's renderer:

```sh
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Assets/Fediverse.icon --export-image --output-file Hanami/Assets.xcassets/FediverseIcon.imageset/Fediverse-Light.png --platform iOS --rendition Default --width 512 --height 512 --scale 1
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Assets/Fediverse.icon --export-image --output-file Hanami/Assets.xcassets/FediverseIcon.imageset/Fediverse-Dark.png --platform iOS --rendition Dark --width 512 --height 512 --scale 1
```
