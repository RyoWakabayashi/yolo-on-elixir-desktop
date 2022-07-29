defmodule YoloApp.Worker do
  use Agent
  alias YoloApp.Store
  alias YoloApp.Worker
  alias Evision, as: OpenCV

  def detect(binary) do
    label_list = Store.get(:label_list)

    binary
    |> preprocess()
    |> predict()
    |> to_tensor()
    |> filter_predictions(0.8)
    |> format_predictions()
    |> nms(0.8, 0.7)
    |> Enum.map(&Map.put(&1, :class, Enum.at(label_list, &1.class)))
  end

  def measure(function) do
    {time, result} = :timer.tc(function)
    IO.puts "Time: #{time}ms"
    result
  end

  def preprocess(binary) do
    binary
    |> StbImage.from_binary()
    |> elem(1)
    |> StbImage.to_nx()
    |> OpenCV.Nx.to_mat!()
    |> OpenCV.DNN.blobFromImage!(size: [608, 608], swapRB: true, crop: false)
  end

  def predict(blob) do
    net = Store.get(:net)
    out_names = Store.get(:out_names)

    net
    |> OpenCV.DNN.Net.setInput!(
      blob,
      name: "",
      scalefactor: 1 / 255,
      mean: [0, 0, 0]
    )
    |> OpenCV.DNN.Net.forward!(outBlobNames: out_names)
  end

  def to_tensor(predictions) do
    predictions
    |> Enum.map(fn prediction ->
      OpenCV.Nx.to_nx(prediction)
    end)
    |> Nx.concatenate()
  end

  def filter_predictions(predictions, score_threshold) do
    size =
      predictions
      |> Nx.shape()
      |> elem(0)

    threshold_tensor =
      score_threshold
      |> Nx.tensor()
      |> Nx.broadcast({size})

    index_list =
      Nx.transpose(predictions)[4]
      |> Nx.greater(threshold_tensor)
      |> Nx.to_flat_list()
      |> Enum.with_index()
      |> Enum.filter(fn {value, _} -> value == 1 end)
      |> Enum.map(&elem(&1, 1))
      |> Nx.tensor()

    Nx.take(predictions, index_list)
  end

  def format_predictions(predictions) do
    predictions
    |> Nx.to_batched_list(1)
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
  end

  def nms(formed_predictions, score_threshold, nms_threshold) do
    box_list = Enum.map(formed_predictions, & &1.box)
    score_list = Enum.map(formed_predictions, & &1.score)

    box_list
    |> OpenCV.DNN.nmsBoxes!(score_list, score_threshold, nms_threshold)
    |> Enum.map(&Enum.at(formed_predictions, &1))
  end
end
