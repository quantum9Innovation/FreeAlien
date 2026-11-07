# FreeAlien on NixOS

[Back to the project overview](../README.md)

FreeAlien provides a reproducible package, flake apps, an overlay, and a NixOS
module. The module uses `TAG+="uaccess"` for the two lighting controllers, so
only the user at the active local seat receives access. It does not add users to
the `input` group or make HID devices world-writable.

## Install the NixOS module

Add the input and import its module in your system flake:

```nix
{
  inputs.freealien.url = "github:JafarAkhondali/FreeAlien";
  inputs.freealien.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, freealien, ... }: {
    nixosConfigurations.my-alienware = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        freealien.nixosModules.default
        {
          hardware.freealien.enable = true;
        }
      ];
    };
  };
}
```

Rebuild, then log out and back in once so logind refreshes the device ACLs:

```console
sudo nixos-rebuild switch --flake .#my-alienware
freealien status
freealien gui
```

The package can also be used without the module:

```console
nix run github:JafarAkhondali/FreeAlien -- --dry-run static red
nix run github:JafarAkhondali/FreeAlien#gui
```

Dry-run mode prints HID reports without opening either controller. Real hardware
commands require the module's udev rules or equivalent access.

## Declarative lighting profile

The optional user service applies a volatile profile at login. Per-key overrides
with the same colour are grouped into one controller transaction.

```nix
hardware.freealien = {
  enable = true;
  startupProfile = {
    enable = true;
    keyboard = {
      baseColor = "082040";
      keys = {
        W = "ff3000";
        A = "ff3000";
        S = "ff3000";
        D = "ff3000";
        ESC = "ffffff";
      };
    };
    touchpad = "0050ff";
    logo = "0050ff";
    chassisBrightness = 180;
  };
};
```

Run `freealien keys` for the measured ANSI key labels. Colours accept a known
name, `rrggbb`, `#rrggbb`, or `r,g,b`.

For a controller-side keyboard animation, set `keyboard.effect` to one of
`breathing`, `side_wave`, `double_wave`, `morph`, `bounce`, or `rainbow`.
`keyboard.secondaryColor` supplies the second colour for `double_wave` and
`morph`; `keyboard.tempo` accepts 0 through 255. Per-key overrides do not apply
while a hardware effect owns the LEDs.

Set `touchpad`, `logo`, or `chassisBrightness` to `null` to leave that setting
unchanged at login.

## Persistent firmware settings

The declarative startup profile intentionally performs only volatile writes.
Persistent settings stay explicit:

```console
freealien touchpad 0050ff --persist
freealien logo ffffff --persist
freealien power 0050ff ff8000
```

`--persist` writes the AW-ELC default animation slot. The power command writes
six firmware power-state profiles. Run these when changing stored settings, not
from a recurring login service.

Keyboard brightness is intentionally absent. The commonly cited
`cc 83 38 9c` command is not understood well enough and has left tested m16 R2
keyboard lighting blank until reboot.

## Overlay and custom package

The flake exports `overlays.default` and `packages.x86_64-linux.freealien`. A
module user can replace the package if needed:

```nix
hardware.freealien.package = freealien.packages.x86_64-linux.default;
```

## Development

```console
nix develop
nix flake check
nix build
nix fmt
```

`nix flake check` runs packet-level CLI smoke checks and the complete mocked test
suite with Qt's offscreen backend. It does not change lighting, cooling, system
services, or device permissions.
