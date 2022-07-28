defmodule YoloWeb.YoloLive do
  @moduledoc """
    Main live view of our YoloApp. Just allows adding, removing and checking off
    yolo items
  """
  use YoloWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:upload_file, nil)
      |> assign(:ans, [])
      |> allow_upload(
        :image,
        accept: :any,
        chunk_size: 6400_000,
        progress: &handle_progress/3,
        auto_upload: true
      )

    {:ok, socket}
  end

  def handle_progress(:image, _entry, socket) do
    upload_file =
      consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
        File.read(path)
      end)
      |> List.first()

    {:noreply, assign(socket, :upload_file, upload_file)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("detect",_params,%{assigns: %{upload_file: binary}} = socket) do
    {:noreply, assign(socket, :ans, YoloApp.Worker.detect(binary))}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {
     :noreply,
      socket
      |> assign(:upload_file, nil)
      |> assign(:ans, [])
    }
  end

  def notification_event(action) do
    Desktop.Window.show_notification(TodoWindow, "You did '#{inspect(action)}' me!",
      id: :click,
      type: :warning
    )
  end
end
