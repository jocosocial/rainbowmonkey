composite -gravity center icons/foreground.png icons/background.png icons/cruise_monkey.png
mogrify -gravity center -crop 1000x1000+0+0 +repage icons/cruise_monkey.png
convert icons/cruise_monkey.png \( +clone -threshold -1 -negate -fill white -draw "circle 500,500 500,25" \) -alpha off -compose copy_opacity -composite icons/badge.png
convert icons/badge.png \( -clone 0 -background black -shadow 50x15+25+25 \) \( -clone 0 -background black -shadow 80x10+0+0 \) -reverse -background none -layers merge -trim +repage icons/splash.png
flutter packages pub run flutter_launcher_icons:main
convert icons/foreground.png -trim +repage -transparent white android/app/src/main/res/drawable/notifications.png
convert icons/cruise_monkey.png -resize 128x128 images/cruise_monkey.png
convert icons/cruise_monkey.png -resize 512x512 images/android_store_icon.png
convert icons/foreground.png -trim -resize 80x80 images/emoji/monkey.png
convert icons/badge.png -trim -resize 80x80 images/emoji/rainbow-monkey.png
convert icons/splash.png -trim -resize 500x500 android/app/src/main/res/drawable/splash.png
