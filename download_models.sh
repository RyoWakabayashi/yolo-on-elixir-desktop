#!/bin/bash

mkdir -p priv/models

wget -c \
  -N https://pjreddie.com/media/files/yolov3.weights \
  -O ./priv/models/yolov3.weights

wget -c \
  -N https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3.cfg \
  -O ./priv/models/yolov3.cfg

wget -c \
  -N https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names \
  -O ./priv/models/labels.txt
