DIR=`pwd`
file=$1

cd ~/documents/stan/stanc3
cp $DIR/$file.stan $file.stan
./build
./run --O --debug-optimized-mir-pretty $file.stan > $DIR/$file.opt-mir
./run --debug-transformed-mir-pretty $file.stan > $DIR/$file.tx-mir
cp $DIR/$file.opt-mir $DIR/$file.opt-mir.edit
echo $file.stan "->" $file.opt-mir
