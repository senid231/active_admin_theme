module ActiveAdminTheme
  module PageObjects
    # A `columns` row. Each column is a section to look inside:
    #
    #   row = Columns.find_in(show)
    #   row.columns.size # => 2
    #   row.columns.first.find(".panel")
    #   row.weights # => [1, 2]
    class Columns < Component
      # One `column` of the row.
      class Column < ActiveAdminPageObjects::Section
        # The weight of the column in the row's ratio: 2 of "1:2".
        # @return [Numeric, nil]
        def weight
          number = root_element[:style].to_s[/--aat-w:\s*([\d.]+)/, 1]
          number && (number.include?(".") ? number.to_f : number.to_i)
        end
      end

      selector_key :columns

      # A row nested in a column has its own columns, so take the children only.
      sections :columns, Column, :xpath, "./*[contains(concat(' ', normalize-space(@class), ' '), ' aat-column ')]"

      # The weights of the columns, in order: [1, 3] for `columns "1:3"`.
      # @return [Array<Numeric>]
      def weights
        columns.map(&:weight)
      end
    end
  end
end
