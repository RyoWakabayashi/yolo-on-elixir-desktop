defmodule YoloApp.Store do
  use Agent
  alias __MODULE__
  alias Evision, as: OpenCV

  def start_link(opts) do
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

    Agent.start_link(fn ->
      %{
        net: net,
        out_names: out_names,
        label_list: label_list,
      }
    end, name: __MODULE__)
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end
end
