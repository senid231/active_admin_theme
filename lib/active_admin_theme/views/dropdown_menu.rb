require_relative "tabs"

module ActiveAdminTheme
  module Views
    # Flowbite's dropdown sets no aria-expanded and ignores Escape; the
    # active_admin_theme/dropdown_menu script adds both.
    class DropdownMenu < ActiveAdmin::Component
      builder_method :dropdown_menu

      CARET = '<svg class="aat-dropdown-caret" aria-hidden="true" fill="none" viewBox="0 0 10 6">' \
        '<path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 4 4 4-4"/></svg>'.freeze

      def build(label, options = {})
        options = options.dup
        button_options = (options.delete(:button) || {}).to_h.symbolize_keys
        menu_options = (options.delete(:menu) || {}).to_h.symbolize_keys
        placement = options.delete(:placement) || "bottom-end"
        id = options.delete(:id)
        super(options)
        add_class "aat-dropdown"

        slug = label.to_s.parameterize
        menu_id = id ? Tabs.claim_id(helpers, id.to_s) : Tabs.unique_id(helpers, ["aat-dropdown", slug.presence].compact.join("-"))
        button id: "#{menu_id}-toggle", **button_options, type: "button",
          class: ["aat-dropdown-toggle", "action-item-button", button_options[:class]].compact.join(" "),
          "aria-haspopup": "menu", "aria-expanded": "false", "aria-controls": menu_id,
          "data-dropdown-toggle": menu_id, "data-dropdown-placement": placement, "data-dropdown-offset-distance": "4" do
          text_node label.to_s
          text_node CARET.html_safe
        end
        @menu = ul id: menu_id, **menu_options, role: "menu", "aria-labelledby": "#{menu_id}-toggle",
          class: ["aat-dropdown-menu hidden", menu_options[:class]].compact.join(" ")
      end

      def item(text, url = "#", options = nil, **link_options)
        attributes = {role: "menuitem"}.merge((options || {}).to_h.symbolize_keys, link_options)
        li(role: "none") { text_node helpers.link_to(text, url, attributes) }
      end

      def add_child(child)
        @menu ? @menu.add_child(child) : super
      end
    end
  end

  module Helpers
    module DropdownMenu
      # The component as a string, for blocks that return one, such as `action_item`.
      # `items` is an array of [text, url, link_options]; no items and no block render nothing.
      def dropdown_menu_tag(label, items = nil, **options, &block)
        return "".html_safe if items.blank? && block.nil?

        Arbre::Context.new({}, self) do
          body = block && proc { instance_exec(&block) }
          dropdown_menu(label, options) do
            Array(items).each { |text, url, link_options| item(text, url, link_options) }
            body&.call
            nil
          end
        end.to_s.html_safe
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::DropdownMenu }
