# Browser test (headless Chrome): secret_reveal's inline mode keeps the value
# in a template and reveals it on click without a request.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"

class SecretRevealInlineTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  MULTILINE = "{\n  \"token\": \"abc\",\n  \"scope\": \"read\"\n}".freeze

  def setup
    page.current_window.resize_to(1280, 900)
    visit "/admin/secret_reveal"
  end

  def teardown
    Capybara.reset_sessions!
  end

  def render_view(&block)
    Arbre::Context.new({}, nil, &block).to_s
  end

  def test_masked_by_default_with_the_value_in_an_inert_template
    assert_selector "#inline button", text: "••••••••"
    assert_no_text "inline-s3cr3t"
    assert_equal 1, page.evaluate_script("document.querySelectorAll('#inline template[data-aat-secret-reveal-value]').length")
    assert_nil find("#inline [data-aat-secret-reveal]")["data-url"]
  end

  def test_click_shows_the_value_and_a_second_click_hides_it
    page.execute_script("window.fetchCalls = 0; const f = window.fetch; window.fetch = (...args) => { window.fetchCalls++; return f(...args) }")
    find("#inline button").click
    assert_selector "#inline button", text: "inline-s3cr3t"
    assert_selector "#inline [data-aat-secret-reveal][data-revealed]"
    assert_equal 0, page.evaluate_script("window.fetchCalls")
    find("#inline button").click
    assert_selector "#inline button", text: "••••••••"
    assert_no_selector "#inline [data-revealed]"
  end

  def test_a_multi_line_value_keeps_its_line_breaks
    find("#multiline button").click
    assert_selector "#multiline [data-revealed]"
    assert_equal MULTILINE, page.evaluate_script("document.querySelector('#multiline .aat-secret-reveal-value').textContent")
    assert_equal "pre-wrap", page.evaluate_script("getComputedStyle(document.querySelector('#multiline .aat-secret-reveal-value')).whiteSpace")
  end

  def test_the_value_is_shown_as_text_even_when_html_safe
    find("#markup button").click
    assert_selector "#markup [data-revealed]"
    assert_equal %(<img src="x" onerror="window.injected = true"><b>bold</b>),
      page.evaluate_script("document.querySelector('#markup .aat-secret-reveal-value').textContent")
    assert_no_selector "#markup img"
    assert_no_selector "#markup b"
    assert_nil page.evaluate_script("window.injected")
  end

  def test_a_blank_value_renders_the_empty_text
    assert_selector "#blank .attributes-table-empty-value", text: /\Aempty\z/i
    assert_no_selector "#blank button"
  end

  def test_url_mode_still_fetches
    assert_nil page.evaluate_script("document.querySelector('#fetched template')")
    find("#fetched button").click
    assert_selector "#fetched button", text: "s3cr3t"
  end

  def test_value_and_url_together_raise
    error = assert_raises(ArgumentError) { render_view { secret_reveal url: "/x", value: "y" } }
    assert_match(/not both/, error.message)
  end

  def test_neither_value_nor_url_raises
    error = assert_raises(ArgumentError) { render_view { secret_reveal } }
    assert_match(/url: or value:/, error.message)
  end
end
