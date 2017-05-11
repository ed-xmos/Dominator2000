pushd ../mp3media/ && sh create_flash_image.sh && popd
xflash --boot-partition-size 131072 --data ../mp3media/mp3_flash_image.bin bin/app_flash_only_data.xe