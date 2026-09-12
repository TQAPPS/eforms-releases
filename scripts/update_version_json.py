import json
import os
import datetime

def main():
    repo = os.environ.get('REPO', 'TQAPPS/eforms-releases')
    tag = os.environ.get('TAG_NAME', '')
    version = os.environ.get('VERSION', '')
    build_number_str = os.environ.get('BUILD_NUMBER', '1')
    try:
        build_number = int(build_number_str)
    except ValueError:
        build_number = 1

    notes = os.environ.get('NOTES', '')
    force_update = os.environ.get('FORCE_UPDATE', 'false').lower() == 'true'

    data = {
        "latest_version": version,
        "build_number": build_number,
        "apk_url": f"https://github.com/{repo}/releases/download/{tag}/app-release.apk",
        "release_notes": notes,
        "force_update": force_update,
        "publish_date": datetime.date.today().isoformat()
    }

    with open("version.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("version.json updated successfully.")

if __name__ == "__main__":
    main()
