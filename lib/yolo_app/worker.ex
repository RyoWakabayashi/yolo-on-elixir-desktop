defmodule YoloApp.Worker do
  alias Evision, as: OpenCV

  def detect(binary) do
    priv_path = List.to_string(:code.priv_dir(:yolo_app))

    cfg_path = priv_path <> "/models/yolov3.cfg"
    weights_path = priv_path <> "/models/yolov3.weights"
    labels_path = priv_path <> "/models/labels.txt"

    net = OpenCV.DNN.readNet!(weights_path, config: cfg_path, framework: "")
    out_names = OpenCV.DNN.Net.getUnconnectedOutLayersNames!(net)
    label_list =
      labels_path
      |> File.stream!()
      |> Enum.map(&String.trim/1)

    {:ok, image} = StbImage.from_binary(binary)

    mat =
      image
      |> StbImage.to_nx()
      |> OpenCV.Nx.to_mat!()

    blob = OpenCV.DNN.blobFromImage!(mat, size: [608, 608], swapRB: true, crop: false)

    predictions =
      net
      |> OpenCV.DNN.Net.setInput!(
        blob,
        name: "",
        scalefactor: 1 / 255,
        mean: [0, 0, 0]
      )
      |> OpenCV.DNN.Net.forward!(outBlobNames: out_names)

    score_threshold = 0.8

    formed_predictions =
      predictions
      |> Enum.map(fn prediction ->
        OpenCV.Nx.to_nx(prediction)
      end)
      |> Nx.concatenate()
      |> Nx.to_batched_list(1)
      |> Enum.filter(fn t ->
        t[0][4]
        |> Nx.to_number()
        |> Kernel.>(score_threshold)
      end)
      |> Enum.map(fn t ->
        class_score_list = t[0][5..-1//1]
        class_id = class_score_list |> Nx.argmax() |> Nx.to_number()
        class_score = class_score_list[class_id] |> Nx.to_number()
        score = t[0][4] |> Nx.to_number() |> Kernel.*(class_score)

        center_x = t[0][0] |> Nx.to_number()
        center_y = t[0][1] |> Nx.to_number()
        box_width = t[0][2] |> Nx.to_number()
        box_height = t[0][3] |> Nx.to_number()
        min_x = center_x - box_width / 2
        min_y = center_y - box_height / 2
        max_x = center_x + box_width / 2
        max_y = center_y + box_height / 2

        box = [min_x, min_y, max_x, max_y]

        %{
          box: box,
          score: score,
          class: class_id
        }
      end)

    box_list = Enum.map(formed_predictions, & &1.box)
    score_list = Enum.map(formed_predictions, & &1.score)

    nms_threshold = 0.7

    index_list = OpenCV.DNN.nmsBoxes!(box_list, score_list, score_threshold, nms_threshold)

    index_list
    |> Enum.map(&Enum.at(formed_predictions, &1))
    |> Enum.map(&Map.put(&1, :class, Enum.at(label_list, &1.class)))
  end
end
