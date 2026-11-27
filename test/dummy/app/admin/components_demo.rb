# Demo of the opt-in components: status_tag colors, truncate_text,
# secret_reveal, with_tooltip, pre_wrap, notice and the string helpers.
ActiveAdmin.register_page "Components" do
  menu parent: "Demo pages", priority: 6

  page_action :secret, method: :get do
    render json: {value: "s3cr3t"}
  end

  page_action :forbidden, method: :get do
    head :forbidden
  end

  page_action :warning, method: :get do
    messages = {warning: "Check the dates\nbefore you export", notice: "Saved"}
    messages[:info] = "For your information" if params[:extra] == "info"
    redirect_to admin_components_path, flash: messages
  end

  content do
    # A host defines the color of a custom status in its own CSS.
    text_node "<style>:root { --aat-status-shipped: #7c3aed; }</style>".html_safe
    # secret_reveal is opt-in: the page loads its script.
    text_node '<script type="module">import "active_admin_theme/secret_reveal"</script>'.html_safe

    panel "Status tags" do
      div id: "status-tags" do
        %w[ok warning error danger info empty yes shipped unstyled].each { |status| status_tag status }
        %w[green orange red blue].each { |status| status_tag status }
        status_tag false
        status_tag "Late", color: "#b91c1c", id: "status-late"
      end
    end

    panel "Truncate text" do
      long = "A long sentence that does not fit in the space it is given, so it is cut."
      div(id: "truncate-default") { truncate_text long }
      div(id: "truncate-narrow") { truncate_text long, max_width: "8rem" }
      div(id: "truncate-length") { truncate_text long, length: 20 }
      # Inside a scrolling box, as in an index table: the popup must not be clipped.
      div(id: "truncate-popup", style: "overflow: auto; max-width: 12rem;") { truncate_text long, max_width: "8rem", popup: true }
    end

    panel "Table for" do
      div id: "table-for" do
        table_for ["A long value in a show page table, which wraps inside its panel instead of widening the page."] do
          column("Value") { |value| value }
        end
      end
    end

    panel "Sticky rows", id: "sticky-rows" do
      table_for (1..4).to_a, class: "with-sticky-rows" do
        (1..10).each { |c| column("Column #{c}") { |r| "row #{r} / a fairly long value #{c}" } }
      end
    end

    panel "Secret reveal" do
      div(id: "secret") { secret_reveal url: "/admin/components/secret" }
    end

    panel "Tooltips" do
      div id: "tooltips" do
        span(id: "tooltip-title") { text_node with_tooltip("Hover for a title", "Plain title tooltip") }
        text_node " "
        span(id: "tooltip-html") { text_node with_tooltip("Hover for HTML", "<strong>Rich</strong> tooltip<script>alert(1)</script>", html: true) }
      end
    end

    panel "Pre wrap" do
      div id: "pre-wrap" do
        text_node pre_wrap("first line\n" + "x" * 400)
      end
      div id: "pre-wrap-capped" do
        text_node pre_wrap((1..40).map { |n| "line #{n}" }.join("\n"), max_height: "6rem")
      end
      div id: "pre-wrap-capped-px" do
        text_node pre_wrap((1..40).map { |n| "line #{n}" }.join("\n"), max_height: 90)
      end
      div id: "pre-wrap-blank" do
        attributes_table_for ActiveSupport::OrderedOptions.new.merge!(payload: "  ") do
          row(:payload) { |record| pre_wrap(record.payload) }
        end
      end
    end

    panel "Notices" do
      div id: "notices" do
        %i[info success warning danger].each { |kind| notice "A #{kind} notice", kind: kind }
        notice("A notice with no kind") { para "and a body", class: "notice-body" }
      end
      div(id: "notice-string") { text_node notice_tag("A notice from the string helper", kind: :warning) }
    end

    panel "String helpers" do
      div id: "string-helpers" do
        text_node status_tag_tag("Late", color: "#b91c1c", label: "Overdue")
        text_node " "
        text_node secret_reveal_tag(value: "helper-s3cr3t")
        text_node " "
        text_node aat_arbre { span "From aat_arbre", class: "from-arbre" }
      end
    end
  end
end
