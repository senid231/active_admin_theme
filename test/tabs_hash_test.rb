# Browser test (headless Chrome): the URL hash opens a tab, and tab clicks write it.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"

class TabsHashTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def teardown
    Capybara.reset_sessions!
  end

  def test_hash_of_a_panel_opens_that_tab
    visit "/admin/tabs#explicit-2"
    assert_selector "#explicit-2", visible: :visible
    assert_selector "#summary-2", visible: :hidden
    assert_selector "button[aria-controls=explicit-2][aria-selected=true]"
    assert_selector "button[aria-controls=summary-2][aria-selected=false]"
    assert_selector "#summary", visible: :visible
  end

  def test_hash_of_the_only_tab_keeps_it_open
    visit "/admin/tabs#flow-links"
    assert_selector "#flow-links", visible: :visible
    assert_selector "button[aria-controls=flow-links][aria-selected=true]"
  end

  def test_hash_of_an_element_inside_a_hidden_panel_opens_its_tab
    visit "/admin/tabs#year-note-2"
    assert_selector "#tab-2024-2", visible: :visible
    assert_selector "#year-note-2", visible: :visible
    assert_selector "#summary-2", visible: :hidden
  end

  def test_unknown_hash_changes_nothing
    visit "/admin/tabs#nothing-here"
    assert_selector "#summary", visible: :visible
    assert_selector "#tab-2024", visible: :hidden
  end

  def test_click_writes_the_hash_without_a_history_entry
    visit "/admin/tabs"
    length = page.evaluate_script("history.length")
    find("button[aria-controls=tab-2024]").click
    assert_selector "#tab-2024", visible: :visible
    assert_equal "#tab-2024", page.evaluate_script("location.hash")
    assert_equal length, page.evaluate_script("history.length")
  end

  def test_hashchange_selects_the_tab
    visit "/admin/tabs"
    find("button[aria-controls=tab-2024]").click
    assert_selector "#summary", visible: :hidden
    page.execute_script("location.hash = '#summary'")
    assert_selector "#summary", visible: :visible
    assert_selector "#tab-2024", visible: :hidden
    assert_selector "button[aria-controls=summary][aria-selected=true]"
  end
end
