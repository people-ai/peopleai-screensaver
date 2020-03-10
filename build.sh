# build
xcodebuild -project Slides.xcodeproj -scheme "Slides" -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" clean
xcodebuild -project Slides.xcodeproj -scheme "Slides" -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" build
xcodebuild -project Slides.xcodeproj -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" archive -archivePath "Build/Slides"
xcodebuild -project Slides.xcodeproj -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" archive -exportArchive -exportOptionsPlist "exportOptions.plist"

# package
packagesbuild -v "Slides.pkgproj"

# sign package
/usr/bin/productsign --timestamp --sign "Developer ID Installer: People.ai, Inc (B865KYJU5B)" "Build/Slides.pkg" "Build/Slides_signed.pkg"

# create zip
zip "Build/Slides_signed.zip" "Build/Slides_signed.pkg"
