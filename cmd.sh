#!/bin/bash

# turn on bash's job control
set -m

# Start the primary process and put it in the background
/start_nginx.sh &

# Start the helper process
/init_repo.sh

# now we bring the primary process back into the foreground
# and leave it there
fg %1
