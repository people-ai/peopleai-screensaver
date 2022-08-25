# build
xcodebuild -project People.ai.xcodeproj -scheme "People.ai" -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" clean
xcodebuild -project People.ai.xcodeproj -scheme "People.ai" -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" build -xcconfig build.xcconfig
xcodebuild -project People.ai.xcodeproj -scheme "People.ai" -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" archive -archivePath "Build/People.ai.xcarchive"
#xcodebuild -project People.ai.xcodeproj -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" -UseModernBuildSystem=NO -exportArchive -archivePath "Build/People.ai.xcarchive"  -exportOptionsPlist "exportOptions.plist"

# package
packagesbuild -v "People.ai.pkgproj"

# sign package
/usr/bin/productsign --timestamp --sign "Developer ID Installer: People.ai, Inc (B865KYJU5B)" "Build/People.ai.pkg" "Build/People.ai.signed.pkg"

# create zip
zip "Build/People.ai.signed.zip" "Build/People.ai.signed.pkg"
