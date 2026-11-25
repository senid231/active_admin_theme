module ActiveAdminTheme
  module PageObjects
    # A `truncate_text` value.
    #
    #   note = TruncateText.find_in(index.table.row(1).cell(:notes))
    #   note.text # what the cell shows
    #   note.full_text # the whole value
    class TruncateText < Component
      selector_key :truncate_text

      # The whole value, which the component keeps in its `title`.
      # @return [String]
      def full_text
        root_element[:title].to_s
      end

      # True when `length:` cut the text. A value that only CSS clips to the
      # width is whole in the page, so it does not count.
      def cut?
        squish(text) != squish(full_text)
      end
    end
  end
end
