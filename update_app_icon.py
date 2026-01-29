from PIL import Image
import os

logo_path = "/Users/luwenting/development/ChillNote/chillnote/Assets.xcassets/logo.imageset/logo.png"
app_icon_path = "/Users/luwenting/development/ChillNote/chillnote/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

def update_icon():
    if not os.path.exists(logo_path):
        print(f"Error: logo.png not found at {logo_path}")
        return

    try:
        img = Image.open(logo_path)
        print(f"Original size: {img.size}")

        # Resize to 1024x1024 if needed
        if img.size != (1024, 1024):
            print("Resizing to 1024x1024...")
            img = img.resize((1024, 1024), Image.Resampling.LANCZOS)
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(app_icon_path), exist_ok=True)
        
        img.save(app_icon_path, "PNG")
        print(f"Successfully set {logo_path} as AppIcon at {app_icon_path}")
    except Exception as e:
        print(f"Failed to update icon: {e}")

if __name__ == "__main__":
    update_icon()
