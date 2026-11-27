module ActiveAdminTheme
  module Helpers
    module PreWrap
      include ActionView::Helpers::TagHelper

      MAX_HEIGHT = /\A\d+(\.\d+)?(px|r?em|ch|vh|vw|dvh|svh|lvh|vmin|vmax|%|cm|mm|in|pt|pc)\z/

      # pre_wrap(record.raw_payload)
      # pre_wrap(record.raw_payload, max_height: "20rem")
      #
      # A <pre> that keeps line breaks and wraps long lines. The text is escaped.
      # Blank text renders nothing (nil), so an attributes_table row shows
      # ActiveAdmin's empty marker. `max_height:` (a CSS length, or an Integer
      # of px) caps the height and scrolls the rest.
      def pre_wrap(text, max_height: nil)
        return if text.blank?

        options = {class: "aat-pre-wrap"}
        if max_height
          options[:class] = "aat-pre-wrap aat-pre-wrap-capped"
          options[:style] = "--aat-pre-wrap-max-height:#{pre_wrap_max_height(max_height)}"
          options[:tabindex] = "0"
        end
        content_tag(:pre, text.to_s, **options)
      end

      private

      def pre_wrap_max_height(value)
        length = value.is_a?(Numeric) ? "#{value}px" : value.to_s.strip
        raise ArgumentError, "pre_wrap max_height must be a CSS length or a number of px, got #{value.inspect}" unless length.match?(MAX_HEIGHT)

        length
      end
    end
  end
end

ActiveSupport.on_load(:action_view) { include ActiveAdminTheme::Helpers::PreWrap }
