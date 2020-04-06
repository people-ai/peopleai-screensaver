#  Preparing the release of People.ai Screensaver

## Build

To build screensaver:
1. Run script
  > $  "./build.sh".

  It will build app, build installer package and sign it and produce **People.ia.signed.zip** package, that later can be send to notarisation.

## Notarisation

To notarise screensaver:
1. In script **"notarize.sh"** replace:
 **[APPLE ID]** with AppleId that should be used for notarisation.  
 **[APP PASSWORD]** with App Password created for notarisation (go to AppleId home page -> Security -> App password -> Create New).

 --asc-provider, if need to change, should be replaced with other ITC provider id.

2. Run script
  > $ "./notarize.sh".

  It may take up 10 minutes.

3. To add staple (needed for Gatekeeper to check app if no internet connection is available) run script

  > $ "./add_staple.sh"

  after message about successful notarisation received by email.

To check notarisation status:

  Also you can check status of notarisation using RequestId, received after running **"./notarize.sh"**:

  > $ "xcrun altool --notarization-info [REQUEST ID] -u [APPLE ID] -p [APP PASSWORD] --output-format xml"

  where **[REQUEST ID]** should be replaced with real request id, **[APPLE ID]** with AppleId of person who sent app to notarisation and **[APP PASSWORD]** with app password created to this purpose.
