# Browser test (headless Chrome): lazy_load loads its HTML when it scrolls into
# view, when its tab opens, or at once with eager: true.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"
require "active_admin_theme/page_objects"

class LazyLoadTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  LazyLoad = ActiveAdminTheme::PageObjects::LazyLoad

  def setup
    page.current_window.resize_to(1280, 900)
    visit "/admin/lazy_load"
  end

  def teardown
    Capybara.reset_sessions!
  end

  def render_view(&block)
    Arbre::Context.new({}, nil, &block).to_s
  end

  def test_a_placeholder_in_view_loads_and_the_html_replaces_its_content
    assert_selector "#in-view [data-loaded] .fragment", text: "GET fragment"
    assert_no_text "Loading the history..."
    assert_no_selector "#in-view [data-loading]"
    assert_no_selector "#in-view [data-error]"
  end

  def test_the_placeholder_shows_the_loading_text_before_the_load
    html = render_view { lazy_load url: "/x", loading: "Loading <b>now</b>" }
    assert_includes html, "Loading &lt;b&gt;now&lt;/b&gt;"
    assert_includes html, %(data-url="/x")
    assert_includes html, %(data-method="GET")
    refute_includes html, "data-eager"
  end

  def test_a_script_in_the_reply_does_not_run
    assert_selector "#in-view [data-loaded]"
    assert_nil page.evaluate_script("window.lazyScriptRan")
  end

  def test_a_placeholder_below_the_fold_waits_until_it_scrolls_into_view
    assert_selector "#in-view [data-loaded]"
    assert_no_selector "#below [data-loaded]", visible: :all
    assert_no_selector "#below [data-loading]", visible: :all
    page.execute_script("document.getElementById('below').scrollIntoView()")
    assert_selector "#below [data-loaded] .fragment", text: "GET fragment"
  end

  def test_an_eager_placeholder_loads_without_scrolling
    assert_selector "#eager [data-loaded] .fragment", text: "GET fragment", visible: :all
    assert_equal 0, page.evaluate_script("window.scrollY")
  end

  def test_a_placeholder_in_a_hidden_tab_loads_when_the_tab_opens
    assert_selector "#in-view [data-loaded]"
    assert_no_selector "#in-tab [data-loaded]", visible: :all
    click_on "History"
    assert_selector "#in-tab [data-loaded] .fragment", text: "GET fragment"
  end

  def test_a_failed_request_shows_the_error_text_and_the_status
    assert_selector "#failing [data-error='HTTP 403'] .aat-lazy-load-error", text: "Could not load the history (HTTP 403)"
    assert_no_selector "#failing [data-loaded]"
  end

  def test_a_post_placeholder_sends_the_method
    assert_selector "#posted [data-loaded] .fragment", text: "POST fragment"
  end

  def test_the_loaded_event_bubbles_and_reload_fetches_again
    assert_selector "#in-view [data-loaded]"
    page.execute_script(<<~JS)
      window.loadedEvents = 0
      document.addEventListener("aat:lazy-load:loaded", () => window.loadedEvents++)
      document.querySelector("#in-view [data-aat-lazy-load]").dispatchEvent(new CustomEvent("aat:lazy-load:reload", { bubbles: true }))
    JS
    assert_selector "#in-view [data-loaded]"
    assert_equal 1, page.evaluate_script("window.loadedEvents")
  end

  def test_the_page_object_waits_for_the_content
    lazy = LazyLoad.find_in(page, match: :first)
    assert_same lazy, lazy.wait_until_loaded
    assert lazy.content_loaded?
    refute lazy.loading?
    assert_nil lazy.error
    assert_equal "GET fragment", lazy.text
  end

  def test_the_page_object_reports_a_failed_request
    lazy = LazyLoad.find_in(find("#failing"))
    error = assert_raises(Capybara::ExpectationNotMet) { lazy.wait_until_loaded }
    assert_match(/HTTP 403/, error.message)
    assert_equal "HTTP 403", lazy.error
    refute lazy.content_loaded?
  end

  def test_the_page_object_finds_a_placeholder_by_its_scope
    assert_equal 6, LazyLoad.all_in(page, visible: :all).size
  end

  def test_no_url_raises
    error = assert_raises(ArgumentError) { render_view { lazy_load } }
    assert_match(/needs url:/, error.message)
  end

  def test_an_unknown_method_raises
    error = assert_raises(ArgumentError) { render_view { lazy_load url: "/x", method: :trace } }
    assert_match(/method must be one of/, error.message)
  end
end
