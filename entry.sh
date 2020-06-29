#!/bin/bash

cd /home/swipl/src/swipl-devel

if [ -z "$1" ]; then
  sudo -u swipl /bin/bash --rcfile /bash-init.sh
else
  sudo -u swipl /bin/bash /bash-init.sh $*
fi
