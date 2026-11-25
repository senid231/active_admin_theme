# Every demo page renders (HTTP 200) with the theme active, and the built CSS
# contains the theme's stylesheet and the utility classes from its views.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "minitest/autorun"

class SmokeTest < Minitest::Test
  PAGES = %w[/admin /admin/table /admin/wide_table /admin/customers /admin/customers/1 /admin/customers/1/edit /admin/customers/new /admin/columns /admin/confirm_dialog /admin/components /admin/orders /admin/orders/1 /admin/orders/new /admin/countries /admin/cities /admin/shipments /admin/shipments/1 /admin/shipments/new /admin/shipments/1/edit /admin/products /admin/streets /admin/select_lab].freeze

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

  def test_select_texts_come_from_i18n
    I18n.backend.store_translations(:en, active_admin_theme: {searchable_select: {no_results: "Nothing <found>"}})
    session.get "/admin/customers"
    json = session.response.body[%r{<script type="application/json" id="active-admin-theme-config">(.*?)</script>}m, 1]
    refute_includes json, "<"
    config = JSON.parse(json).fetch("searchableSelect")
    assert_equal({"all" => true, "minChars" => 3}, config.slice("all", "minChars"))
    assert_equal "Nothing <found>", config.dig("texts", "noResults")
    assert_equal "Type %{count} chars to search...", config.dig("texts", "typeToSearch")
  ensure
    I18n.backend.reload!
  end

  def test_built_css_includes_the_theme_stylesheet
    css = File.read(File.expand_path("dummy/app/assets/builds/active_admin.css", __dir__))
    assert_includes css, "--active-admin-theme"
  end
end
