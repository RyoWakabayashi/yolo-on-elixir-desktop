defmodule YoloApp do
  @moduledoc """
    YoloApp Application.

    Other than that this module initialized the main `Desktop.Window`
    and configures it to create a taskbar icon as well.

  """
  use Application
  require Logger

  def config_dir() do
    Path.join([Desktop.OS.home(), ".config", "yolo"])
  end

  @app Mix.Project.config()[:app]

  def start(:normal, []) do
    Desktop.identify_default_locale(YoloWeb.Gettext)
    File.mkdir_p!(config_dir())

    {:ok, sup} = Supervisor.start_link([YoloApp.Store], name: __MODULE__, strategy: :one_for_one)

    {:ok, _} = Supervisor.start_child(sup, YoloWeb.Sup)

    {:ok, _} =
      Supervisor.start_child(sup, {
        Desktop.Window,
        [
          app: @app,
          id: YoloWindow,
          title: "YoloApp",
          size: {600, 500},
          icon: "icon.png",
          menubar: YoloApp.MenuBar,
          icon_menu: YoloApp.Menu,
          url: &YoloWeb.Endpoint.url/0
        ]
      })
  end

  def config_change(changed, _new, removed) do
    YoloWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
