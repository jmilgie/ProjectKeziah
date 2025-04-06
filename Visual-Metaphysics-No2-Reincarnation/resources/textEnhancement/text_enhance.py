import cv2
import sys
import numpy as np

def enhance_text(input_file, output_file, scale_factor=2.0):
    image = cv2.imread(input_file, cv2.IMREAD_COLOR)

    # Upscale the image
    height, width = image.shape[:2]
    new_height, new_width = int(height * scale_factor), int(width * scale_factor)
    upscaled = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_CUBIC)

    gray = cv2.cvtColor(upscaled, cv2.COLOR_BGR2GRAY)

    # Apply adaptive thresholding
    thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 31, 15)

    # Apply dilation followed by erosion (closing) to reduce blockiness
    kernel = np.ones((2, 2), np.uint8)
    closing = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)

    # Save the enhanced image
    cv2.imwrite(output_file, closing)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python text_enhance.py <input_image> <output_image>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    enhance_text(input_file, output_file)
