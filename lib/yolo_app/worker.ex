defmodule YoloApp.Worker do
  use Agent
  alias YoloApp.Store
  alias YoloApp.Worker

  def detect(binary) do
    label_list = Store.get(:label_list)

    binary
    |> to_nx()
    |> preprocess()
    |> predict()
    |> parse()
    |> filter_predictions(0.5)
    |> format_predictions()
    |> nms(0.7)
    |> Enum.map(&Map.put(&1, :class, Enum.at(label_list, &1.class)))
  end

  def measure(function) do
    {time, result} = :timer.tc(function)
    IO.puts("Time: #{time}ms")
    result
  end

  def to_nx(binary) do
    binary
    |> StbImage.read_binary!()
    |> StbImage.resize(416, 416)
    |> StbImage.to_nx()
  end

  def preprocess(tensor) do
    case Nx.axis_size(tensor, 2) do
      3 -> tensor
      4 -> Nx.slice(tensor, [0, 0, 0], [416, 416, 3])
    end
    |> Nx.divide(255)
    |> Nx.transpose(axes: [2, 0, 1])
    |> Nx.new_axis(0)
  end

  def predict(tensor) do
    model = Store.get(:model)
    params = Store.get(:params)

    Axon.predict(model, params, tensor)
  end

  def parse(feats) do
    anchors_tensor = Store.get(:anchors_tensor)

    feats =
      feats
      |> Nx.transpose(axes: [0, 2, 3, 1])
      |> Nx.reshape({1, 13, 13, 5, 85})

    conv_height_index =
      Nx.iota({13})
      |> Nx.tile([13])

    conv_width_index =
      Nx.iota({13})
      |> Nx.reshape({1, 13})
      |> Nx.tile([13, 1])
      |> Nx.transpose()
      |> Nx.flatten()

    conv_index =
      Nx.stack([conv_height_index, conv_width_index])
      |> Nx.transpose()
      |> Nx.reshape({1, 13, 13, 1, 2})
      |> Nx.as_type({:f, 32})

    conv_tensor =
      Nx.tensor([13, 13])
      |> Nx.reshape({1, 1, 1, 1, 2})
      |> Nx.as_type({:f, 32})

    box_xy =
      feats[[0..0, 0..12, 0..12, 0..4, 0..1]]
      |> Nx.logistic()
      |> Nx.add(conv_index)
      |> Nx.divide(conv_tensor)

    box_wh =
      feats[[0..0, 0..12, 0..12, 0..4, 2..3]]
      |> Nx.exp()
      |> Nx.multiply(anchors_tensor)
      |> Nx.divide(conv_tensor)

    box_mins =
      box_xy
      |> Nx.subtract(Nx.divide(box_wh, 2.0))

    box_maxes =
      box_xy
      |> Nx.add(Nx.divide(box_wh, 2))

    box_list =
      Nx.concatenate([
        box_mins[[0..0, 0..12, 0..12, 0..4, 0..0]],
        box_mins[[0..0, 0..12, 0..12, 0..4, 1..1]],
        box_maxes[[0..0, 0..12, 0..12, 0..4, 0..0]],
        box_maxes[[0..0, 0..12, 0..12, 0..4, 1..1]]
      ])
      |> Nx.transpose(axes: [4, 1, 2, 3, 0])

    box_confidence = Nx.logistic(feats[[0..0, 0..12, 0..12, 0..4, 4..4]])
    box_class_probs = feats[[0..0, 0..12, 0..12, 0..4, 5..84]]

    exp =
      box_class_probs
      |> Nx.exp()

    exp_sum =
      box_class_probs
      |> Nx.exp()
      |> Nx.sum(axes: [4])
      |> Nx.reshape({1, 13, 13, 5, 1})
      |> Nx.broadcast({1, 13, 13, 5, 80})

    box_class_probs = Nx.divide(exp, exp_sum)

    box_scores = Nx.multiply(box_confidence, box_class_probs)

    box_classes =
      box_scores
      |> Nx.argmax(axis: -1)
      |> Nx.reshape({1, 13, 13, 5, 1})

    box_class_scores =
      box_scores
      |> Nx.reduce_max(axes: [-1])
      |> Nx.reshape({1, 13, 13, 5, 1})

    Nx.concatenate(
      [
        box_class_scores,
        box_classes,
        box_list
      ],
      axis: 4
    )
    |> Nx.reshape({13 * 13 * 5, 6})
  end

  def filter_predictions(predictions, score_threshold) do
    box_class_scores =
      predictions
      |> Nx.transpose()

    box_class_scores = box_class_scores[0]

    prediction_mask = Nx.greater(box_class_scores, score_threshold)

    masked_index_list =
      prediction_mask
      |> Nx.to_flat_list()
      |> Enum.with_index()
      |> Enum.filter(fn {value, _} -> value == 1 end)
      |> Enum.map(&elem(&1, 1))
      |> Nx.tensor()

    Nx.take(predictions, masked_index_list)
  end

  def format_predictions(predictions) do
    predictions
    |> Nx.to_batched_list(1)
    |> Enum.map(fn t ->
      %{
        box: t[0][[2..5]] |> Nx.to_flat_list(),
        score: t[0][0] |> Nx.to_number(),
        class: t[0][1] |> Nx.to_number() |> trunc()
      }
    end)
  end

  def iou_nx(a, b, a_area, b_area) do
    num_b = Nx.shape(b) |> elem(0)
    abx_mn = Nx.max(a[0], b[[0..(num_b - 1), 0]])
    aby_mn = Nx.max(a[1], b[[0..(num_b - 1), 1]])
    abx_mx = Nx.min(a[2], b[[0..(num_b - 1), 2]])
    aby_mx = Nx.min(a[3], b[[0..(num_b - 1), 3]])
    w = Nx.subtract(abx_mx, abx_mn)
    h = Nx.subtract(aby_mx, aby_mn)
    intersect = Nx.multiply(w, h)

    Nx.divide(intersect, Nx.subtract(Nx.add(a_area, b_area), intersect))
  end

  def nms(predictions, iou_threshold) do
    box_list =
      predictions
      |> Enum.map(& &1.box)
      |> Nx.tensor()

    score_list =
      predictions
      |> Enum.map(& &1.score)
      |> Nx.tensor()

    num_boxes = Nx.shape(box_list) |> elem(0)

    areas =
      Nx.multiply(
        Nx.subtract(box_list[[0..(num_boxes - 1), 2]], box_list[[0..(num_boxes - 1), 0]]),
        Nx.subtract(box_list[[0..(num_boxes - 1), 3]], box_list[[0..(num_boxes - 1), 1]])
      )

    index_list =
      box_list
      |> Nx.to_batched_list(1)
      |> Enum.with_index()
      |> Enum.map(fn {box, index} ->
        box[0]
        |> iou_nx(box_list, areas[index], areas)
        |> Nx.greater(iou_threshold)
        |> Nx.to_flat_list()
      end)
      |> Enum.uniq()
      |> Enum.map(fn mask_list ->
        duplicated_index_list =
          mask_list
          |> Enum.with_index()
          |> Enum.filter(fn {value, _} -> value == 1 end)
          |> Enum.map(&elem(&1, 1))

        max_index =
          score_list
          |> Nx.take(duplicated_index_list |> Nx.tensor())
          |> Nx.argmax()
          |> Nx.to_number()

        Enum.at(duplicated_index_list, max_index)
      end)
      |> Enum.uniq()

    Enum.map(index_list, &Enum.at(predictions, &1))
  end

  def draw_predictions(mat, predictions) do
    {height, width, _} = OpenCV.Mat.shape!(mat)

    predictions
    |> Enum.reduce(mat, fn prediction, drawed_mat ->
      box = prediction.box
      left = Enum.at(box, 0) |> Kernel.*(width) |> trunc()
      top = Enum.at(box, 1) |> Kernel.*(height) |> trunc()
      right = Enum.at(box, 2) |> Kernel.*(width) |> trunc()
      bottom = Enum.at(box, 3) |> Kernel.*(height) |> trunc()

      drawed_mat
      |> OpenCV.rectangle!(
        [left, top],
        [right, bottom],
        [255, 0, 0],
        thickness: 4
      )

      # 四角形を描画する
      |> OpenCV.putText!(
        prediction.class,
        [left + 6, top + 26],
        OpenCV.cv_FONT_HERSHEY_SIMPLEX(),
        0.8,
        [0, 0, 255],
        thickness: 2
      )

      # ラベル文字を書く
    end)
    |> OpenCV.cvtColor!(OpenCV.cv_COLOR_BGR2RGB())
  end
end
