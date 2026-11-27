# `find(:active_admin_sidebar, "Stats")` is the base gem's :active_admin_panel
# limited to the panels of the sidebar, for
# `section :stats, ActiveAdminPageObjects::Panel, :active_admin_sidebar, "Stats"`.
# The title is a String (case-insensitive) or a Regexp.
Capybara.add_selector(:active_admin_sidebar) do
  css { |_title| ActiveAdminPageObjects.selector(:sidebar_section) }
  locator_filter do |node, title|
    next true if title.nil?

    # The panel's own title comes before the titles of panels nested in its body.
    own = node.first(:css, ActiveAdminPageObjects.selector(:panel_title), visible: :all, minimum: 0, wait: false)
    own && ActiveAdminPageObjects.text_match?(own.text(:all), title)
  end
end

module ActiveAdminTheme
  module PageObjects
    # The sidebar. The theme puts every sidebar section, the filters included,
    # in a panel titled with the section name.
    #
    #   index.sidebar.titles # => ["Filters"]
    #   show.sidebar.panel("Help").body.text
    class Sidebar < ActiveAdminPageObjects::Section
      selector_key :sidebar

      # The titles of the sidebar sections in document order.
      # @return [Array<String>]
      def titles
        all(:active_admin, :panel_title, wait: false).map { |title| title.text.strip }
      end

      # The sidebar section titled +title+: a String (case-insensitive) or a Regexp.
      # @return [ActiveAdminPageObjects::Panel]
      def panel(title)
        ActiveAdminPageObjects::Panel.new(self, find(:active_admin_sidebar, title))
      end

      # True when the sidebar has a section titled +title+.
      def has_panel?(title, **options)
        has_selector?(:active_admin_sidebar, title, **options)
      end

      # Waits until the sidebar has no section titled +title+.
      def has_no_panel?(title, **options)
        has_no_selector?(:active_admin_sidebar, title, **options)
      end
    end
  end
end
