# A host's own searchable_select_options wins over the theme's, whether the host
# defines it before the theme's initializer (a gem, another engine) or after it
# (an initializer of the app). Each case boots the dummy app in a process of
# its own; test/dummy/config/application.rb reads HOST_DSL.
require "minitest/autorun"
require "open3"
require "rbconfig"

class HostDslTest < Minitest::Test
  SCRIPT = <<~RUBY.freeze
    require "./test/dummy/config/environment"
    Rails.application.reload_routes!
    print ActiveAdmin::ResourceDSL.instance_method(:searchable_select_options).owner
  RUBY

  def owner(host_dsl)
    out, status = Open3.capture2e({"HOST_DSL" => host_dsl, "RAILS_ENV" => "test"}, RbConfig.ruby, "-e", SCRIPT, chdir: File.expand_path("..", __dir__))
    assert status.success?, out
    out.lines.last
  end

  def test_the_theme_defines_it_when_the_host_does_not
    assert_equal "ActiveAdminTheme::SearchableSelect::ResourceDSL", owner(nil)
  end

  def test_a_host_definition_loaded_before_the_theme_wins
    assert_equal "HostSearchableSelect", owner("before")
  end

  def test_a_host_definition_loaded_after_the_theme_wins
    assert_equal "HostSearchableSelect", owner("after")
  end
end
