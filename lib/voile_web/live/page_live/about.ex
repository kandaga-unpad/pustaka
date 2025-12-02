defmodule VoileWeb.PageLive.About do
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
                {gettext("Voile, the Magic Library")}
              </h1>

              <p
                class="text-xl md:text-2xl font-semibold mb-6"
                style={"color: #{@app_main_color};"}
              >
                {gettext("Virtual Organized of Information & Library Ecosystem")}
              </p>

              <p class="text-lg text-gray-600 dark:text-gray-300 max-w-3xl mx-auto leading-relaxed">
                {gettext(
                  "A next-generation digital library management system designed to bridge the gap between traditional library heritage and modern information technology."
                )}
              </p>
            </div>
          </div>
        </section>
        <!-- Overview Section -->
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
                <.icon name="hero-sparkles" class="w-6 h-6" />
              </div>

              <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                {gettext("Digital Transformation")}
              </h3>

              <p class="text-gray-600 dark:text-gray-300">
                {gettext(
                  "VOILE reimagines the cultural institution experience by providing a fully digital ecosystem that caters to libraries while also supporting galleries, archives, and museums."
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
                <.icon name="hero-server-stack" class="w-6 h-6" />
              </div>

              <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                {gettext("Robust Architecture")}
              </h3>

              <p class="text-gray-600 dark:text-gray-300">
                {gettext(
                  "Built with Elixir and Phoenix, leveraging high concurrency, fault tolerance, and real-time performance for a scalable platform."
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
                <.icon name="hero-paint-brush" class="w-6 h-6" />
              </div>

              <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                {gettext("User-Centric Design")}
              </h3>

              <p class="text-gray-600 dark:text-gray-300">
                {gettext(
                  "Inspired by violet and purple hues, offering a visually engaging experience that evokes the magic of ancient libraries and cultural heritage."
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
              <h2 class="text-3xl md:text-4xl font-bold mb-4">{gettext("Key Features")}</h2>

              <p class="text-white/80 text-lg">
                {gettext("Powerful tools for modern library management")}
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-folder-open" class="w-6 h-6" />
                  </div>

                  <div>
                    <h4 class="text-lg font-semibold mb-2">
                      {gettext("Advanced Cataloging & Metadata Management")}
                    </h4>

                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Efficiently manage diverse collections with sophisticated indexing, metadata tagging, and categorization tools."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-magnifying-glass" class="w-6 h-6" />
                  </div>

                  <div>
                    <h4 class="text-lg font-semibold mb-2">
                      {gettext("Dynamic Search & Retrieval")}
                    </h4>

                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Robust search functionalities including filters, metadata searches, and full-text search capabilities."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-user-circle" class="w-6 h-6" />
                  </div>

                  <div>
                    <h4 class="text-lg font-semibold mb-2">
                      {gettext("User Authentication & Personalization")}
                    </h4>

                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Secure access controls with personalized experiences, ensuring safe and engaging interactions."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-chart-bar" class="w-6 h-6" />
                  </div>

                  <div>
                    <h4 class="text-lg font-semibold mb-2">
                      {gettext("Data Analytics & Reporting")}
                    </h4>

                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Integrated analytics offer insights into user behavior and collection usage for data-driven decisions."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-arrow-trending-up" class="w-6 h-6" />
                  </div>

                  <div>
                    <h4 class="text-lg font-semibold mb-2">{gettext("Scalable Ecosystem")}</h4>

                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Designed for growth, handling increasing data loads ideal for academic libraries and cultural institutions."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white/10 backdrop-blur-lg rounded-lg p-6 border border-white/20">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 bg-white/20 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-globe-alt" class="w-6 h-6" />
                  </div>

                  <div>
                    <h4 class="text-lg font-semibold mb-2">{gettext("GLAM Integration")}</h4>

                    <p class="text-white/80 text-sm">
                      {gettext(
                        "Unified support for Galleries, Libraries, Archives, and Museums in a single platform."
                      )}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
        <!-- Vision Section -->
        <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-xl p-8 md:p-12 border border-gray-200 dark:border-gray-700">
            <div class="text-center mb-8">
              <h2 class="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-4">
                {gettext("Our Vision")}
              </h2>

              <div
                class="w-20 h-1 bg-gradient-to-r mx-auto rounded-full"
                style={"background: linear-gradient(90deg, #{@app_main_color}, #{@app_secondary_color});"}
              >
              </div>
            </div>

            <div class="prose prose-lg dark:prose-invert max-w-none">
              <p class="text-gray-600 dark:text-gray-300 text-lg leading-relaxed mb-6">
                {gettext(
                  "VOILE is more than just a library management system—it's a digital sanctuary for cultural preservation and discovery. By uniting classical library principles with GLAM concepts and cutting-edge technology, VOILE aims to enhance how libraries operate while simultaneously supporting galleries, archives, and museums."
                )}
              </p>

              <p class="text-gray-600 dark:text-gray-300 text-lg leading-relaxed">
                {gettext(
                  "This integrated approach empowers users to explore and engage with a rich tapestry of cultural heritage, transforming the way knowledge and art are experienced in the digital age."
                )}
              </p>
            </div>
          </div>
        </section>
        <!-- Technology Stack Section -->
        <section class="bg-gray-50 dark:bg-gray-900/50 py-16">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="text-center mb-12">
              <h2 class="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-4">
                {gettext("Built with Modern Technology")}
              </h2>

              <p class="text-gray-600 dark:text-gray-300 text-lg">
                {gettext("Powered by industry-leading tools and frameworks")}
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-4xl mx-auto">
              <div class="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6">
                <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
                  <span style={"color: #{@app_main_color};"}>
                    <.icon name="hero-server" class="w-6 h-6" />
                  </span>
                  {gettext("Server")}
                </h3>

                <ul class="space-y-3">
                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_main_color};"}
                    >
                    </span>
                    <span><strong>Elixir</strong> v1.18.0</span>
                  </li>

                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_main_color};"}
                    >
                    </span>
                    <span><strong>Phoenix</strong> v1.17.20</span>
                  </li>

                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_main_color};"}
                    >
                    </span>
                    <span><strong>Erlang (BEAM VM)</strong> OTP 27.1</span>
                  </li>

                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_main_color};"}
                    >
                    </span>
                    <span><strong>PostgreSQL</strong> 14 or newer</span>
                  </li>
                </ul>
              </div>

              <div class="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6">
                <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
                  <span style={"color: #{@app_secondary_color};"}>
                    <.icon name="hero-computer-desktop" class="w-6 h-6" />
                  </span>
                  {gettext("Client")}
                </h3>

                <ul class="space-y-3">
                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_secondary_color};"}
                    >
                    </span>
                    <span><strong>Phoenix LiveView</strong></span>
                  </li>

                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_secondary_color};"}
                    >
                    </span>
                    <span><strong>Tailwind CSS</strong></span>
                  </li>

                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_secondary_color};"}
                    >
                    </span>
                    <span><strong>Real-time Interactivity</strong></span>
                  </li>

                  <li class="flex items-center gap-3 text-gray-600 dark:text-gray-300">
                    <span
                      class="w-2 h-2 rounded-full"
                      style={"background-color: #{@app_secondary_color};"}
                    >
                    </span>
                    <span><strong>Responsive Design</strong></span>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </section>
        <!-- Developer Section -->
        <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div class="text-center">
            <h2 class="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-8">
              {gettext("Developer")}
            </h2>

            <div class="inline-flex items-center gap-4 bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 border border-gray-200 dark:border-gray-700">
              <div
                class="w-16 h-16 rounded-full flex items-center justify-center"
                style={"background: linear-gradient(135deg, #{@app_main_color}, #{@app_secondary_color});"}
              >
                <.icon name="hero-code-bracket" class="w-8 h-8 text-white" />
              </div>

              <div class="text-left">
                <a
                  href="https://github.com/chrisnaadhi"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-xl font-semibold hover:opacity-80 transition-opacity"
                  style={"color: #{@app_main_color};"}
                >
                  @chrisnaadhi
                </a>

                <p class="text-sm text-gray-500 dark:text-gray-400">{gettext("GitHub")}</p>
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
            <h2 class="text-3xl md:text-4xl font-bold mb-6">
              {gettext("Ready to Experience the Magic?")}
            </h2>

            <p class="text-xl text-white/80 mb-8">
              {gettext(
                "Explore our collections and discover the future of digital library management"
              )}
            </p>

            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <.link
                navigate={~p"/"}
                class="inline-flex items-center justify-center px-8 py-4 bg-white font-semibold rounded-lg shadow-lg hover:bg-gray-50 transition-colors"
                style={"color: #{@app_main_color};"}
              >
                <.icon name="hero-home" class="w-5 h-5 mr-2" /> {gettext("Back to Home")}
              </.link>

              <%= if assigns[:current_scope] && assigns[:current_scope].user do %>
                <.link
                  navigate={~p"/atrium"}
                  class="inline-flex items-center justify-center px-8 py-4 bg-white/20 text-white font-semibold rounded-lg shadow-lg hover:bg-white/30 transition-colors backdrop-blur-sm"
                >
                  <.icon name="hero-user-circle" class="w-5 h-5 mr-2" /> {gettext("Go to Your Atrium")}
                </.link>
              <% else %>
                <.link
                  navigate={~p"/login"}
                  class="inline-flex items-center justify-center px-8 py-4 bg-white/20 text-white font-semibold rounded-lg shadow-lg hover:bg-white/30 transition-colors backdrop-blur-sm"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5 mr-2" /> {gettext(
                    "Get Started"
                  )}
                </.link>
              <% end %>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
