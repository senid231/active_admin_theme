# Page objects for the theme, built on the active_admin_page_objects gem.
# Test code only: load it from a spec helper with
#   require "active_admin_theme/page_objects"
# The theme itself never requires this file, and the gemspec does not depend
# on active_admin_page_objects.
require "active_admin_page_objects"

ActiveAdminPageObjects.check_version!(">= 2.0.0.a", "< 3.0.0.a", plugin: "active_admin_theme")

module ActiveAdminTheme
  module PageObjects
  end
end

require "active_admin_theme/page_objects/selectors"
require "active_admin_theme/page_objects/component"
require "active_admin_theme/page_objects/main_menu"
require "active_admin_theme/page_objects/tabs"
require "active_admin_theme/page_objects/sidebar"
require "active_admin_theme/page_objects/searchable_select"
require "active_admin_theme/page_objects/confirm_dialog"
require "active_admin_theme/page_objects/secret_reveal"
require "active_admin_theme/page_objects/status_tag"
require "active_admin_theme/page_objects/truncate_text"
require "active_admin_theme/page_objects/tooltip"
require "active_admin_theme/page_objects/pre_wrap"
require "active_admin_theme/page_objects/columns"
require "active_admin_theme/page_objects/layout"
