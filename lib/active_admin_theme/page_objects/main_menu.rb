module ActiveAdminTheme
  module PageObjects
    # Prepended to ActiveAdminPageObjects::MainMenu. The theme has two menus,
    # both nested to any depth: the top menu, whose submenus open on hover, and
    # the drawer of a narrow screen, whose submenus open with a toggle button.
    # The section's root is the one on screen.
    module MainMenuPatch
      # A submenu of the top menu sits in a `div` next to its link.
      ITEM_XPATH = "./ul/li | ./div/ul/li".freeze
      # A drawer parent without a URL has a `span` for a label.
      LABEL_XPATH = "./a | ./div/a | ./div/span".freeze
      LINK_XPATH = "./a | ./div/a".freeze

      # Opens the drawer first when the menu is the drawer.
      def click(*labels)
        open_drawer if drawer?
        super
      end

      # A parent without a URL links to "#", which a browser resolves to the current page.
      def go(*labels)
        link = find_item(labels)&.first(:xpath, LINK_XPATH, visible: :all, minimum: 0)
        raise ArgumentError, "menu item #{labels.inspect} has no link" if link && href_attribute(link) == "#"

        super
      end

      private

      def drawer?
        root_element[:id] == "main-menu"
      end

      # Flowbite marks the open drawer as a modal; closed, it is off screen.
      def drawer_closed?
        root_element["aria-modal"] != "true"
      end

      def open_drawer
        return unless drawer_closed?

        root_element.session.find(:active_admin, :main_menu_button).click
        eventually { !drawer_closed? }
      end

      def children(scope)
        scope.all(:xpath, ITEM_XPATH, visible: :all, wait: false)
      end

      def visible_item(scope, label, path)
        scope.all(:xpath, ITEM_XPATH, wait: false).find { |li| same_text?(label_of(li), label) } ||
          raise(Capybara::ElementNotFound, "no visible menu item #{label.inspect} in #{path.inspect}")
      end

      def label_of(item)
        item.first(:xpath, LABEL_XPATH, visible: :all, minimum: 0)&.text(:all).to_s.strip
      end

      # The top menu opens a submenu when the pointer is on its item. rack_test
      # applies no CSS, so every submenu is already visible there.
      def expand(item)
        return super if drawer?

        item.first(:xpath, LINK_XPATH, wait: false).hover
        item
      rescue NotImplementedError, Capybara::NotSupportedByDriverError
        item
      end

      # The top menu marks every ancestor of the current item, so take the deepest one.
      def current_path_in(scope)
        children(scope).each do |li|
          nested = current_path_in(li)
          return [li, *nested] if nested
          return [li] if selected_item?(li)
        end
        nil
      end

      def selected_item?(item)
        link = item.first(:xpath, LINK_XPATH, visible: :all, minimum: 0)
        !link.nil? && link.matches_css?(sel(:main_menu_selected), wait: false)
      end
    end
  end
end

ActiveAdminPageObjects::MainMenu.prepend(ActiveAdminTheme::PageObjects::MainMenuPatch)
