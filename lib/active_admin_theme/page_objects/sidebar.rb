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
        ActiveAdminPageObjects::Panel.new(self, find(:active_admin_panel, title))
      end

      # True when the sidebar has a section titled +title+.
      def has_panel?(title, **options)
        has_selector?(:active_admin_panel, title, **options)
      end

      # Waits until the sidebar has no section titled +title+.
      def has_no_panel?(title, **options)
        has_no_selector?(:active_admin_panel, title, **options)
      end
    end
  end
end
