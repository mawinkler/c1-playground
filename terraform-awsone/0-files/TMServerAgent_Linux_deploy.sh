#!/bin/bash

cd $HOME/download

archive=TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar

if [ -f "${archive}" ]; then
    tar xf ${archive}
    sudo ./tmxbc install
fi
