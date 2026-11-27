# Settings a host reads without a browser: the Sprockets precompile list, the
# Tailwind sources, and the default script list. The dummy uses Propshaft, so
# the precompile list is checked as data, not by booting Sprockets.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "minitest/autorun"
require "tmpdir"
require "rake"

class EngineSetupTest < Minitest::Test
  def test_sprockets_precompile_lists_the_theme_scripts_and_vendored_libraries
    list = ActiveAdminTheme::Engine.sprockets_precompile
    assert_includes list, "active_admin_theme/layout.js"
    assert_includes list, "active_admin_theme/confirm_dialog.js"
    assert_includes list, "tom-select.js"
  end

  def test_sprockets_precompile_covers_every_theme_pin
    list = ActiveAdminTheme::Engine.sprockets_precompile
    theme_dir = ActiveAdminTheme::Engine.root.join("app/javascript/active_admin_theme").to_s
    pinned = ActiveAdmin.importmap.directories.select { |path, _| path == theme_dir }
    assert_equal 1, pinned.size
    modules = Dir[File.join(theme_dir, "*.js")].map { |file| "active_admin_theme/#{File.basename(file)}" }
    refute_empty modules
    assert_empty modules - list
    assert_equal "tom-select.js", ActiveAdmin.importmap.packages.fetch("tom-select").path
    assert_includes list, "tom-select.js"
  end

  def test_propshaft_hosts_get_no_precompile_entries
    refute_includes Rails.application.config.assets.precompile, "active_admin_theme/layout.js"
  end

  def test_confirm_dialog_loads_by_default
    assert_includes ActiveAdminTheme::DEFAULT_JAVASCRIPTS, "active_admin_theme/confirm_dialog"
    assert_includes ActiveAdminTheme.javascripts, "active_admin_theme/confirm_dialog"
  end

  def test_tailwind_content_globs_the_views_ruby_and_scripts
    root = ActiveAdminTheme::Engine.root.to_s
    assert_equal ["#{root}/app/**/*.{arb,erb,html,rb,js}", "#{root}/lib/**/*.rb"], ActiveAdminTheme.tailwind_content
  end

  def test_tailwind_sources_are_source_lines
    lines = ActiveAdminTheme.tailwind_sources
    assert_equal ActiveAdminTheme.tailwind_content.map { |glob| %(@source "#{glob}";) }, lines
  end

  def test_tailwind_sources_relative_to_a_directory
    Dir.mktmpdir do |dir|
      lines = ActiveAdminTheme.tailwind_sources(relative_to: dir)
      glob = lines.first[/@source "(.*)";/, 1]
      refute glob.start_with?("/"), "expected a relative path, got #{glob}"
      assert_equal ActiveAdminTheme.tailwind_content.first, File.expand_path(glob, dir)
    end
  end

  def test_the_sources_task_writes_a_file_relative_to_it
    Rails.application.load_tasks unless Rake::Task.task_defined?("active_admin_theme:tailwind:sources")
    Dir.mktmpdir do |dir|
      file = File.join(dir, "app/assets/stylesheets/active_admin_theme.sources.css")
      with_env("ACTIVE_ADMIN_THEME_SOURCES" => file) do
        out, = capture_io { Rake::Task["active_admin_theme:tailwind:sources"].execute }
        assert_match(/written/, out)
        assert_match(%r{^@source "\.\./.*/app/\*\*/\*\.\{arb,erb,html,rb,js\}";$}, File.read(file))
        out, = capture_io { Rake::Task["active_admin_theme:tailwind:sources"].execute }
        assert_match(/up to date/, out)
      end
    end
  end

  def test_the_sources_task_prints_without_a_file
    Rails.application.load_tasks unless Rake::Task.task_defined?("active_admin_theme:tailwind:sources")
    with_env("ACTIVE_ADMIN_THEME_SOURCES" => nil) do
      out, = capture_io { Rake::Task["active_admin_theme:tailwind:sources"].execute }
      assert_equal ActiveAdminTheme.tailwind_sources.join("\n") + "\n", out
    end
  end

  def test_the_footer_keeps_powered_by_when_nothing_is_set
    html = with_settings(footer_product_name: nil, footer_version: nil, footer_extra: nil) { render_footer }
    assert_includes html, "Active Admin"
    refute_includes html, "data-aat-footer-product"
  end

  def test_the_footer_shows_the_product_and_runs_extra_in_the_view
    settings = {footer_product_name: "Acme", footer_version: "2.0", footer_extra: -> { link_to("Notes", "/notes") }}
    html = with_settings(settings) { render_footer }
    assert_includes html, ">Acme 2.0<"
    assert_includes html, %(<a href="/notes">Notes</a>)
    refute_includes html, "Powered by"
  end

  def test_a_plain_string_extra_is_escaped
    html = with_settings(footer_product_name: nil, footer_version: nil, footer_extra: "<b>x</b>") { render_footer }
    assert_includes html, "&lt;b&gt;x&lt;/b&gt;"
  end

  private

  def render_footer
    ApplicationController.render(partial: "active_admin/site_footer")
  end

  def with_settings(settings)
    saved = settings.keys.to_h { |key| [key, ActiveAdminTheme.public_send(key)] }
    settings.each { |key, value| ActiveAdminTheme.public_send("#{key}=", value) }
    yield
  ensure
    saved.each { |key, value| ActiveAdminTheme.public_send("#{key}=", value) }
  end

  def with_env(values)
    saved = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
