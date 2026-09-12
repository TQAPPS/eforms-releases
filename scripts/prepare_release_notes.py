import json
import os

def main():
    version = os.environ.get('VERSION', '')
    notes = f"• إصدار جديد v{version}"
    force_update = "false"

    event_name = os.environ.get('GITHUB_EVENT_NAME', '')
    dispatch_notes = os.environ.get('INPUT_RELEASE_NOTES', '')
    dispatch_force = os.environ.get('INPUT_FORCE_UPDATE', '')

    if event_name == 'workflow_dispatch' and dispatch_notes:
        notes = dispatch_notes
        if dispatch_force:
            force_update = dispatch_force
    elif os.path.exists('version.json'):
        try:
            with open('version.json', 'r', encoding='utf-8') as f:
                vdata = json.load(f)
                if vdata.get('latest_version') == version and vdata.get('release_notes'):
                    notes = vdata['release_notes']
                if 'force_update' in vdata:
                    force_update = str(vdata['force_update']).lower()
        except Exception as e:
            print("Warning reading version.json:", e)

    github_env = os.environ.get('GITHUB_ENV')
    if github_env:
        with open(github_env, 'a', encoding='utf-8') as f:
            f.write(f"TAG_NAME=v{version}\n")
            f.write(f"FORCE_UPDATE={force_update}\n")
            f.write("NOTES<<EOF\n")
            f.write(notes + "\n")
            f.write("EOF\n")
    print(f"Prepared release tag: v{version}, force_update: {force_update}")

if __name__ == "__main__":
    main()
