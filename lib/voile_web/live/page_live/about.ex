defmodule VoileWeb.PageLive.About do
  use VoileWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <section class="text-center max-w-7xl mx-auto">
        <h1 class="pb-5">Tentang Voile</h1>
        
        <.modal id="about-modal">
          <h3>
            <%= if assigns[:current_scope] && assigns[:current_scope].user do %>
              Hey there, {@current_scope.user.username}!
            <% else %>
              Hey there, visitor!
            <% end %>
          </h3>
          
          <p class="text-justify">
            Lorem ipsum dolor sit amet consectetur, adipisicing elit. Sit praesentium voluptatum minus quibusdam enim fugit aperiam tempora. Voluptates facilis commodi pariatur! Tenetur qui similique nobis nulla, atque fugiat ratione id obcaecati autem asperiores illum unde, nostrum eos vel harum mollitia. Inventore consequatur quasi, ut culpa laudantium libero quod assumenda est!
          </p>
        </.modal>
        
        <p class="text-justify px-5 lg:px-3">
          Lorem ipsum dolor sit amet consectetur, adipisicing elit. Tempore quasi dolorem delectus nulla excepturi quibusdam illum quia harum beatae alias culpa iusto, ex hic in est? Aliquam veritatis quae dolore quisquam. Totam, blanditiis ea adipisci a vel eum recusandae sapiente rem quas doloremque, distinctio excepturi quisquam accusamus quam dicta? Facilis quibusdam tenetur reprehenderit porro ea tempore aliquam error dignissimos sint nulla! Accusamus officiis perspiciatis dignissimos vero quo aliquam? Minus ipsa veritatis quod repellat dolores fugit quaerat minima rerum, consequuntur debitis sit consequatur laudantium corrupti maiores ratione ipsum quisquam impedit. Debitis, itaque sapiente possimus eligendi omnis culpa quos quod laudantium. Est mollitia, exercitationem inventore adipisci reiciendis pariatur? Asperiores quasi quos suscipit minima rerum, commodi perspiciatis illo nesciunt sunt in sed voluptate veritatis? In placeat eaque consectetur itaque, rerum, minus vero atque consequuntur aut suscipit laudantium aperiam? Ad libero autem facilis dolorem nihil corrupti quasi architecto nam molestiae. Modi, dolores molestias quisquam beatae id doloribus impedit consequatur quo quasi nisi. Reiciendis expedita accusamus corrupti ipsam. Et labore praesentium minima quidem. Itaque corporis eveniet iusto qui nobis quibusdam minus impedit numquam repudiandae, quos ab ullam praesentium. Rerum odio libero explicabo illum autem. Doloremque obcaecati voluptate, dolorum ipsum expedita illo ducimus asperiores facilis dolorem tempora? Optio saepe aut vel ea dolorum, sapiente debitis deleniti quod voluptatem eius dolor fugit numquam natus laboriosam rem sunt! Aperiam sint consectetur neque reiciendis ipsum, blanditiis eaque, voluptas aliquam ratione natus animi ad suscipit dolor, eligendi iusto esse sit. Libero quasi repellendus nemo soluta sequi! Necessitatibus porro natus illum officiis consequatur quasi voluptatum odit, tempora autem magnam, deserunt inventore fuga, perspiciatis non. Blanditiis omnis exercitationem, eum fuga officia sequi ad, corrupti reiciendis laudantium doloribus qui reprehenderit inventore! Temporibus quaerat tenetur totam maiores maxime fugit magni harum? Laudantium molestiae rem commodi sit sequi fugiat nam amet, optio illo! Nemo aliquam eaque, aut odit, debitis mollitia vitae magnam, ratione iste ut assumenda eos rem architecto culpa odio maxime doloribus illo a explicabo. Cupiditate recusandae sint vel, itaque odit quisquam alias eos ducimus aliquid qui consequuntur at neque sit dicta molestiae. Magnam quos eius provident veniam, blanditiis quasi sed quibusdam inventore. Quisquam totam magnam nulla, a doloribus libero recusandae nobis. Voluptate magni asperiores corporis accusantium explicabo, ipsa expedita eum modi voluptates illo nam laudantium temporibus debitis pariatur rem? Laudantium quas aut quibusdam, nihil voluptas, libero harum quasi velit veritatis odit distinctio deserunt aperiam placeat, et illo dolorum. Provident reiciendis architecto cupiditate. Aut possimus illum, similique assumenda nulla placeat saepe incidunt veniam iste quae ut inventore distinctio laborum ad porro, aliquam provident dolorum error animi iure quos cumque, perferendis voluptatibus minus. Nobis laborum, voluptate reiciendis vitae odit quia fuga itaque repellat dolore explicabo eos ratione iure, ab nesciunt veritatis ducimus officia voluptatibus quas sed, dicta sit? Animi asperiores sint, quam neque praesentium atque quo voluptate hic consectetur nam perspiciatis id fugit aspernatur voluptatum sapiente itaque ipsam, libero esse excepturi in. Illum eaque velit expedita optio omnis fuga magnam quae? Ipsa assumenda rem modi necessitatibus? Quis corporis impedit quae ex sed assumenda explicabo eius laborum ab accusamus. Autem maxime, a expedita accusamus rem deleniti deserunt eum at, facere quae quam maiores, quasi ut? Animi quaerat amet nemo in, facilis omnis nisi cumque, sint perspiciatis ea, velit rem vero provident ratione porro labore corrupti repellat consequatur. Doloremque beatae eius explicabo laudantium non, et fuga minus laborum soluta, neque architecto aliquid qui perferendis! Totam fugiat aut rem accusantium quasi corrupti beatae perferendis qui ut laudantium cumque iste, soluta autem, quaerat dolores aliquid corporis sequi saepe praesentium porro voluptas! Veniam inventore eum odio ad, doloribus, voluptatibus dolores eos totam exercitationem esse, earum placeat alias reprehenderit sed odit delectus est molestias vel consectetur. Saepe aut est at repellat hic, earum qui debitis quibusdam distinctio magnam impedit unde sint, a ullam rem blanditiis ex quasi deleniti exercitationem? Numquam, recusandae? Amet facilis asperiores officia adipisci vitae praesentium eveniet modi quam blanditiis reprehenderit repellendus, quas neque ullam culpa aliquid ad delectus? Cum perferendis incidunt minima! Minus vero facilis placeat? In cumque odio illo iure sint ullam aperiam rem nesciunt perferendis debitis aliquid, maiores nostrum non at, exercitationem commodi natus expedita facilis vel itaque sit. Natus sequi totam laboriosam commodi nulla?
        </p>
        
        <div class="mt-8 space-y-4">
          <.button phx-click={show_modal("about-modal")} class="primary-btn">Open Modal</.button>
          <div>
            <.link
              navigate={~p"/"}
              class="inline-flex items-center text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Kembali
            </.link>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
