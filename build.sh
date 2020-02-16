# build
xcodebuild -project Slides.xcodeproj -scheme "Slides" -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" clean
xcodebuild -project Slides.xcodeproj -scheme "Slides" -configuration Release "CODE_SIGN_IDENTITY=Developer ID Application: People.ai, Inc (B865KYJU5B)" build

# package
packagesbuild -v "Slides.pkgproj"

# sign package
/usr/bin/productsign --sign "People.ai, Inc (B865KYJU5B)" "Build/Slides.pkg" "Build/Slides_signed.pkg"
