defmodule VoileWeb.VoileComponents do
  use Phoenix.Component
  use Phoenix.LiveComponent

  alias Phoenix.LiveView.JS

  @doc """
  Main Search Component for GLAM (Gallery, Library, Archive, Museum)

  ## Examples

    <.main_search />

  The components doesn't need custom props, it will use the default props.
  """
  attr :state, :string, default: "quick"

  def main_search(assigns) do
    ~H"""
    <div>
      <div class="search-tab">
        <button
          id="tab1"
          tabindex="1"
          class="search-tab-item active-tab-item"
          phx-click={set_active_tab("#tab1") |> show_active_content("#quick-search")}
        >
          Search
        </button>
        <button
          id="tab2"
          tabindex="2"
          class="search-tab-item"
          phx-click={set_active_tab("#tab2") |> show_active_content("#gallery-search")}
        >
          Gallery
        </button>
        <button
          id="tab3"
          tabindex="3"
          class="search-tab-item"
          phx-click={set_active_tab("#tab3") |> show_active_content("#library-search")}
        >
          Library
        </button>
        <button
          id="tab4"
          tabindex="4"
          class="search-tab-item"
          phx-click={set_active_tab("#tab4") |> show_active_content("#archive-search")}
        >
          Archive
        </button>
        <button
          id="tab5"
          tabindex="5"
          class="search-tab-item"
          phx-click={set_active_tab("#tab5") |> show_active_content("#museum-search")}
        >
          Museum
        </button>
      </div>
      
      <div class="bg-violet-200 dark:bg-gray-800 p-5 rounded-bl-lg rounded-br-lg flex gap-2">
        <div class="w-full">
          <div id="quick-search" class="tab-content block">
            <input
              type="text"
              placeholder="Search what you need here..."
              name="quick-search"
              class="input-main-search"
            />
          </div>
          
          <div id="gallery-search" class="tab-content hidden">
            <input
              type="text"
              placeholder="Feeling blue ? find something interesting on our Gallery..."
              name="gallery-search"
              class="input-main-search"
            />
          </div>
          
          <div id="library-search" class="tab-content hidden">
            <input
              type="text"
              placeholder="Search more and read more from our books..."
              name="library-search"
              class="input-main-search"
            />
          </div>
          
          <div id="archive-search" class="tab-content hidden">
            <input
              type="text"
              placeholder="Checkout our historical archive document..."
              name="archive-search"
              class="input-main-search"
            />
          </div>
          
          <div id="museum-search" class="tab-content hidden">
            <input
              type="text"
              placeholder="Bringing memories comeback, search in museum..."
              name="museum-search"
              class="input-main-search"
            />
          </div>
        </div>
        
        <div><button class="default-btn">Search</button></div>
      </div>
    </div>
    """
  end

  ## JS Commands (with fade transitions)
  def show_active_content(js \\ %JS{}, to) do
    js
    |> JS.hide(
      to: ".tab-content",
      transition:
        {"transition-all transform ease-in duration-50", "opacity-100 translate-y-0",
         "opacity-0 translate-y-1"}
    )
    |> JS.show(
      to: to,
      transition:
        {"transition-all transform ease-out duration-150", "opacity-0 translate-y-1",
         "opacity-100 translate-y-0"},
      display: "block"
    )
  end

  def set_active_tab(js \\ %JS{}, tab) do
    js
    |> JS.remove_class("active-tab-item", to: ".search-tab-item")
    |> JS.add_class("active-tab-item", to: tab)
  end
end
