defmodule YoloApp.Menu do
  @moduledoc """
    Menu that is shown when a user click on the taskbar icon of the YoloApp
  """
  import YoloWeb.Gettext
  use Desktop.Menu

  def handle_event(command, menu) do
    case command do
      <<"quit">> -> Desktop.Window.quit()
      <<"edit">> -> Desktop.Window.show(YoloWindow)
    end

    {:noreply, menu}
  end

  def mount(menu) do
    {:ok, menu}
  end

  def handle_info(:changed, menu) do
    {:noreply, menu}
  end
end
