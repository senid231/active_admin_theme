module ActiveAdminTheme
  module Views
    # The theme's CSS displays an attributes table for one record as a grid,
    # and a browser drops the table semantics of such a table. These ARIA
    # roles keep each label tied to its value. Prepended to ActiveAdmin's
    # AttributesTable; a table for several records stays a table.
    module AttributesTableRoles
      CELL_ROLES = {"th" => "rowheader", "td" => "cell"}.freeze

      def build(obj, *attrs)
        super
        @table.set_attribute(:role, "table") if grid_table?
      end

      def row(*args, &block)
        result = super
        table_row = @table.children.last if grid_table?
        if table_row.respond_to?(:tag_name) && table_row.tag_name == "tr"
          table_row.set_attribute(:role, "row")
          table_row.children.each do |cell|
            role = CELL_ROLES[cell.tag_name] if cell.respond_to?(:tag_name)
            cell.set_attribute(:role, role) if role
          end
        end
        result
      end

      private

      def grid_table?
        @table.respond_to?(:children) && single_record?
      end
    end

    ActiveAdmin::Views::AttributesTable.prepend(AttributesTableRoles)
  end
end
