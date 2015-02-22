
Setting path to libclang:
  export LIBCLANG=`ldconfig -p | grep 'libclang.so' | awk '{ print $4 }'`
