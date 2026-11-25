module ActiveAdminTheme
  module PageObjects
    # Included into ActiveAdminPageObjects::Layout, so every page gets the
    # lookups of the theme's components and the sidebar switch.
    module Layout
      # The confirm dialog whose trigger button reads +trigger+, the one whose
      # modal has the id +dialog+, or the only one.
      # @return [ConfirmDialog]
      def confirm_dialog(trigger = nil, dialog: nil)
        ConfirmDialog.find_in(self, trigger, dialog: dialog)
      end

      # Hides the sidebar with the switch next to the page title (desktop).
      def collapse_sidebar
        find(:active_admin, :sidebar_toggle).click unless sidebar_collapsed?
        has_css?(ActiveAdminPageObjects.selector(:sidebar_collapsed))
      end

      # Shows the sidebar again.
      def expand_sidebar
        find(:active_admin, :sidebar_toggle).click if sidebar_collapsed?
        has_no_css?(ActiveAdminPageObjects.selector(:sidebar_collapsed))
      end

      # True when the sidebar is collapsed. Does not wait.
      def sidebar_collapsed?
        has_css?(ActiveAdminPageObjects.selector(:sidebar_collapsed), wait: false)
      end
    end
  end
end

ActiveAdminPageObjects::Layout.include(ActiveAdminTheme::PageObjects::Layout)

# The header shows the signed-in user and a logout icon in place of
# ActiveAdmin's user menu, so `user_menu_button` is never on a theme page.
ActiveAdminPageObjects::Layout.add_element(:current_user, :active_admin, :current_user)
ActiveAdminPageObjects::Layout.add_element(:logout_link, :active_admin, :logout_link)
ActiveAdminPageObjects::Layout.add_element(:server_clock, :active_admin, :server_clock)
ActiveAdminPageObjects::Layout.add_element(:main_menu_button, :active_admin, :main_menu_button)
ActiveAdminPageObjects::Layout.add_element(:sidebar_toggle, :active_admin, :sidebar_toggle)

# rack_test sees the top menu and the drawer; a browser shows one of them.
ActiveAdminPageObjects::Layout.add_section(:main_menu, ActiveAdminPageObjects::MainMenu, :active_admin, :main_menu, match: :first)
ActiveAdminPageObjects::Layout.add_section(:sidebar, ActiveAdminTheme::PageObjects::Sidebar)
ActiveAdminPageObjects::Layout.add_section(:tabs, ActiveAdminPageObjects::Tabs)
