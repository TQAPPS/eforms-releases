import os
import base64
import re

FALLBACK_KEYSTORE_B64 = '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'

def setup():
    os.makedirs("android/app", exist_ok=True)
    
    keystore_path = "android/app/my-release-key.jks"
    keystore_b64 = os.environ.get("KEYSTORE_BASE64", "").strip()
    
    if keystore_b64:
        clean = re.sub(r'-----.*?-----|\s+', '', keystore_b64)
        with open(keystore_path, "wb") as f:
            f.write(base64.b64decode(clean))
        print(f"Keystore restored from KEYSTORE_BASE64 ({os.path.getsize(keystore_path)} bytes).")
    elif not os.path.exists(keystore_path):
        with open(keystore_path, "wb") as f:
            f.write(base64.b64decode(FALLBACK_KEYSTORE_B64))
        print(f"Keystore restored from embedded fallback ({os.path.getsize(keystore_path)} bytes).")
    else:
        print(f"Keystore already exists locally ({os.path.getsize(keystore_path)} bytes).")

    key_props_path = "android/key.properties"
    key_props = os.environ.get("KEY_PROPERTIES", "").strip()
    if key_props:
        with open(key_props_path, "w", encoding="utf-8") as f:
            f.write(key_props + "\n")
        print("Written key.properties from KEY_PROPERTIES secret.")
    else:
        store_password = os.environ.get("STORE_PASSWORD", "Nova0566#")
        key_password = os.environ.get("KEY_PASSWORD", "Nova0566#")
        key_alias = os.environ.get("KEY_ALIAS", "my-key-alias")
        with open(key_props_path, "w", encoding="utf-8") as f:
            f.write(f"storePassword={store_password}\n")
            f.write(f"keyPassword={key_password}\n")
            f.write(f"keyAlias={key_alias}\n")
            f.write("storeFile=my-release-key.jks\n")
        print("Written default key.properties.")

if __name__ == "__main__":
    setup()
