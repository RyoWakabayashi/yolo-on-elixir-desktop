defmodule YoloApp.Store do
  use Agent
  alias __MODULE__

  def start_link(opts) do
    priv_path = List.to_string(:code.priv_dir(:yolo_app))

    model_path = priv_path <> "/models/yolov2.onnx"
    labels_path = priv_path <> "/models/labels.txt"

    {model, params} = AxonOnnx.import(model_path)

    label_list =
      labels_path
      |> File.stream!()
      |> Enum.map(&String.trim/1)

    anchors =
      Nx.tensor([
        [0.57273, 0.677385],
        [1.87446, 2.06253],
        [3.33843, 5.47434],
        [7.88282, 3.52778],
        [9.77052, 9.16828]
      ])

    anchors_tensor = Nx.reshape(anchors, {1, 1, 1, 5, 2})

    Agent.start_link(
      fn ->
        %{
          model: model,
          params: params,
          label_list: label_list,
          anchors_tensor: anchors_tensor
        }
      end,
      name: __MODULE__
    )
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end
end
