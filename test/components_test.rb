# Browser test (headless Chrome): the opt-in components render and behave.
require_relative "capybara_boot"
require "minitest/autorun"
require "capybara/minitest"

class ComponentsTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    page.current_window.resize_to(1280, 900)
    visit "/admin/components"
  end

  def teardown
    Capybara.reset_sessions!
  end

  def style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).#{property}")
  end

  def test_status_tag_variants_have_their_own_solid_fills
    colors = %w[ok warning error info no].map { |status| style("[data-status=#{status}]", "backgroundColor") }
    assert_equal ["rgb(94, 126, 99)", "rgb(158, 108, 21)", "rgb(206, 72, 59)", "rgb(56, 116, 210)", "rgb(112, 118, 129)"], colors
    assert_equal "rgb(255, 255, 255)", style("[data-status=ok]", "color")
    assert_equal "rgba(0, 0, 0, 0)", style("[data-status=empty]", "backgroundColor")
  end

  def test_status_tag_aliases_take_the_theme_colors
    {green: "ok", orange: "warning", red: "error", blue: "info"}.each do |alias_name, status|
      assert_equal style("[data-status=#{status}]", "backgroundColor"), style("[data-status=#{alias_name}]", "backgroundColor"), alias_name
      assert_nil find("[data-status=#{alias_name}]")[:style], alias_name
    end
  end

  def test_status_tag_yes_is_blue
    assert_equal "rgb(25, 114, 198)", style("[data-status=yes]", "backgroundColor")
  end

  def test_table_in_a_panel_scrolls_with_a_sticky_first_column
    page.current_window.resize_to(420, 900)
    body = "#sticky-rows .panel-body"
    assert_equal "auto", style(body, "overflowX")
    assert_operator page.evaluate_script("document.querySelector(#{body.to_json}).scrollWidth"), :>, 420
    left = ->(sel) { page.evaluate_script("document.querySelector(#{sel.to_json}).getBoundingClientRect().left") }
    first = "#sticky-rows tbody tr:nth-child(2) td:first-child"
    second = "#sticky-rows tbody tr:nth-child(2) td:nth-child(2)"
    before = left.(first)
    page.execute_script("document.querySelector(#{body.to_json}).scrollLeft = 300")
    assert_in_delta before, left.(first), 1
    assert_operator left.(second), :<, before
    assert_equal style(second, "backgroundColor"), style(first, "backgroundColor")
  end

  def test_body_uses_the_v3_font_without_antialiasing
    assert_match(/\A"Helvetica Neue", Arial/, style("body", "fontFamily"))
    assert_equal "auto", style("body", "webkitFontSmoothing")
  end

  def test_status_tag_colors_are_the_same_in_dark_mode
    light = [style("[data-status=ok]", "backgroundColor"), style("[data-status=ok]", "color")]
    page.execute_script("document.documentElement.classList.add('dark')")
    assert_equal light, [style("[data-status=ok]", "backgroundColor"), style("[data-status=ok]", "color")]
  end

  def test_status_tag_without_a_defined_color_keeps_the_default_look
    assert_equal style("[data-status=no]", "backgroundColor"), style("[data-status=unstyled]", "backgroundColor")
    assert_equal style("[data-status=no]", "color"), style("[data-status=unstyled]", "color")
    page.execute_script("document.documentElement.classList.add('dark')")
    assert_equal style("[data-status=no]", "backgroundColor"), style("[data-status=unstyled]", "backgroundColor")
    assert_equal style("[data-status=no]", "color"), style("[data-status=unstyled]", "color")
  end

  def test_status_tag_reads_a_custom_property_for_its_status
    shipped = style("[data-status=shipped]", "backgroundColor")
    refute_equal style("[data-status=unstyled]", "backgroundColor"), shipped
    assert_equal "rgb(124, 58, 237)", shipped
  end

  def test_status_tag_color_option_sets_the_color
    assert_equal "--aat-status-color:#b91c1c", find("#status-late")[:style]
    late = style("#status-late", "backgroundColor")
    refute_equal style("[data-status=error]", "backgroundColor"), late
    refute_equal "rgba(0, 0, 0, 0)", late
  end

  def test_status_tag_color_option_rejects_anything_but_a_color
    error = assert_raises(ArgumentError) do
      Arbre::Context.new { status_tag "x", color: "red;background:url(x)" }.to_s
    end
    assert_match(/plain CSS color/, error.message)
  end

  def test_truncate_text_shows_an_ellipsis_and_the_full_text_in_title
    assert_selector "#truncate-default .aat-truncate[title*='so it is cut']"
    assert_equal "ellipsis", style("#truncate-default .aat-truncate", "textOverflow")
    assert_equal "nowrap", style("#truncate-default .aat-truncate", "whiteSpace")
    assert page.evaluate_script("(() => { const e = document.querySelector('#truncate-narrow .aat-truncate'); return e.scrollWidth > e.clientWidth })()")
    assert_in_delta 128, page.evaluate_script("document.querySelector('#truncate-narrow .aat-truncate').getBoundingClientRect().width"), 1
  end

  def test_truncate_text_popup_shows_the_full_text_on_hover_and_focus
    host = "#truncate-popup .aat-truncate"
    assert_no_selector "#{host}[title]"
    assert_selector "#{host}[tabindex='0'][aria-describedby]"
    popup_id = find(host)["aria-describedby"]
    assert_selector "##{popup_id}[role=tooltip]", visible: :hidden, text: "so it is cut"
    assert page.evaluate_script("(() => { const e = document.querySelector('#truncate-popup .aat-truncate-text'); return e.scrollWidth > e.clientWidth })()")

    find(host).hover
    assert_selector "##{popup_id}", visible: :visible, text: "A long sentence that does not fit in the space it is given, so it is cut."
    # Wider than the scrolling box around it, and still whole on screen.
    box = page.evaluate_script("document.querySelector('#truncate-popup').getBoundingClientRect().toJSON()")
    popup = page.evaluate_script("document.getElementById('#{popup_id}').getBoundingClientRect().toJSON()")
    text = page.evaluate_script("document.querySelector('#truncate-popup .aat-truncate-text').getBoundingClientRect().toJSON()")
    assert_operator popup["width"], :>, box["width"]
    assert_operator popup["top"], :>=, text["bottom"]
    assert page.evaluate_script("(() => { const p = document.getElementById('#{popup_id}'); const r = p.getBoundingClientRect(); const hit = document.elementFromPoint(r.right - 4, r.bottom - 4); return hit === p })()")

    find("#truncate-default").hover
    assert_no_selector "##{popup_id}", visible: :visible
    page.execute_script("document.querySelector(arguments[0]).focus()", host)
    assert_selector "##{popup_id}", visible: :visible
  end

  def test_truncate_text_length_cuts_the_text
    assert_selector "#truncate-length .aat-truncate", text: "A long sentence t..."
    assert_match(/so it is cut/, find("#truncate-length .aat-truncate")[:title])
  end

  def test_secret_reveal_shows_the_value_on_click_and_hides_it_on_the_second
    assert_selector "#secret button", text: "••••••••"
    assert_no_text "s3cr3t"
    find("#secret button").click
    assert_selector "#secret button", text: "s3cr3t"
    find("#secret button").click
    assert_selector "#secret button", text: "••••••••"
    assert_no_text "s3cr3t"
  end

  def test_secret_reveal_shows_a_failed_request_inline
    page.execute_script("document.querySelector('#secret [data-aat-secret-reveal]').dataset.url = '/admin/components/forbidden'")
    find("#secret button").click
    assert_selector "#secret .aat-secret-reveal-error", text: /Could not load/
    assert_selector "#secret button", text: "••••••••"
  end

  def test_tooltip_title_is_a_title_attribute
    assert_selector "#tooltip-title span[title='Plain title tooltip']", text: "Hover for a title"
  end

  def test_html_tooltip_appears_on_hover_and_is_sanitized
    assert_no_selector "#tooltip-html [role=tooltip]", visible: :visible
    find("#tooltip-html span[data-tooltip-target]").hover
    assert_selector "[role=tooltip] strong", text: "Rich", visible: :visible
    assert_no_selector "[role=tooltip] script", visible: :all
  end

  def test_pre_wrap_wraps_a_long_string_without_widening_the_page
    assert_equal "pre-wrap", style("#pre-wrap pre", "whiteSpace")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 1280
    assert_operator page.evaluate_script("document.querySelector('#pre-wrap pre').getBoundingClientRect().height"), :>, 40
    page.current_window.resize_to(390, 800)
    visit "/admin/components"
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
  end

  def test_status_tag_danger_takes_the_error_color
    assert_equal style("[data-status=error]", "backgroundColor"), style("[data-status=danger]", "backgroundColor")
    assert_nil find("[data-status=danger]")[:style]
  end

  def test_notice_kinds_have_roles_and_a_kind_each
    assert_selector "#notices > .aat-notice", count: 5
    {"info" => "status", "success" => "status", "warning" => "alert", "danger" => "alert"}.each do |kind, role|
      assert_selector "#notices > .aat-notice[data-kind=#{kind}][role=#{role}]", text: "A #{kind} notice"
    end
    assert_selector "#notices > .aat-notice[data-kind=info] p.notice-body", text: "and a body"
    assert_selector "#notice-string .aat-notice[data-kind=warning][role=alert]", text: "from the string helper"
  end

  def test_notice_text_is_readable_in_light_and_dark_mode
    %w[info success warning danger].each do |kind|
      assert_operator notice_contrast(kind), :>=, 4.5, "light #{kind}"
    end
    page.execute_script("document.documentElement.classList.add('dark')")
    assert_equal "rgb(221, 226, 232)", style("#notices .aat-notice", "color")
    %w[info success warning danger].each do |kind|
      assert_operator notice_contrast(kind), :>=, 4.5, "dark #{kind}"
    end
  end

  def test_text_success_token_is_readable_on_the_surfaces
    read = ->(name) { page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--aat-#{name}').trim()") }
    assert_equal "#1a6b34", read.("text-success")
    names = %w[page-bg surface surface-2]
    names.each { |name| assert_operator hex_contrast(read.("text-success"), read.(name)), :>=, 4.5, name }
    page.execute_script("document.documentElement.classList.add('dark')")
    assert_equal "#7fd49a", read.("text-success")
    names.each { |name| assert_operator hex_contrast(read.("text-success"), read.(name)), :>=, 4.5, "dark #{name}" }
  end

  def test_pre_wrap_max_height_caps_the_height_and_scrolls
    assert_equal "auto", style("#pre-wrap-capped pre", "overflowY")
    assert page.evaluate_script("(() => { const e = document.querySelector('#pre-wrap-capped pre'); return e.scrollHeight > e.clientHeight })()")
    assert_in_delta 90, page.evaluate_script("document.querySelector('#pre-wrap-capped-px pre').getBoundingClientRect().height"), 1
    assert_selector "#pre-wrap-capped pre[tabindex='0']"
  end

  def test_pre_wrap_of_blank_text_shows_the_empty_marker
    assert_no_selector "#pre-wrap-blank pre"
    assert_selector "#pre-wrap-blank .attributes-table-empty-value"
  end

  def test_string_helpers_render_the_components
    assert_selector "#string-helpers .status-tag[data-status=late]", text: /overdue/i
    assert_equal "--aat-status-color:#b91c1c", find("#string-helpers .status-tag")[:style]
    assert_selector "#string-helpers [data-aat-secret-reveal] .aat-secret-reveal-toggle"
    assert_selector "#string-helpers span.from-arbre", text: "From aat_arbre"
  end

  private

  def srgb_channels(color)
    numbers = color.scan(/[\d.]+/).first(3).map(&:to_f)
    color.start_with?("color(") ? numbers.map { |n| n * 255 } : numbers
  end

  def luminance(channels)
    channels.map { |c| (c /= 255.0) <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }.then { |r, g, b| 0.2126 * r + 0.7152 * g + 0.0722 * b }
  end

  def contrast(first, second)
    light, dark = [luminance(first), luminance(second)].sort.reverse
    (light + 0.05) / (dark + 0.05)
  end

  def hex_contrast(first, second)
    contrast(*[first, second].map { |hex| hex.delete("#").scan(/../).map { |pair| pair.to_i(16) } })
  end

  def notice_contrast(kind)
    selector = "#notices > .aat-notice[data-kind=#{kind}]"
    contrast(srgb_channels(style(selector, "color")), srgb_channels(style(selector, "backgroundColor")))
  end
end
