DIR=`pwd`
file=$1

cd ~/documents/stan/stanc3
cp $DIR/$file.stan $file.stan
#./build
./run --debug-transformed-mir-pretty $file.stan > $DIR/$file.tx-mir
cp $DIR/$file.tx-mir $DIR/$file.tx-mir.edit
echo $file.stan "->" $file.tx-mir
