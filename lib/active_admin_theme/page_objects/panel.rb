module ActiveAdminTheme
  module PageObjects
    # Included in ActiveAdminPageObjects::Panel: a panel built with
    # `collapsible: true` has a button for a title. The toggling needs a
    # JavaScript driver and the active_admin_theme/panel_toggle script.
    #
    #   panel = page.panel("JSON")
    #   panel.collapsible? # => true
    #   panel.expand
    #   panel.body.text
    module PanelCollapsible
      # True when the title is a toggle button. Does not wait for it.
      def collapsible?
        !toggle_button.nil?
      end

      # True when the body is open. A panel that is not collapsible is always open.
      def expanded?
        button = toggle_button
        button.nil? || button["aria-expanded"] == "true"
      end

      # Opens the body, if closed, and waits for it.
      # @raise [ArgumentError] when the panel is not collapsible
      # @return [self]
      def expand
        change_to(true)
      end

      # Closes the body, if open, and waits for it.
      # @raise [ArgumentError] when the panel is not collapsible
      # @return [self]
      def collapse
        change_to(false)
      end

      # Clicks the title and waits for the body to change.
      # @raise [ArgumentError] when the panel is not collapsible
      # @return [self]
      def toggle
        change_to(!expanded?)
      end

      private

      def toggle_button
        title_node = find(:active_admin, :panel_title, match: :first)
        title_node.first(:active_admin, :panel_toggle, minimum: 0, wait: false)
      end

      def change_to(expanded)
        button = toggle_button || raise(ArgumentError, "the panel is not collapsible")
        button.click unless expanded? == expanded
        return self if eventually { expanded? == expanded }

        raise Capybara::ExpectationNotMet, "the panel did not #{expanded ? "expand" : "collapse"}"
      end
    end
  end
end

ActiveAdminPageObjects::Panel.include(ActiveAdminTheme::PageObjects::PanelCollapsible)
