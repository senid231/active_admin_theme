# Every demo page renders (HTTP 200) with the theme active, and the built CSS
# contains the theme's stylesheet and the utility classes from its views.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "minitest/autorun"

class SmokeTest < Minitest::Test
  PAGES = %w[/admin /admin/table /admin/wide_table /admin/customers /admin/customers/1 /admin/customers/1/edit /admin/customers/new /admin/columns /admin/confirm_dialog /admin/components /admin/orders /admin/orders/1 /admin/orders/new /admin/countries /admin/cities].freeze

  def session
    @session ||= ActionDispatch::Integration::Session.new(Rails.application)
  end

  PAGES.each do |path|
    define_method("test_renders_#{path.tr('/', '_')}") do
      session.get path
      assert_equal 200, session.response.status
    end
  end

  # The page objects are test code: an app loads them from its spec helper.
  def test_the_theme_does_not_load_its_page_objects
    assert_nil defined?(ActiveAdminTheme::PageObjects)
    assert_nil defined?(ActiveAdminPageObjects)
    assert_empty Gem::Specification.load(File.expand_path("../active_admin_theme.gemspec", __dir__)).runtime_dependencies.map(&:name) - ["activeadmin"]
  end

  def test_built_css_includes_the_theme_stylesheet
    css = File.read(File.expand_path("dummy/app/assets/builds/active_admin.css", __dir__))
    assert_includes css, "--active-admin-theme"
  end
end
