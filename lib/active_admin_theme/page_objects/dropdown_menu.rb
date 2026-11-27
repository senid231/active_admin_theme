module ActiveAdminTheme
  module PageObjects
    # The `dropdown_menu` component: a button and its list of links. Needs a
    # JavaScript driver. It stands in for ActiveAdmin 3's action item dropdown.
    #
    #   menu = page_object.action_items.dropdown("Export")
    #   menu.items # => ["CSV", "JSON"]
    #   menu.click("CSV")
    class DropdownMenu < Component
      selector_key :dropdown_menu

      class << self
        # The dropdown inside +scope+ whose button reads +label+
        # (case-insensitive), or the only dropdown when +label+ is nil.
        def find_in(scope, label = nil, **options)
          return super(scope, **options) if label.nil?

          node = scope.find(*default_search_arguments, **options) do |root|
            button = root.first(:active_admin, :dropdown_menu_toggle, minimum: 0, wait: false)
            button && ActiveAdminPageObjects.same_text?(button.text, label)
          end
          new(scope, node)
        end
      end

      # The text of the button.
      # @return [String]
      def label
        toggle.text.strip
      end

      # The texts of the links in document order, shown or not.
      # @return [Array<String>]
      def items
        all(:active_admin, :dropdown_menu_item, visible: :all, wait: false).map { |link| link.text(:all).strip }
      end

      # True when the dropdown has a link reading +text+ (case-insensitive).
      def has_item?(text, **options)
        eventually(**options) { find_item(text) }
      end

      def has_no_item?(text, **options)
        eventually(**options) { !find_item(text) }
      end

      # The link reading +text+.
      # @return [Capybara::Node::Element]
      def item(text)
        find_item(text) || raise(Capybara::ElementNotFound, "no dropdown item #{text.inspect} in #{items.inspect}")
      end

      # Opens the list, if closed, and clicks the link reading +text+.
      def click(text)
        open
        item(text).click
      end

      # Clicks the button and waits for the list.
      def open
        toggle.click unless open?
        menu
        self
      end

      # Closes the list, if open, and waits for it to go.
      def close
        toggle.click if open?
        has_no_open?
        self
      end

      # True when the list is on screen. Does not wait.
      def open?
        has_css?(sel(:dropdown_menu_menu), visible: true, wait: false)
      end

      # True when the list is on screen.
      def has_open?(**options)
        has_css?(sel(:dropdown_menu_menu), visible: true, **options)
      end

      # Waits until the list is closed.
      def has_no_open?(**options)
        has_no_css?(sel(:dropdown_menu_menu), visible: true, **options)
      end

      # The button.
      # @return [Capybara::Node::Element]
      def toggle
        find(:active_admin, :dropdown_menu_toggle)
      end

      private

      def menu
        find(:active_admin, :dropdown_menu_menu, visible: true)
      end

      def find_item(text)
        all(:active_admin, :dropdown_menu_item, visible: :all, wait: false).find { |link| same_text?(link.text(:all), text) }
      end
    end

    # Prepended to ActiveAdminPageObjects::ActionItems, whose `dropdown` is the
    # ActiveAdmin 3 one and raises on ActiveAdmin 4.
    module ActionItemsDropdown
      # The dropdown labelled +label+, or the only one.
      # @return [DropdownMenu]
      def dropdown(label = nil)
        DropdownMenu.find_in(self, label)
      end
    end

    module DropdownMenuLayout
      # The dropdown whose button reads +label+, or the only one on the page.
      # @return [DropdownMenu]
      def dropdown_menu(label = nil)
        DropdownMenu.find_in(self, label)
      end
    end
  end
end

ActiveAdminPageObjects::ActionItems.prepend(ActiveAdminTheme::PageObjects::ActionItemsDropdown)
ActiveAdminPageObjects::Layout.include(ActiveAdminTheme::PageObjects::DropdownMenuLayout)
