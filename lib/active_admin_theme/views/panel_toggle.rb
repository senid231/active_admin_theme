module ActiveAdminTheme
  module Views
    # panel "JSON", collapsible: true do ... end
    # panel "JSON", collapsible: true, collapsed: true do ... end
    #
    # The title becomes a button (aria-expanded, aria-controls) that shows and
    # hides the body. collapsed: true renders the body hidden, so the page does
    # not flash it. A panel without collapsible: is unchanged, collapsed: or
    # not. Prepended to ActiveAdmin's Panel, so it works in a sidebar too.
    #
    # Needs the opt-in module active_admin_theme/panel_toggle; see
    # ActiveAdminTheme.javascripts. The script sends a bubbling
    # `aat:panel:toggle` event with detail { panel, expanded }.
    module PanelToggle
      CHEVRON = '<svg class="aat-panel-chevron" aria-hidden="true" fill="none" viewBox="0 0 10 6">' \
        '<path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 4 4 4-4"/></svg>'.freeze

      def build(title, attributes = {})
        attributes = attributes.dup
        collapsible = attributes.delete(:collapsible)
        collapsed = attributes.delete(:collapsed)

        super(title, attributes)
        make_collapsible(title, attributes[:id], collapsed) if collapsible
      end

      private

      def make_collapsible(title, id, collapsed)
        base = id ? Tabs.claim_id(helpers, id.to_s) : Tabs.unique_id(helpers, "aat-panel-#{title.to_s.parameterize.presence || "panel"}")
        add_class "aat-panel-collapsible"
        @contents.set_attribute "id", "#{base}-body"
        @contents.set_attribute "role", "region"
        @contents.set_attribute "aria-labelledby", "#{base}-toggle"
        @contents.set_attribute "hidden", "" if collapsed
        @title.children.clear
        with_current_arbre_element(@title) do
          button(type: "button", class: "aat-panel-toggle", id: "#{base}-toggle", "data-aat-panel-toggle": "",
                 "aria-expanded": (!collapsed).to_s, "aria-controls": "#{base}-body") do
            span title.to_s, class: "aat-panel-toggle-title"
            text_node CHEVRON.html_safe
          end
        end
      end
    end

    ActiveAdmin::Views::Panel.prepend(PanelToggle)
  end
end
