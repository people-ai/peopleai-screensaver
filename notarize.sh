# Notarization
#
#  Created by People.ai on 1/21/20.
#  Copyright © 2020 People.ai, Inc. All rights reserved.
#

xcrun altool --notarize-app --primary-bundle-id "ai.people.screensaver" --username "[APPLE ID]" --password "[APP PASSWORD]" --asc-provider "B865KYJU5B" --file "Build/People.ai.signed.zip"
