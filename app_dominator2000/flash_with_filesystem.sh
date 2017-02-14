pushd ../mp3media/ && sh create_flash_image.sh && popd
xflash --boot-partition-size 262144 --data ../mp3media/mp3_flash_image.bin bin/app_dominator2000.xe