Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Dell\.gemini\antigravity\brain\beb2bed3-36cd-4b11-9b92-ad46687a3b29\.user_uploaded\media_1791813483988_9991bca5.jpg"
$baseImg = [System.Drawing.Image]::FromFile($srcPath)
Write-Host "Original Image Dimensions: $($baseImg.Width) x $($baseImg.Height)"

# The sunflower head is in the upper portion of the image.
# Let's crop a square region centered on the sunflower head so it looks gorgeous as an app icon!
# Flower head center is roughly around x: 45-50%, y: 35-40%.
# Let's see: square crop width = min(width, height) = width.
$cropSize = [Math]::Min($baseImg.Width, $baseImg.Height)
# Shift the crop slightly towards the top where the sunflower blossom is
$cropX = [Math]::Max(0, [int](($baseImg.Width - $cropSize) / 2))
# Offset Y so the flower head is nicely centered in the square
$cropY = [Math]::Max(0, [Math]::Min([int]($baseImg.Height * 0.12), $baseImg.Height - $cropSize))

Write-Host "Crop Region: X=$cropX, Y=$cropY, Size=$cropSize"

$resDir = "C:\Users\Dell\.gemini\antigravity\scratch\sumobot_controller\android\app\src\main\res"

$sizes = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

# Also save an icon source in assets if needed
$assetsDir = "C:\Users\Dell\.gemini\antigravity\scratch\sumobot_controller\assets"
if (!(Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

foreach ($folder in $sizes.Keys) {
    $targetSize = $sizes[$folder]
    $destFolder = Join-Path $resDir $folder
    $destPath = Join-Path $destFolder "ic_launcher.png"

    $bitmap = New-Object System.Drawing.Bitmap $targetSize, $targetSize
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $destRect = New-Object System.Drawing.Rectangle 0, 0, $targetSize, $targetSize
    $srcRect = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropSize, $cropSize

    $graphics.DrawImage($baseImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()

    $bitmap.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    Write-Host "Saved: $destPath ($targetSize x $targetSize)"
}

# Save a 512x512 store/master icon
$masterPath = Join-Path $assetsDir "app_icon_512.png"
$masterBmp = New-Object System.Drawing.Bitmap 512, 512
$mGraphics = [System.Drawing.Graphics]::FromImage($masterBmp)
$mGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$mGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$mDestRect = New-Object System.Drawing.Rectangle 0, 0, 512, 512
$mSrcRect = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropSize, $cropSize
$mGraphics.DrawImage($baseImg, $mDestRect, $mSrcRect, [System.Drawing.GraphicsUnit]::Pixel)
$mGraphics.Dispose()
$masterBmp.Save($masterPath, [System.Drawing.Imaging.ImageFormat]::Png)
$masterBmp.Dispose()
Write-Host "Saved master icon: $masterPath"

$baseImg.Dispose()
Write-Host "All launcher icons generated successfully!"
