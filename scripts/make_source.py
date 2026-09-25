"""SideStore / AltStore source for the latest build.

usage: make_source.py <owner/repo> <version> <build> <ipa size in bytes>
"""
import datetime
import json
import sys

repo, version, build, size = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
base = f"https://github.com/{repo}"

source = {
    "name": "Cat Worker",
    "identifier": "com.kolot.catworker.source",
    "sourceURL": f"{base}/releases/download/source/source.json",
    "iconURL": f"https://raw.githubusercontent.com/{repo}/main/CatWorker/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    "tintColor": "FF5A3C",
    "apps": [
        {
            "name": "Cat Worker",
            "bundleIdentifier": "com.kolot.catworker",
            "developerName": "KOLOT",
            "subtitle": "Доска задач, боты и их экраны",
            "localizedDescription": "Канбан задач с серверов «Котик Клайла» и «Котик Колот», роли-боты с переходом в их чаты ChatGPT и живые рабочие столы ботов.",
            "iconURL": f"https://raw.githubusercontent.com/{repo}/main/CatWorker/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
            "tintColor": "FF5A3C",
            "appPermissions": {"entitlements": [], "privacy": {}},
            "versions": [
                {
                    "version": version,
                    "buildVersion": build,
                    "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "size": size,
                    "downloadURL": f"{base}/releases/download/v{version}/CatWorker.ipa",
                    "minOSVersion": "17.0",
                    "localizedDescription": f"Сборка {build}",
                }
            ],
        }
    ],
    "news": [],
}

sys.stdout.reconfigure(encoding="utf-8")
print(json.dumps(source, ensure_ascii=False, indent=2))
