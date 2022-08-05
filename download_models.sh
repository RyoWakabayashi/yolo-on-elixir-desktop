#!/bin/bash

mkdir -p priv/models

wget -c \
  -N https://media.githubusercontent.com/media/onnx/models/main/vision/object_detection_segmentation/yolov2-coco/model/yolov2-coco-9.onnx \
  -O ./priv/models/yolov2.onnx

wget -c \
  -N https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names \
  -O ./priv/models/labels.txt
