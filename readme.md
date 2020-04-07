#  Preparing the release of People.ai Screensaver

## Build

To build screensaver:
1. Run script
  > $  "./build.sh".

  It will build the app, installer package and sign the package for distributiion. The result of command execution is **People.ia.signed.zip** package, that can be notarized later.

## Notarisation

To notarize the screensaver:
1. In script **"notarize.sh"** replace:
 **[APPLE ID]** with AppleId that should be used for notarisation.  
 **[APP PASSWORD]** with App Password created for notarization (go to AppleId home page -> Security -> App password -> Create New).

 --asc-provider, if need to change, should be replaced with other ITC provider id.

2. Run script

  > $ "./notarize.sh".

  It may take up to 10 minutes.

3. To add staple (required for Gatekeeper to check the app with no Internet connection available), run the following script:

  > $ "./add_staple.sh"

  The result of command execution is an email from Apple about successful notarization process.

  You can check notarization status using RequestId, received after running **"./notarize.sh"** command:

  > $ "xcrun altool --notarization-info [REQUEST ID] -u [APPLE ID] -p [APP PASSWORD] --output-format xml"

  where **[REQUEST ID]** should be replaced with real request id, **[APPLE ID]** with AppleId of person who sent app for notarization and **[APP PASSWORD]** with app password created for notarization purposes.
