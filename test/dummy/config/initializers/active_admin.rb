ActiveAdmin.setup do |config|
  config.site_title = "ActiveAdmin Theme Demo"

  # No devise: the dummy only renders themed pages. A fake signed-in user makes
  # the header show the clock, user name, and logout icon.
  config.authentication_method = false
  config.current_user_method = :current_admin_user
  config.logout_link_path = "/admin"

  # No ActiveRecord-backed comments, so the app needs no schema.
  config.comments = false
end

# The optional modules the demo pages use.
ActiveAdminTheme.javascripts += %w[
  active_admin_theme/secret_reveal
]

# test/layout_test.rb: the footer and the title link.
ActiveAdminTheme.footer_product_name = "Theme Demo"
ActiveAdminTheme.footer_version = "1.2.3"
ActiveAdminTheme.footer_extra = -> { link_to("Changelog", admin_root_path) }
ActiveAdminTheme.site_title_link = -> { admin_root_path }

# test/searchable_select_off_test.rb
ActiveAdminTheme.searchable_select_all = false if ENV["SEARCHABLE_SELECT_ALL"] == "0"
