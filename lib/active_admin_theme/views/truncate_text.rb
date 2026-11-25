module ActiveAdminTheme
  module Views
    # truncate_text(text)                           # CSS ellipsis, 20rem wide
    # truncate_text(text, max_width: "12rem")       # width limit
    # truncate_text(text, length: 40)               # also cut to 40 characters
    #
    # truncate_text(text, popup: true)             # full text in a popup on hover and focus
    #
    # One line; the full value is in the `title` attribute. `max_width` is a
    # number (pixels) or a number with px, rem, em, ch, % or vw. With
    # `popup: true` the full value shows in a popup instead of the `title`: the
    # element takes keyboard focus and names the popup in `aria-describedby`.
    class TruncateText < ActiveAdmin::Component
      builder_method :truncate_text

      MAX_WIDTH = /\A\d+(\.\d+)?(px|rem|em|ch|%|vw)?\z/

      def tag_name
        "span"
      end

      def build(text, options = {})
        options = options.dup
        length = options.delete(:length)
        max_width = options.delete(:max_width)
        popup = options.delete(:popup)
        text = text.to_s
        super(options)
        add_class "aat-truncate"
        set_attribute :style, [get_attribute(:style), "--aat-truncate-width:#{width(max_width)}"].compact.join(";") if max_width
        shown = length ? text.truncate(length) : text
        return build_popup(shown, text) if popup && text.present?

        set_attribute :title, text if text.present? && !get_attribute(:title)
        text_node(shown)
      end

      private

      def build_popup(shown, text)
        popup_id = "aat-truncate-#{SecureRandom.hex(4)}"
        add_class "aat-truncate-has-popup"
        set_attribute :tabindex, "0"
        set_attribute :"aria-describedby", popup_id
        span shown, class: "aat-truncate-text"
        span text, id: popup_id, role: "tooltip", class: "aat-truncate-popup"
      end

      def width(value)
        value = value.is_a?(Numeric) ? "#{value}px" : value.to_s.strip
        raise ArgumentError, "truncate_text max_width must be a number or a CSS length, got #{value.inspect}" unless value.match?(MAX_WIDTH)

        value.match?(/\d\z/) ? "#{value}px" : value
      end
    end
  end
end
