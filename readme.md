#  Preparing the release of People.ai Screensaver

## Prerequisites

1. Install Packages toolkit for applications packaging - http://s.sudre.free.fr/Software/Packages/about.html
2. Add notarization keys to keychain

    > xcrun notarytool store-credentials "AC_PASSWORD" --apple-id "AC_USERNAME" --team-id <team_id> --password <secret_2FA_password>

    Where replace <team_id> with real Team ID and <secret_2FA_password> with real app password

## Build process

To build screensaver:
1. Run script
  > $  "./build.sh".

  It will build the app, installer package and sign the package for distributiion. The result of command execution is **People.ia.signed.zip** package, that can be notarized later.

## Notarization process

To notarize the screensaver:

1. Run script

  > $ "./notarize.sh".

  It may take up to 10 minutes.

2. To add staple (required for Gatekeeper to check the app with no Internet connection available), run the following script:

  > $ "./add_staple.sh"
