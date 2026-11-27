# Demo of secret_reveal's inline mode: the value is in the page and a click
# shows it without a request.
ActiveAdmin.register_page "Secret reveal" do
  menu false

  content do
    # secret_reveal is opt-in: the page loads its script.
    text_node '<script type="module">import "active_admin_theme/secret_reveal"</script>'.html_safe

    panel "Inline value" do
      div(id: "inline") { secret_reveal value: "inline-s3cr3t" }
    end

    panel "Inline multi-line value" do
      div(id: "multiline") { secret_reveal value: "{\n  \"token\": \"abc\",\n  \"scope\": \"read\"\n}", mask: "{ ... }" }
    end

    panel "Inline value with markup" do
      div(id: "markup") { secret_reveal value: %(<img src="x" onerror="window.injected = true"><b>bold</b>).html_safe }
    end

    panel "Blank inline value" do
      div(id: "blank") { secret_reveal value: nil }
    end

    panel "Fetched value" do
      div(id: "fetched") { secret_reveal url: "/admin/components/secret" }
    end
  end
end
