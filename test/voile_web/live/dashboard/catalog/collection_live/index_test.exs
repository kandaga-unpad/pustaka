defmodule VoileWeb.Dashboard.Catalog.CollectionLive.IndexTest do
  use VoileWeb.ConnCase, async: true

  alias VoileWeb.Dashboard.Catalog.CollectionLive.Index
  alias Phoenix.LiveView.Socket

  describe "search debounce behavior" do
    test "live_search_collections sets timer and cancels previous one" do
      # start with empty socket
      socket = %Socket{assigns: %{collection_search_timer: nil}}

      # first event creates a timer reference
      {:noreply, socket1} =
        Index.handle_event("live_search_collections", %{"query" => "foo"}, socket)

      assert socket1.assigns.collection_search_loading == true
      assert is_reference(socket1.assigns.collection_search_timer)

      timer1 = socket1.assigns.collection_search_timer

      # second event should cancel the first timer and set a new one
      {:noreply, socket2} =
        Index.handle_event("live_search_collections", %{"query" => "foobar"}, socket1)

      assert is_reference(socket2.assigns.collection_search_timer)
      refute socket2.assigns.collection_search_timer == timer1

      # old timer should have been cancelled by the code
      assert Process.read_timer(timer1) == false
    end
  end
end
