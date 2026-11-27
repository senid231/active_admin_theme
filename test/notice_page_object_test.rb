# Browser test (headless Chrome): the Notice page object reads the notice component.
require_relative "page_objects_helper"

class NoticePageObjectTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    Pages::Components.new.load
  end

  def teardown
    Capybara.reset_sessions!
  end

  def test_reads_the_kind_and_the_text
    notices = Pages::Theme::Notice.all_in(page.find("#notices"))
    assert_equal %w[info success warning danger info], notices.map(&:kind)
    assert_equal "A warning notice", notices[2].text
    assert_equal "A notice with no kind and a body", notices.last.text
    assert_equal "warning", Pages::Theme::Notice.find_in(page.find("#notice-string")).kind
  end
end
