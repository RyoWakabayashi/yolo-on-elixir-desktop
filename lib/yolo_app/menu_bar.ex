defmodule YoloApp.MenuBar do
  @moduledoc """
    Menubar that is shown as part of the main Window on Windows/Linux. In
    MacOS this Menubar appears at the very top of the screen.
  """
  import YoloWeb.Gettext
  use Desktop.Menu
  alias Desktop.Window

  def render(assigns) do
    ~E"""
    <menubar>
    <menu label="<%= gettext "File" %>">
        <%= for item <- @yolos do %>
        <item
            type="checkbox" onclick="toggle:<%= item.id %>"
            <%= if item.status == "done" do %>checked="checked"<% end %>
            ><%= item.text %></item>
        <% end %>
        <hr/>
        <item onclick="quit"><%= gettext "Quit" %></item>
    </menu>
    <menu label="<%= gettext "Extra" %>">
        <item onclick="notification"><%= gettext "Show Notification" %></item>
        <item onclick="observer"><%= gettext "Show Observer" %></item>
        <item onclick="browser"><%= gettext "Open Browser" %></item>
    </menu>
    </menubar>
    """
  end

  def handle_event(<<"toggle:", id::binary>>, menu) do
    {:noreply, menu}
  end

  def handle_event("observer", menu) do
    :observer.start()
    {:noreply, menu}
  end

  def handle_event("quit", menu) do
    Window.quit()
    {:noreply, menu}
  end

  def handle_event("browser", menu) do
    Window.prepare_url(YoloWeb.Endpoint.url())
    |> :wx_misc.launchDefaultBrowser()

    {:noreply, menu}
  end

  def handle_event("notification", menu) do
    Window.show_notification(YoloWindow, gettext("Sample Elixir Desktop App!"),
      callback: &YoloWeb.YoloLive.notification_event/1
    )

    {:noreply, menu}
  end

  def mount(menu) do
    {:ok, assign(menu, yolos: [])}
  end

  def handle_info(:changed, menu) do
    {:noreply, assign(menu, yolos: [])}
  end
end
