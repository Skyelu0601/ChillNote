from PIL import Image
import os

source_path = "/Users/luwenting/.gemini/antigravity/brain/2d980493-d25a-4c8a-affd-f70a2e79d47b/chillnote_app_icon_v3_1767792497559.png"
app_icon_path = "/Users/luwenting/development/ChillNote/chillnote/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
logo_path = "/Users/luwenting/development/ChillNote/chillnote/Assets.xcassets/ChillLogo.imageset/ChillLogo.png"

def process_image():
    if not os.path.exists(source_path):
        print(f"Source not found: {source_path}")
        return

    img = Image.open(source_path).convert("RGBA")
    
    # 1. Background Color: Creamy Yellow (Requested)
    new_bg_color = (255, 235, 160, 255) # #FFEBA0
    
    # 2. Extract Text
    width, height = img.size
    datas = img.getdata()
    newData = []
    
    min_x, min_y, max_x, max_y = width, height, 0, 0
    has_text = False
    
    for i, item in enumerate(datas):
        # Calculate Luminance
        lum = 0.299*item[0] + 0.587*item[1] + 0.114*item[2]
        
        x = i % width
        y = i // width
        
        if lum < 150: 
            # Text
            newData.append(item)
            if x < min_x: min_x = x
            if x > max_x: max_x = x
            if y < min_y: min_y = y
            if y > max_y: max_y = y
            has_text = True
        else:
            # Background
            newData.append(new_bg_color)
            
    img.putdata(newData)
    
    # 3. Crop with Balanced Padding (15%)
    if has_text:
        padding_percent = 0.15
        
        w = max_x - min_x
        h = max_y - min_y
        
        pad_w = int(w * padding_percent)
        pad_h = int(h * padding_percent)
        
        left = max(0, min_x - pad_w)
        top = max(0, min_y - pad_h)
        right = min(img.width, max_x + pad_w)
        bottom = min(img.height, max_y + pad_h)
        
        img = img.crop((left, top, right, bottom))
        print(f"Cropped with padding: {img.size}")
    
    # 4. Resize to 1024x1024
    final_size = (1024, 1024)
    final_img = Image.new("RGBA", final_size, new_bg_color)
    
    ratio = min(final_size[0] / img.width, final_size[1] / img.height)
    new_size = (int(img.width * ratio), int(img.height * ratio))
    
    img_resized = img.resize(new_size, Image.Resampling.LANCZOS)
    
    paste_x = (final_size[0] - new_size[0]) // 2
    paste_y = (final_size[1] - new_size[1]) // 2
    
    final_img.paste(img_resized, (paste_x, paste_y))
    
    # Save
    if not os.path.exists(os.path.dirname(app_icon_path)):
        os.makedirs(os.path.dirname(app_icon_path))
        
    final_img.save(app_icon_path, "PNG")
    print(f"Saved AppIcon to {app_icon_path}")
    
    final_img.save(logo_path, "PNG")
    print(f"Saved Logo to {logo_path}")

if __name__ == "__main__":
    process_image()
