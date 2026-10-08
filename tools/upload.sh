#!/usr/bin/env bash
# Archiviert Rapt und lädt es nach App Store Connect hoch – ersetzt in Xcode
# „Product → Archive → Distribute App → App Store Connect → Upload“.
#
# Aufruf (im Repo-Ordner):
#   tools/upload.sh            iOS und macOS
#   tools/upload.sh ios        nur iOS
#   tools/upload.sh mac        nur macOS
#   tools/upload.sh --bump     vorher die Build-Nummer in project.yml um 1 erhöhen (geht mit jeder Plattform)
#
# Anmeldung: Standardmäßig über den in Xcode angemeldeten Apple-Account (Xcode → Settings → Accounts).
# Alternativ mit App-Store-Connect-API-Schlüssel, dann vorher setzen:
#   export ASC_KEY_PATH=~/keys/AuthKey_XXXXXXXXXX.p8 ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-...
set -euo pipefail
cd "$(dirname "$0")/.."

platforms=(ios mac)
bump=false
for arg in "$@"; do
    case "$arg" in
        ios) platforms=(ios) ;;
        mac|macos) platforms=(mac) ;;
        beide|both) platforms=(ios mac) ;;
        --bump) bump=true ;;
        *) echo "Unbekannte Angabe: $arg (erlaubt: ios, mac, beide, --bump)"; exit 1 ;;
    esac
done

if $bump; then
    current=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([0-9]*\)".*/\1/p' project.yml)
    next=$((current + 1))
    perl -pi -e "s/CURRENT_PROJECT_VERSION: \"$current\"/CURRENT_PROJECT_VERSION: \"$next\"/" project.yml
    echo "Build-Nummer: $current → $next (project.yml; bitte committen)"
fi

version=$(sed -n 's/.*MARKETING_VERSION: "\([^"]*\)".*/\1/p' project.yml)
build=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([0-9]*\)".*/\1/p' project.yml)
echo "Rapt $version ($build)"

xcodegen generate

out=build/upload
rm -rf "$out"
mkdir -p "$out"

# Exportoptionen: App Store Connect, direkt hochladen, automatische Signierung
cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>9H7F5NMT97</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

auth=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
    auth+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

for platform in "${platforms[@]}"; do
    case "$platform" in
        ios) destination="generic/platform=iOS" ;;
        mac) destination="generic/platform=macOS" ;;
    esac
    archive="$out/Rapt-$platform.xcarchive"
    echo "▶ Archiviere $platform …"
    xcodebuild archive \
        -project Rapt.xcodeproj \
        -scheme Rapt \
        -configuration Release \
        -destination "$destination" \
        -archivePath "$archive" \
        "${auth[@]}" \
        -quiet
    echo "▶ Lade $platform zu App Store Connect hoch …"
    xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportOptionsPlist "$out/ExportOptions.plist" \
        -exportPath "$out/export-$platform" \
        "${auth[@]}"
    echo "✓ $platform hochgeladen ($version, Build $build)"
done

echo "Fertig. Die Builds erscheinen nach der Verarbeitung (meist 5–30 Minuten) in App Store Connect."
