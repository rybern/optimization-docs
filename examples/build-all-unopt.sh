DIR=`pwd`
file=$1

for file in `ls *.stan`; do
  fn=${file%.*}
  ./build-unopt.sh $fn
  cp $DIR/$fn.tx-mir $DIR/$fn.tx-mir.edit
  echo $fn.stan "->" $fn.tx-mir
done

