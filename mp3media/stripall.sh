for fn in ls media/*.mp3;
do
python mp3strip.py $fn
done
