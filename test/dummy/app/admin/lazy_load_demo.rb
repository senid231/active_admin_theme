# Demo of lazy_load: placeholders that fetch the fragment below when they
# scroll into view, are in a tab that opens, or are marked eager.
ActiveAdmin.register_page "Lazy load" do
  menu false

  page_action :fragment, method: [:get, :post] do
    html = "<p class=\"fragment\">#{request.request_method} fragment</p><script>window.lazyScriptRan = true</script>"
    render html: html.html_safe, layout: false
  end

  page_action :forbidden, method: :get do
    head :forbidden
  end

  content do
    # lazy_load is opt-in: the page loads its script.
    text_node '<script type="module">import "active_admin_theme/lazy_load"</script>'.html_safe

    panel "In view" do
      div(id: "in-view") { lazy_load url: "/admin/lazy_load/fragment", loading: "Loading the history..." }
    end

    panel "In a tab" do
      tabs do
        tab("Summary") { para "Summary" }
        tab("History") { div(id: "in-tab") { lazy_load url: "/admin/lazy_load/fragment" } }
      end
    end

    panel "Failing" do
      div(id: "failing") { lazy_load url: "/admin/lazy_load/forbidden", error: "Could not load the history" }
    end

    panel "Posted" do
      div(id: "posted") { lazy_load url: "/admin/lazy_load/fragment", method: :post }
    end

    div(style: "height: 3000px")

    panel "Below the fold" do
      div(id: "below") { lazy_load url: "/admin/lazy_load/fragment" }
    end

    panel "Eager, below the fold" do
      div(id: "eager") { lazy_load url: "/admin/lazy_load/fragment", eager: true }
    end
  end
end
