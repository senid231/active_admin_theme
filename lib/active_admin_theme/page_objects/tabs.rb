module ActiveAdminTheme
  module PageObjects
    # Prepended to ActiveAdminPageObjects::Tabs, which is empty because
    # ActiveAdmin 4 has no tabs. Drives the theme's `tabs` component.
    #
    #   show.tabs.titles # => ["Notes", "Raw"]
    #   show.tabs.select("Raw")
    #   show.tabs.select(/\ARaw/)
    #   show.tabs.content.text
    module TabsPatch
      # The tab titles in document order.
      # @return [Array<String>]
      def titles
        tab_buttons.map { |button| button.text.strip }
      end

      # Clicks the tab titled +title+: a String is the whole title, ignoring
      # case, and a Regexp matches the title text. Every method that takes a
      # +title+ reads it this way.
      def select(title)
        tab_button(title).click
      end

      alias select_matching select

      # The title of the selected tab.
      # @return [String, nil]
      def selected
        tab_buttons.find { |button| button["aria-selected"] == "true" }&.text&.strip
      end

      # True when the tab titled +title+ is the selected one.
      def has_selected?(title, **options)
        eventually(**options) { text_match?(selected, title) }
      end

      # Waits until the tab titled +title+ is not the selected one.
      def has_no_selected?(title, **options)
        eventually(**options) { !text_match?(selected, title) }
      end

      # True when the component has a tab titled +title+.
      def has_tab?(title, **options)
        eventually(**options) { find_tab_button(title) }
      end

      # Waits until the component has no tab titled +title+.
      def has_no_tab?(title, **options)
        eventually(**options) { find_tab_button(title).nil? }
      end

      # The content node of the tab titled +title+, or of the selected tab.
      # The content of another tab is hidden: read it with `text(:all)`.
      # @return [Capybara::Node::Element]
      def content(title = nil)
        button = title ? tab_button(title) : tab_buttons.find { |tab| tab["aria-selected"] == "true" }
        raise Capybara::ElementNotFound, "no selected tab in #{titles.inspect}" unless button

        find(:id, button["aria-controls"], visible: :all)
      end

      private

      # The first tab list is this component's: one nested in a tab comes later.
      def tab_buttons
        find(:active_admin, :tabs_nav, match: :first).all(:active_admin, :tab, wait: false)
      end

      def find_tab_button(title)
        tab_buttons.find { |button| text_match?(button.text, title) }
      end

      def tab_button(title)
        find_tab_button(title) || raise(Capybara::ElementNotFound, "no tab #{title.inspect} in #{titles.inspect}")
      end
    end
  end
end

ActiveAdminPageObjects::Tabs.prepend(ActiveAdminTheme::PageObjects::TabsPatch)
