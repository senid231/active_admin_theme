# The engine's rake tasks are defined once. Its own process: loading the tasks
# is global.
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "minitest/autorun"
require "rake"

class RakeTasksTest < Minitest::Test
  def test_the_css_task_runs_once_per_call
    Rails.application.load_tasks
    assert_equal 1, Rake::Task["active_admin_theme:css"].actions.size
  end
end
