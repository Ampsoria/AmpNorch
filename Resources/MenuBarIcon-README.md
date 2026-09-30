# Custom menu bar icon

Place your artwork in `Resources/` before building:

- `AmpNotch_Menubar_icon.png`: full-color menu bar artwork, preserving the supplied colors. This takes priority over template icons.
- `MenuBarIconTemplate.pdf`: optional vector PDF; preferred when both PDF and PNG exist.
- `MenuBarIconTemplate.png`: PNG with transparent background, ideally 18 × 18 px.
- `MenuBarIconTemplate@2x.png`: optional Retina companion, ideally 36 × 36 px. Include the base PNG too.

For the `MenuBarIconTemplate` files, use a solid black silhouette on transparency, with a small amount of padding. The alpha channel determines the icon; macOS supplies its light/dark appearance because the image is a template. Color artwork is preserved only with `AmpNotch_Menubar_icon.png`.

The app fits the artwork inside 18 × 18 pt while preserving its aspect ratio. Until an icon is provided (or if it cannot be decoded), the existing waveform symbol remains in use. The build script copies only these optional assets before signing the app.

After adding or replacing an icon, rebuild and package:

```sh
bash scripts/build.sh
bash scripts/package_release.sh --skip-build
```

Restart the updated app to see the icon. Changing project Resources alone does not change an already installed app. Do not edit the signed app bundle directly.
