defmodule VoileWeb.PageLive.Ebook do
  use VoileWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Load app colors from system settings
    app_main_color = Voile.Schema.System.get_setting_value("app_main_color", "#9333ea")
    app_secondary_color = Voile.Schema.System.get_setting_value("app_secondary_color", "#7c3aed")

    socket =
      socket
      |> assign(:app_main_color, app_main_color)
      |> assign(:app_secondary_color, app_secondary_color)
      |> assign(:page_title, "E-Book Reader")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <div class="min-h-screen bg-gradient-to-b from-purple-50 to-white dark:from-gray-900 dark:to-gray-800">
        <!-- Hero Section -->
        <section class="relative overflow-hidden">
          <div
            class="absolute inset-0 opacity-10"
            style={"background: linear-gradient(135deg, #{@app_main_color} 0%, #{@app_secondary_color} 100%);"}
          >
          </div>
          
          <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
            <div class="text-center">
              <div
                class="inline-flex items-center justify-center w-20 h-20 rounded-full mb-6 shadow-lg"
                style={"background: linear-gradient(135deg, #{@app_main_color}, #{@app_secondary_color});"}
              >
                <.icon name="hero-book-open" class="w-12 h-12 text-white" />
              </div>
              
              <h1 class="text-4xl md:text-5xl lg:text-6xl font-bold text-gray-900 dark:text-white mb-4">
                {gettext("E-Book Reader")}
              </h1>
              
              <p
                class="text-xl md:text-2xl font-semibold mb-6"
                style={"color: #{@app_main_color};"}
              >
                {gettext("Immersive Digital Reading Experience")}
              </p>
              
              <p class="text-lg text-gray-600 dark:text-gray-300 max-w-3xl mx-auto leading-relaxed">
                {gettext(
                  "Read digital books seamlessly with our advanced e-book reader supporting PDF and EPUB formats. Experience modern reading with full-screen views, navigation controls, and responsive design."
                )}
              </p>
            </div>
          </div>
        </section>
        <!-- Features Section -->
        <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div
              class="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 border hover:shadow-xl transition-shadow"
              style={"border-color: #{@app_main_color}33;"}
            >
              <div
                class="w-12 h-12 rounded-lg flex items-center justify-center mb-4"
                style={"background-color: #{@app_main_color}15; color: #{@app_main_color};"}
              >
                <.icon name="hero-document-text" class="w-6 h-6" />
              </div>
              
              <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                {gettext("Multiple Formats")}
              </h3>
              
              <p class="text-gray-600 dark:text-gray-300">
                {gettext(
                  "Support for PDF and EPUB formats ensuring compatibility with most digital book collections."
                )}
              </p>
            </div>
            
            <div
              class="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 border hover:shadow-xl transition-shadow"
              style={"border-color: #{@app_secondary_color}33;"}
            >
              <div
                class="w-12 h-12 rounded-lg flex items-center justify-center mb-4"
                style={"background-color: #{@app_secondary_color}15; color: #{@app_secondary_color};"}
              >
                <.icon name="hero-device-tablet" class="w-6 h-6" />
              </div>
              
              <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                {gettext("Responsive Design")}
              </h3>
              
              <p class="text-gray-600 dark:text-gray-300">
                {gettext(
                  "Read comfortably on any device with our adaptive interface that works across desktop, tablet, and mobile."
                )}
              </p>
            </div>
            
            <div
              class="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 border hover:shadow-xl transition-shadow"
              style={"border-color: #{@app_main_color}33;"}
            >
              <div
                class="w-12 h-12 rounded-lg flex items-center justify-center mb-4"
                style={"background-color: #{@app_main_color}15; color: #{@app_main_color};"}
              >
                <.icon name="hero-eye" class="w-6 h-6" />
              </div>
              
              <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                {gettext("Enhanced Reading")}
              </h3>
              
              <p class="text-gray-600 dark:text-gray-300">
                {gettext(
                  "Full-screen reading mode, page navigation, and zoom controls for an optimal reading experience."
                )}
              </p>
            </div>
          </div>
        </section>
        <!-- Key Features Section -->
        <section
          class="text-white py-16"
          style={"background: linear-gradient(135deg, #{@app_main_color}, #{@app_secondary_color});"}
        >
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="text-center mb-12">
              <h2 class="text-3xl md:text-4xl font-bold mb-4">{gettext("Reader Features")}</h2>
              
              <p class="text-white/80 text-lg">
                {gettext("Everything you need for a great reading experience")}
              </p>
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-arrows-pointing-out" class="w-6 h-6" />
                  </div>
                  
                  <div>
                    <h4 class="text-lg font-semibold mb-2">{gettext("Full-Screen Mode")}</h4>
                    
                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Immerse yourself in your reading with distraction-free full-screen viewing."
                      )}
                    </p>
                  </div>
                </div>
              </div>
              
              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-arrow-path" class="w-6 h-6" />
                  </div>
                  
                  <div>
                    <h4 class="text-lg font-semibold mb-2">{gettext("Easy Navigation")}</h4>
                    
                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Jump between pages quickly with intuitive controls and page indicators."
                      )}
                    </p>
                  </div>
                </div>
              </div>
              
              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-arrow-down-tray" class="w-6 h-6" />
                  </div>
                  
                  <div>
                    <h4 class="text-lg font-semibold mb-2">{gettext("Download Support")}</h4>
                    
                    <p class="text-white/80 text-sm">
                      {gettext("Download books for offline reading whenever you need them.")}
                    </p>
                  </div>
                </div>
              </div>
              
              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-shield-check" class="w-6 h-6" />
                  </div>
                  
                  <div>
                    <h4 class="text-lg font-semibold mb-2">{gettext("Secure Access")}</h4>
                    
                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Access control ensures only authorized users can view protected content."
                      )}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
        <!-- How to Use Section -->
        <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-xl p-8 md:p-12 border border-gray-200 dark:border-gray-700">
            <div class="text-center mb-8">
              <h2 class="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-4">
                {gettext("How to Use")}
              </h2>
              
              <div
                class="w-20 h-1 bg-gradient-to-r mx-auto rounded-full"
                style={"background: linear-gradient(90deg, #{@app_main_color}, #{@app_secondary_color});"}
              >
              </div>
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div class="text-center">
                <div
                  class="inline-flex items-center justify-center w-16 h-16 rounded-full mb-4"
                  style={"background: linear-gradient(135deg, #{@app_main_color}, #{@app_secondary_color});"}
                >
                  <span class="text-2xl font-bold text-white">1</span>
                </div>
                
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                  {gettext("Browse Collections")}
                </h3>
                
                <p class="text-gray-600 dark:text-gray-300">
                  {gettext("Navigate to the collections page and find the book you want to read.")}
                </p>
              </div>
              
              <div class="text-center">
                <div
                  class="inline-flex items-center justify-center w-16 h-16 rounded-full mb-4"
                  style={"background: linear-gradient(135deg, #{@app_main_color}, #{@app_secondary_color});"}
                >
                  <span class="text-2xl font-bold text-white">2</span>
                </div>
                
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                  {gettext("Select a Book")}
                </h3>
                
                <p class="text-gray-600 dark:text-gray-300">
                  {gettext("Click on a collection item to view its details and attached e-books.")}
                </p>
              </div>
              
              <div class="text-center">
                <div
                  class="inline-flex items-center justify-center w-16 h-16 rounded-full mb-4"
                  style={"background: linear-gradient(135deg, #{@app_main_color}, #{@app_secondary_color});"}
                >
                  <span class="text-2xl font-bold text-white">3</span>
                </div>
                
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                  {gettext("Start Reading")}
                </h3>
                
                <p class="text-gray-600 dark:text-gray-300">
                  {gettext("Click the read button to open the e-book in our full-featured reader.")}
                </p>
              </div>
            </div>
          </div>
        </section>
        <!-- CTA Section -->
        <section
          class="text-white py-16"
          style={"background: linear-gradient(135deg, #{@app_main_color}, #{@app_secondary_color});"}
        >
          <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
            <h2 class="text-3xl md:text-4xl font-bold mb-6">{gettext("Ready to Start Reading?")}</h2>
            
            <p class="text-xl text-white/80 mb-8">
              {gettext("Explore our digital collection and dive into your next book")}
            </p>
            
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <.link
                navigate={~p"/collections"}
                class="inline-flex items-center justify-center px-8 py-4 bg-white font-semibold rounded-lg shadow-lg hover:bg-gray-50 transition-colors"
                style={"color: #{@app_main_color};"}
              >
                <.icon name="hero-book-open" class="w-5 h-5 mr-2" /> {gettext("Browse Collections")}
              </.link>
              <.link
                navigate={~p"/"}
                class="inline-flex items-center justify-center px-8 py-4 bg-white/20 text-white font-semibold rounded-lg shadow-lg hover:bg-white/30 transition-colors backdrop-blur-sm"
              >
                <.icon name="hero-home" class="w-5 h-5 mr-2" /> {gettext("Back to Home")}
              </.link>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
