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
    set_state_icon(menu)
    {:ok, menu}
  end

  def handle_info(:changed, menu) do
    set_state_icon(menu)

    {:noreply, menu}
  end

  defp set_state_icon(menu) do
    if checked?(menu.yolos) do
      Menu.set_icon(menu, {:file, "icon32x32-done.png"})
    else
      Menu.set_icon(menu, {:file, "icon32x32.png"})
    end
  end

  defp checked?([]) do
    true
  end

  defp checked?([%{status: "done"} | yolos]) do
    checked?(yolos)
  end

  defp checked?([%{status: _} | yolos]) do
    false && checked?(yolos)
  end
end
